/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  @testable import AppLaunchInstrumentationCore
  @testable import MincoreLaunchInstrumentation
  import Foundation
  import os.log
  import InMemoryExporter
  import OpenTelemetryApi
  import OpenTelemetrySdk
  import XCTest

  /// Mirrors the C baseline: reading gives nothing until the app has entered the background, so a
  /// test can't accidentally assert on a sample the app never took.
  final class FakeBackgroundSample: @unchecked Sendable {
    private let lock = NSLock()
    private var _didTake = false
    private var _sample: LaunchPageSample?

    func configure(_ sample: LaunchPageSample?) {
      lock.withLock { _sample = sample }
    }

    func take() {
      lock.withLock { _didTake = true }
    }

    func read() -> LaunchPageSample? {
      lock.withLock { _didTake ? _sample : nil }
    }

    var didTake: Bool { lock.withLock { _didTake } }
  }

  struct FakeLaunchPageSampler: LaunchPageSampler {
    var sample: LaunchPageSample?
    var pageIns: LaunchPageIns?
    var pageInsNow: @Sendable () -> Int? = { nil }
    var background: FakeBackgroundSample?
    var textPageTotal: Int?

    func readSample() -> LaunchPageSample? {
      sample
    }

    func readPageIns() -> LaunchPageIns? {
      pageIns
    }

    func readPageInsNow() -> Int? {
      pageInsNow()
    }

    func samplePagesAtBackground() {
      background?.take()
    }

    func readBackgroundSample() -> LaunchPageSample? {
      background?.read()
    }

    func readTextPageTotal() -> Int? {
      textPageTotal
    }
  }

  final class FakeFirstFrameReader: FirstFrameReader, @unchecked Sendable {
    private let lock = NSLock()
    // Keyed by token, so cancelling one read leaves the others pending, as a display link does.
    private var completions: [Int: (Date) -> Void] = [:]
    private var lastToken = 0
    private var reads = 0
    private var cancellations = 0

    var pendingCount: Int { lock.withLock { completions.count } }
    var readCount: Int { lock.withLock { reads } }
    var cancelCount: Int { lock.withLock { cancellations } }

    func readFirstFrame(_ completion: @escaping (Date) -> Void) -> FirstFrameRead {
      let token: Int = lock.withLock {
        reads += 1
        lastToken += 1
        completions[lastToken] = completion
        return lastToken
      }
      return Read(reader: self, token: token)
    }

    func displayFrame(at date: Date) {
      let pending: [Int: (Date) -> Void] = lock.withLock {
        defer { completions.removeAll() }
        return completions
      }
      pending.sorted { $0.key < $1.key }.forEach { $0.value(date) }
    }

    /// Like an invalidated display link: the completion is never called again. Counted whether or
    /// not the read was still pending, since a cancelled read that already reported is a no-op.
    private struct Read: FirstFrameRead {
      let reader: FakeFirstFrameReader
      let token: Int

      func cancel() {
        reader.cancel(token)
      }
    }

    private func cancel(_ token: Int) {
      lock.withLock {
        cancellations += 1
        completions[token] = nil
      }
    }
  }

  final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date

    init(now: Date) {
      _now = now
    }

    var now: Date {
      get { lock.withLock { _now } }
      set { lock.withLock { _now = newValue } }
    }
  }

  final class FakeLaunchHistory: LaunchHistory, @unchecked Sendable {
    private let lock = NSLock()
    private var _previous: LaunchContext?
    private var _exchangeCount = 0

    init(previous: LaunchContext?) {
      _previous = previous
    }

    var exchangeCount: Int { lock.withLock { _exchangeCount } }

    func exchange(_ current: LaunchContext) -> LaunchContext? {
      lock.withLock {
        _exchangeCount += 1
        defer { _previous = current }
        return _previous
      }
    }
  }

  /// Holds the blocks the instrumentation runs after the current event, until the test runs them.
  final class FakeEventQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var blocks: [@Sendable () -> Void] = []

    func enqueue(_ block: @escaping @Sendable () -> Void) {
      lock.withLock { blocks.append(block) }
    }

    func finishCurrentEvent() {
      let pending = lock.withLock {
        defer { blocks = [] }
        return blocks
      }
      pending.forEach { $0() }
    }
  }

  /// The start type a root span describes: `app.start.type` for a launch, `resume` for an `app.resume`.
  func startType(_ span: SpanData?) -> AttributeValue? {
    guard let span else { return nil }
    return span.name == "app.resume" ? .string("resume") : span.attributes["app.start.type"]
  }

  class MincoreLaunchInstrumentationTests: XCTestCase {
    let didBecomeActive = Notification.Name("AppLaunchInstrumentationTests.didBecomeActive")
    let willEnterForeground = Notification.Name("AppLaunchInstrumentationTests.willEnterForeground")
    let didEnterBackground = Notification.Name("AppLaunchInstrumentationTests.didEnterBackground")
    let sceneWillConnect = Notification.Name("AppLaunchInstrumentationTests.sceneWillConnect")
    let didFinishLaunching = Notification.Name("AppLaunchInstrumentationTests.didFinishLaunching")
    let processStart = Date(timeIntervalSince1970: 1_000)
    let appCodeStart = Date(timeIntervalSince1970: 1_001)
    let becameActive = Date(timeIntervalSince1970: 1_002.5)
    let firstFrame = Date(timeIntervalSince1970: 1_002.6)
    var launchContext = LaunchContext(bootTime: 500, appVersion: "1.0", appBuild: "1")

    var spanExporter: InMemoryExporter!
    var tracerProvider: TracerProviderSdk!
    var notificationCenter: NotificationCenter!
    var firstFrameReader: FakeFirstFrameReader!
    var clock: TestClock!
    var launchHistory: FakeLaunchHistory!
    var eventQueue: FakeEventQueue!
    var backgroundPageSample: FakeBackgroundSample!

    override func setUp() {
      super.setUp()
      AppLaunchRuntime.reset()
      spanExporter = InMemoryExporter()
      tracerProvider = TracerProviderSdk()
      tracerProvider.addSpanProcessor(SimpleSpanProcessor(spanExporter: spanExporter))
      OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
      notificationCenter = NotificationCenter()
      firstFrameReader = FakeFirstFrameReader()
      clock = TestClock(now: becameActive)
      launchHistory = FakeLaunchHistory(previous: nil)
      eventQueue = FakeEventQueue()
    }

    override func tearDown() {
      AppLaunchRuntime.reset()
      spanExporter.reset()
      super.tearDown()
    }

    func makeDependencies(
      sample: LaunchPageSample? = nil,
      pageIns: LaunchPageIns? = nil,
      pageInsNow: @escaping @Sendable () -> Int? = { nil },
      backgroundSample: LaunchPageSample? = nil,
      textPageTotal: Int? = nil,
      useFirstFrameReader: Bool = true,
      processStartTime: @escaping @Sendable () -> Date? = { Date(timeIntervalSince1970: 1_000) },
      isActivePrewarm: Bool = false,
      earliestAppCodeTime: Date? = Date(timeIntervalSince1970: 1_001),
      isAppActive: Bool = false,
      isBackgroundLaunch: Bool = false,
      configuration: AppLaunchInstrumentationConfiguration = .init()
    ) -> MincoreLaunchInstrumentation.Dependencies {
      let background = FakeBackgroundSample()
      background.configure(backgroundSample)
      backgroundPageSample = background
      let pageSampler = FakeLaunchPageSampler(sample: sample, pageIns: pageIns, pageInsNow: pageInsNow,
                                              background: background, textPageTotal: textPageTotal)
      return MincoreLaunchInstrumentation.Dependencies(
        notificationCenter: notificationCenter,
        didBecomeActiveNotification: didBecomeActive,
        willEnterForegroundNotification: willEnterForeground,
        didEnterBackgroundNotification: didEnterBackground,
        sceneWillConnectNotification: sceneWillConnect,
        didFinishLaunchingNotification: didFinishLaunching,
        firstFrameReader: useFirstFrameReader ? firstFrameReader : nil,
        processStartTime: processStartTime,
        earliestAppCodeTime: { earliestAppCodeTime },
        isActivePrewarm: { isActivePrewarm },
        isAppActive: { isAppActive },
        isBackgroundLaunch: { isBackgroundLaunch },
        configuration: configuration,
        currentLaunchContext: { [launchContext] in launchContext },
        launchHistory: launchHistory,
        now: { [clock] in clock!.now },
        afterCurrentEvent: { [eventQueue] in eventQueue!.enqueue($0) },
        readPageIns: pageInsNow,
        samplePagesAtBackground: { pageSampler.samplePagesAtBackground() },
        makeClassifier: { dependencies in
          MincoreLaunchClassifier(
            fallback: InferredLaunchClassifier(dependencies: dependencies),
            pageSampler: pageSampler,
            isActivePrewarm: dependencies.isActivePrewarm,
            coldPageInRatio: dependencies.configuration.coldPageInRatio
          )
        },
        makeRecorder: { MincoreAppStartRecorder(dependencies: $0, pageSampler: pageSampler) }
      )
    }

    func install(sample: LaunchPageSample? = nil,
                 pageIns: LaunchPageIns? = nil,
                 pageInsNow: @escaping @Sendable () -> Int? = { nil },
                 backgroundSample: LaunchPageSample? = nil,
                 textPageTotal: Int? = nil,
                 useFirstFrameReader: Bool = true,
                 processStartTime: @escaping @Sendable () -> Date? = { Date(timeIntervalSince1970: 1_000) },
                 isActivePrewarm: Bool = false,
                 earliestAppCodeTime: Date? = Date(timeIntervalSince1970: 1_001),
                 isAppActive: Bool = false,
                 isBackgroundLaunch: Bool = false,
                 configuration: AppLaunchInstrumentationConfiguration = .init()) {
      MincoreLaunchInstrumentation.install(
        dependencies: makeDependencies(
          sample: sample,
          pageIns: pageIns,
          pageInsNow: pageInsNow,
          backgroundSample: backgroundSample,
          textPageTotal: textPageTotal,
          useFirstFrameReader: useFirstFrameReader,
          processStartTime: processStartTime,
          isActivePrewarm: isActivePrewarm,
          earliestAppCodeTime: earliestAppCodeTime,
          isAppActive: isAppActive,
          isBackgroundLaunch: isBackgroundLaunch,
          configuration: configuration
        )
      )
    }

    /// A monitor observing activations, built the way `AppLaunchRuntime.install` builds one, so a
    /// test can put a second one in the process without going through the idempotent install.
    func makeMonitor(_ dependencies: MincoreLaunchInstrumentation.Dependencies) -> ActivationMonitor {
      let classifier = dependencies.classifier
      let monitor = ActivationMonitor(dependencies: dependencies,
                                      classifier: classifier,
                                      classification: classifier.begin(),
                                      tracker: ActivationTracker(isAppActive: false, isBackgroundLaunch: false))
      monitor.start()
      return monitor
    }

    func post(_ name: Notification.Name, at time: Date? = nil) {
      if let time {
        clock.now = time
      }
      notificationCenter.post(name: name, object: nil)
    }

    /// Installs and completes the cold start.
    func launch() {
      install()
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)
    }

    func finishedSpans() -> [SpanData] {
      tracerProvider.forceFlush()
      return spanExporter.getFinishedSpanItems()
    }

    /// The `app.start` and `app.resume` spans, without their phases.
    func rootSpans() -> [SpanData] {
      finishedSpans().filter { $0.name == "app.start" || $0.name == "app.resume" }
    }

    func testColdStartSpanCoversProcessStartToFirstFrame() {
      install()

      notificationCenter.post(name: didBecomeActive, object: nil)
      firstFrameReader.displayFrame(at: firstFrame)

      let spans = rootSpans()
      XCTAssertEqual(spans.count, 1)
      let span = spans[0]
      XCTAssertEqual(span.name, "app.start")
      XCTAssertEqual(span.instrumentationScope.name, "io.opentelemetry.lifecycle")
      XCTAssertEqual(span.startTime, processStart)
      XCTAssertEqual(span.endTime, firstFrame)
      XCTAssertEqual(startType(span), .string("cold"))
    }

    func testInitInstalls() {
      // The real dependencies record the launch in the test runner's standard defaults.
      defer { UserDefaults.standard.removeObject(forKey: UserDefaultsLaunchHistory.key) }
      XCTAssertFalse(MincoreLaunchInstrumentation.isInstalled)

      _ = MincoreLaunchInstrumentation()

      XCTAssertTrue(MincoreLaunchInstrumentation.isInstalled)
    }

    func testIsNotInstalledUntilObservingActivations() {
      final class Observation: @unchecked Sendable {
        var isInstalled: Bool?
      }
      let observation = Observation()
      var dependencies = makeDependencies()
      dependencies.isAppActive = {
        observation.isInstalled = MincoreLaunchInstrumentation.isInstalled
        return false
      }

      MincoreLaunchInstrumentation.install(dependencies: dependencies)

      XCTAssertEqual(observation.isInstalled, false)
      XCTAssertTrue(MincoreLaunchInstrumentation.isInstalled)
    }

    func testFirstFrameIsReadOnlyAfterAppBecomesActive() {
      install()

      XCTAssertEqual(firstFrameReader.readCount, 0)

      notificationCenter.post(name: didBecomeActive, object: nil)

      XCTAssertEqual(firstFrameReader.readCount, 1)
    }

    func testNoSpanUntilFirstFrameIsDisplayed() {
      install()

      notificationCenter.post(name: didBecomeActive, object: nil)

      XCTAssertTrue(rootSpans().isEmpty)
    }

    func testColdStartEndsWhenAppBecomesActiveWithoutFirstFrameReader() {
      install(useFirstFrameReader: false)

      notificationCenter.post(name: didBecomeActive, object: nil)

      let spans = rootSpans()
      XCTAssertEqual(spans.count, 1)
      XCTAssertEqual(spans.first?.startTime, processStart)
      XCTAssertEqual(spans.first?.endTime, becameActive)
    }

    func testColdStartIsRecordedOnlyOnce() {
      install()

      notificationCenter.post(name: didBecomeActive, object: nil)
      notificationCenter.post(name: didBecomeActive, object: nil)
      install()
      notificationCenter.post(name: didBecomeActive, object: nil)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(firstFrameReader.readCount, 1)
      XCTAssertEqual(rootSpans().count, 1)
    }

    func testRepeatedInstallRecordsOneSpan() {
      install()
      install()

      notificationCenter.post(name: didBecomeActive, object: nil)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(rootSpans().count, 1)
    }

    func testOneLaunchIsRecordedPerProcess() {
      // Two monitors in one process, which only a `reset` between installs can produce. The
      // process launched once, so one of them records it and the other drops it.
      let monitors = [makeMonitor(makeDependencies()), makeMonitor(makeDependencies())]
      defer { monitors.forEach { $0.stop() } }

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(firstFrameReader.readCount, 1)
      XCTAssertEqual(rootSpans().map(\.name), ["app.start"])
    }

    func testLaunchRecordDoesNotBlockResumes() {
      // The claim covers the launch only. The monitor that lost it has still handled its launch,
      // so its returns to the foreground are resumes, and a resume is never deduplicated: both
      // monitors record one, the same way two monitors duplicate everything else.
      let monitors = [makeMonitor(makeDependencies()), makeMonitor(makeDependencies())]
      defer { monitors.forEach { $0.stop() } }

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)
      post(didEnterBackground, at: Date(timeIntervalSince1970: 1_003))
      post(willEnterForeground, at: Date(timeIntervalSince1970: 2_000))
      post(didBecomeActive, at: Date(timeIntervalSince1970: 2_000.2))
      firstFrameReader.displayFrame(at: Date(timeIntervalSince1970: 2_000.3))

      XCTAssertEqual(rootSpans().map(\.name), ["app.start", "app.resume", "app.resume"])
    }

    func testNoSpanBeforeInstall() {
      notificationCenter.post(name: didBecomeActive, object: nil)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertFalse(MincoreLaunchInstrumentation.isInstalled)
      XCTAssertTrue(rootSpans().isEmpty)
    }

    func testNoSpanAfterReset() {
      install()
      AppLaunchRuntime.reset()

      notificationCenter.post(name: didBecomeActive, object: nil)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertFalse(MincoreLaunchInstrumentation.isInstalled)
      XCTAssertTrue(rootSpans().isEmpty)
    }

    func testNoSpanWhenProcessStartTimeIsUnavailable() {
      install(processStartTime: { nil })

      notificationCenter.post(name: didBecomeActive, object: nil)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertTrue(rootSpans().isEmpty)
    }

    func testOtherNotificationsAreIgnored() {
      install()

      notificationCenter.post(name: Notification.Name("unrelated"), object: nil)

      XCTAssertEqual(firstFrameReader.readCount, 0)
      XCTAssertTrue(rootSpans().isEmpty)
    }

    func testActivePrewarmColdStartStartsWhenAppCodeFirstRan() {
      install(isActivePrewarm: true)

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      let spans = rootSpans()
      XCTAssertEqual(spans.count, 1)
      XCTAssertEqual(spans.first?.startTime, appCodeStart)
      XCTAssertEqual(spans.first?.endTime, firstFrame)
      XCTAssertEqual(startType(spans.first), .string("prewarmed"))
    }

    func testColdStartWithoutActivePrewarmIsNotPrewarmed() {
      install(processStartTime: { Date(timeIntervalSince1970: 1_002.6 - 29) })

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      let spans = rootSpans()
      XCTAssertEqual(spans.count, 1)
      XCTAssertEqual(spans.first?.startTime, Date(timeIntervalSince1970: 1_002.6 - 29))
      XCTAssertNotEqual(startType(spans.first), .string("prewarmed"))
    }

    func testDefaultMaxLaunchDurationIs60Seconds() {
      XCTAssertEqual(AppLaunchInstrumentationConfiguration().maxLaunchDuration, 60)
      XCTAssertEqual(makeDependencies().configuration.maxLaunchDuration, 60)
    }

    func testLongLaunchWithoutActivePrewarmIsNotPrewarmed() {
      install(processStartTime: { Date(timeIntervalSince1970: 1_002.6 - 59) })

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      let span = rootSpans().first
      XCTAssertEqual(span?.startTime, Date(timeIntervalSince1970: 1_002.6 - 59))
      XCTAssertNotEqual(startType(span), .string("prewarmed"))
    }

    func testLaunchExactlyMaxLaunchDurationIsRecorded() {
      install(useFirstFrameReader: false,
              configuration: AppLaunchInstrumentationConfiguration(maxLaunchDuration: 2.5))

      post(didBecomeActive)

      XCTAssertEqual(rootSpans().first?.endTime, processStart.addingTimeInterval(2.5))
    }

    func testLaunchLongerThanMaxLaunchDurationFromProcessStartIsDropped() {
      install(processStartTime: { Date(timeIntervalSince1970: 1_002.6 - 61) })

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertTrue(rootSpans().isEmpty)
    }

    func testPrewarmedLaunchWithinMaxLaunchDurationFromAppCodeIsRecorded() {
      install(processStartTime: { Date(timeIntervalSince1970: 1_002.6 - 3_600) },
              isActivePrewarm: true,
              earliestAppCodeTime: Date(timeIntervalSince1970: 1_002.6 - 59))

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      let span = rootSpans().first
      XCTAssertEqual(span?.startTime, Date(timeIntervalSince1970: 1_002.6 - 59))
      XCTAssertEqual(startType(span), .string("prewarmed"))
    }

    func testMaxLaunchDurationIsConfigurable() {
      install(configuration: AppLaunchInstrumentationConfiguration(maxLaunchDuration: 2))

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertTrue(rootSpans().isEmpty)
    }

    func testExcludedLaunchTypeIsNotRecorded() {
      install(configuration: AppLaunchInstrumentationConfiguration(launchTypes: [.warm, .resume]))

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(firstFrameReader.readCount, 0)
      XCTAssertTrue(rootSpans().isEmpty)
    }

    func testExcludedLaunchStillUpdatesLaunchHistory() {
      install(configuration: AppLaunchInstrumentationConfiguration(launchTypes: [.resume]))

      post(didBecomeActive)

      XCTAssertEqual(launchHistory.exchangeCount, 1)
    }

    func testExcludedWarmLaunchIsNotRecorded() {
      launchHistory = FakeLaunchHistory(previous: launchContext)
      install(configuration: AppLaunchInstrumentationConfiguration(launchTypes: [.cold, .resume]))

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertTrue(rootSpans().isEmpty)
    }

    func testResumeIsRecordedWhenLaunchTypeIsExcluded() {
      install(configuration: AppLaunchInstrumentationConfiguration(launchTypes: [.resume]))

      post(didBecomeActive)
      post(didEnterBackground)
      post(willEnterForeground)
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(rootSpans().map { startType($0) }, [.string("resume")])
    }

    func testExcludedResumeIsNotRecorded() {
      install(configuration: AppLaunchInstrumentationConfiguration(launchTypes: [.cold, .warm]))
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      post(didEnterBackground)
      post(willEnterForeground)
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(firstFrameReader.readCount, 1)
      XCTAssertEqual(rootSpans().map { startType($0) }, [.string("cold")])
    }

    func testColdLaunchSceneAndForegroundNotificationsAreNotSeparateStarts() {
      install()

      post(sceneWillConnect)
      post(willEnterForeground)
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      let spans = rootSpans()
      XCTAssertEqual(spans.count, 1)
      XCTAssertEqual(startType(spans.first), .string("cold"))
    }

    func testResumeRunsFromEnteringForegroundToFirstFrame() {
      launch()
      let enteredForeground = Date(timeIntervalSince1970: 2_000)
      let resumedFrame = Date(timeIntervalSince1970: 2_000.3)

      post(didEnterBackground)
      post(willEnterForeground, at: enteredForeground)
      post(didBecomeActive, at: Date(timeIntervalSince1970: 2_000.2))
      firstFrameReader.displayFrame(at: resumedFrame)

      let spans = rootSpans()
      XCTAssertEqual(spans.count, 2)
      let span = spans[1]
      XCTAssertEqual(span.name, "app.resume")
      XCTAssertEqual(span.instrumentationScope.name, "io.opentelemetry.lifecycle")
      XCTAssertEqual(span.startTime, enteredForeground)
      XCTAssertEqual(span.endTime, resumedFrame)
      XCTAssertEqual(startType(span), .string("resume"))
    }

    func testResumeInPrewarmedProcessIsNotPrewarmed() {
      install(isActivePrewarm: true)
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)
      let enteredForeground = Date(timeIntervalSince1970: 2_000)
      let resumedFrame = Date(timeIntervalSince1970: 2_000.3)

      post(didEnterBackground)
      post(willEnterForeground, at: enteredForeground)
      post(didBecomeActive, at: Date(timeIntervalSince1970: 2_000.2))
      firstFrameReader.displayFrame(at: resumedFrame)

      let spans = rootSpans()
      XCTAssertEqual(spans.map { startType($0) }, [.string("prewarmed"), .string("resume")])
      let span = spans[1]
      XCTAssertEqual(span.startTime, enteredForeground)
      XCTAssertEqual(span.endTime, resumedFrame)
    }

    func testEveryReturnToForegroundIsAResume() {
      launch()

      for _ in 0 ..< 2 {
        post(didEnterBackground)
        post(willEnterForeground)
        post(didBecomeActive)
        firstFrameReader.displayFrame(at: firstFrame)
      }

      XCTAssertEqual(rootSpans().map { startType($0) }, [.string("cold"), .string("resume"), .string("resume")])
    }

    func testResumeWithoutFirstFrameReaderEndsWhenAppBecomesActive() {
      install(useFirstFrameReader: false)
      post(didBecomeActive)
      let becameActiveAgain = Date(timeIntervalSince1970: 2_000.2)

      post(didEnterBackground)
      post(willEnterForeground, at: Date(timeIntervalSince1970: 2_000))
      post(didBecomeActive, at: becameActiveAgain)

      let spans = rootSpans()
      XCTAssertEqual(spans.count, 2)
      XCTAssertEqual(spans.last?.endTime, becameActiveAgain)
    }

    func testRegainingFocusIsNotAStart() {
      launch()

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(firstFrameReader.readCount, 1)
      XCTAssertEqual(rootSpans().count, 1)
    }

    func testReturningToBackgroundBeforeBecomingActiveAbandonsTheStart() {
      launch()

      post(didEnterBackground)
      post(willEnterForeground)
      post(didEnterBackground)
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(rootSpans().count, 1)
    }

    func testResumeWithRecreatedSceneRunsFromSceneConnectingToFirstFrame() {
      launch()
      let sceneConnected = Date(timeIntervalSince1970: 2_000)
      let resumedFrame = Date(timeIntervalSince1970: 2_000.5)

      post(didEnterBackground)
      post(sceneWillConnect, at: sceneConnected)
      post(willEnterForeground, at: Date(timeIntervalSince1970: 2_000.1))
      eventQueue.finishCurrentEvent()
      post(didBecomeActive, at: Date(timeIntervalSince1970: 2_000.4))
      firstFrameReader.displayFrame(at: resumedFrame)

      let spans = rootSpans()
      XCTAssertEqual(spans.count, 2)
      let span = spans[1]
      XCTAssertEqual(span.startTime, sceneConnected)
      XCTAssertEqual(span.endTime, resumedFrame)
      XCTAssertEqual(startType(span), .string("resume"))
    }

    func testSceneConnectingInTheForegroundIsNotAStart() {
      launch()

      post(sceneWillConnect)
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(rootSpans().count, 1)
    }

    func testNoResumeAfterReset() {
      launch()
      AppLaunchRuntime.reset()

      post(didEnterBackground)
      post(sceneWillConnect)
      post(willEnterForeground)
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(firstFrameReader.readCount, 1)
      XCTAssertEqual(rootSpans().count, 1)
    }

    func testFirstLaunchIsCold() {
      launch()

      XCTAssertEqual(startType(rootSpans().first), .string("cold"))
      XCTAssertEqual(launchHistory.exchangeCount, 1)
    }

    func testLaunchInSameStateAsPreviousLaunchIsWarm() {
      launchHistory = FakeLaunchHistory(previous: launchContext)

      launch()

      let span = rootSpans().first
      XCTAssertEqual(startType(span), .string("warm"))
      XCTAssertEqual(span?.startTime, processStart)
      XCTAssertEqual(span?.endTime, firstFrame)
    }

    func testLaunchAfterRebootIsCold() {
      var previous = launchContext
      previous.bootTime -= 3_600
      launchHistory = FakeLaunchHistory(previous: previous)

      launch()

      XCTAssertEqual(startType(rootSpans().first), .string("cold"))
    }

    func testBootTimeAdjustedWithinToleranceIsSameState() {
      var previous = launchContext
      previous.bootTime -= 0.5
      launchHistory = FakeLaunchHistory(previous: previous)

      launch()

      XCTAssertEqual(startType(rootSpans().first), .string("warm"))
    }

    func testLaunchAfterAppVersionUpdateIsCold() {
      var previous = launchContext
      previous.appVersion = "0.9"
      launchHistory = FakeLaunchHistory(previous: previous)

      launch()

      XCTAssertEqual(startType(rootSpans().first), .string("cold"))
    }

    func testLaunchAfterAppBuildUpdateIsCold() {
      var previous = launchContext
      previous.appBuild = "0"
      launchHistory = FakeLaunchHistory(previous: previous)

      launch()

      XCTAssertEqual(startType(rootSpans().first), .string("cold"))
    }

    func testLaunchIsColdWhenLaunchContextIsUnavailable() {
      launchHistory = FakeLaunchHistory(previous: launchContext)
      MincoreLaunchInstrumentation.install(dependencies: {
        var dependencies = makeDependencies()
        dependencies.currentLaunchContext = { nil }
        return dependencies
      }())

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(startType(rootSpans().first), .string("cold"))
      XCTAssertEqual(launchHistory.exchangeCount, 0)
    }

    func testWarmLaunchCanBePrewarmed() {
      launchHistory = FakeLaunchHistory(previous: launchContext)
      install(isActivePrewarm: true)

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      let span = rootSpans().first
      XCTAssertEqual(startType(span), .string("prewarmed"))
      XCTAssertEqual(span?.startTime, appCodeStart)
    }

    func testRepeatedInstallRecordsLaunchHistoryOnce() {
      install()
      install()

      XCTAssertEqual(launchHistory.exchangeCount, 1)
    }

    func testUserDefaultsLaunchHistoryReturnsPreviousLaunch() throws {
      let suiteName = "MincoreLaunchInstrumentationTests.\(UUID().uuidString)"
      defer { UserDefaults().removePersistentDomain(forName: suiteName) }
      let history = UserDefaultsLaunchHistory(suiteName: suiteName)
      var next = launchContext
      next.appBuild = "2"

      XCTAssertNil(history.exchange(launchContext))
      XCTAssertEqual(history.exchange(next), launchContext)
      XCTAssertEqual(history.exchange(next), next)
    }

    func testReadCurrentLaunchContextUsesBootTime() throws {
      let context = try XCTUnwrap(readCurrentLaunchContext())
      let bootTime = try XCTUnwrap(readBootTime())

      XCTAssertEqual(context.bootTime, bootTime.timeIntervalSince1970, accuracy: LaunchContext.bootTimeTolerance)
    }

    func testReadBootSessionIDIsStable() throws {
      let id = try XCTUnwrap(readBootSessionID())

      XCTAssertFalse(id.isEmpty)
      XCTAssertEqual(readBootSessionID(), id)
    }

    func testReadBootTimeIsBeforeProcessStart() throws {
      let bootTime = try XCTUnwrap(readBootTime())
      let processStart = try XCTUnwrap(readProcessStartTime())

      XCTAssertLessThanOrEqual(bootTime, processStart)
    }

    func testSecondInstallWithDifferentConfigurationIsReported() {
      let messages = captureFeedback()
      install()

      install(configuration: AppLaunchInstrumentationConfiguration(launchTypes: [.resume]))

      XCTAssertEqual(messages.values.count, 1)
      XCTAssertTrue(messages.values.first?.contains("already installed") ?? false)
    }

    func testFeedbackHandlerCanCallInstall() {
      let messages = captureFeedback()
      install()
      let dependencies = makeDependencies()
      OpenTelemetry.registerFeedbackHandler { message in
        messages.append(message)
        MincoreLaunchInstrumentation.install(dependencies: dependencies)
      }
      let finished = expectation(description: "install returned")
      let conflicting = makeDependencies(configuration: AppLaunchInstrumentationConfiguration(launchTypes: [.resume]))

      DispatchQueue.global().async {
        MincoreLaunchInstrumentation.install(dependencies: conflicting)
        finished.fulfill()
      }

      wait(for: [finished], timeout: 5)
      XCTAssertEqual(messages.values.count, 1)
    }

    func testReinstallOfSameBuildIsCold() {
      var previous = launchContext
      previous.installPath = "/containers/old/App.app"
      launchContext.installPath = "/containers/new/App.app"
      launchHistory = FakeLaunchHistory(previous: previous)
      install()

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(startType(rootSpans().first), .string("cold"))
    }

    func testSameInstallPathIsWarm() {
      launchContext.installPath = "/containers/same/App.app"
      launchHistory = FakeLaunchHistory(previous: launchContext)
      install()

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(startType(rootSpans().first), .string("warm"))
    }

    func testRecordWithoutInstallPathIsStillWarm() {
      launchHistory = FakeLaunchHistory(previous: launchContext)
      launchContext.installPath = "/containers/new/App.app"
      install()

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(startType(rootSpans().first), .string("warm"))
    }

    func testDebugModeLogsEnteringBackgroundBeforeFirstActivation() {
      let messages = captureFeedback()
      OpenTelemetry.setDebugEnabled(true)
      install()

      post(didEnterBackground)
      post(didEnterBackground)

      XCTAssertEqual(messages.values.filter { $0.contains("no launch recorded") }.count, 1)
    }

    func testDebugModeLogsDurationsInWholeMilliseconds() {
      let messages = captureFeedback()
      OpenTelemetry.setDebugEnabled(true)
      install()

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertTrue(messages.values.last?.contains("launch of 2600 ms") ?? false, "\(messages.values)")
    }

    func testNothingButErrorsIsLoggedWithoutDebugMode() {
      let messages = captureFeedback()
      install()

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(rootSpans().count, 1)
      XCTAssertTrue(messages.values.isEmpty)
    }

    func testDebugModeLogsInstallAndRecordedStart() {
      let messages = captureFeedback()
      OpenTelemetry.setDebugEnabled(true)
      install(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 120))

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(messages.values.count, 2)
      XCTAssertTrue(messages.values.first?.hasPrefix("[info] AppLaunchInstrumentationCore: installed") ?? false)
      XCTAssertTrue(messages.values.last?.hasPrefix("[debug] MincoreLaunchInstrumentation: recorded a cold launch") ?? false)
    }

    func testDebugModeLogsDroppedLaunchAsWarning() {
      let messages = captureFeedback()
      OpenTelemetry.setDebugEnabled(true)
      install(processStartTime: { nil })

      post(didBecomeActive)

      XCTAssertTrue(messages.values.last?.hasPrefix("[warn] MincoreLaunchInstrumentation: dropped a cold launch") ?? false)
    }

    func testFeedbackHandlerCanCallInstallDuringDebugLogging() {
      let messages = captureFeedback()
      OpenTelemetry.setDebugEnabled(true)
      let dependencies = makeDependencies(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 120))
      OpenTelemetry.registerFeedbackHandler { message in
        messages.append(message)
        MincoreLaunchInstrumentation.install(dependencies: dependencies)
      }
      let finished = expectation(description: "activation recorded")

      DispatchQueue.global().async { [notificationCenter, didBecomeActive, firstFrameReader, firstFrame] in
        MincoreLaunchInstrumentation.install(dependencies: dependencies)
        notificationCenter!.post(name: didBecomeActive, object: nil)
        firstFrameReader!.displayFrame(at: firstFrame)
        finished.fulfill()
      }

      wait(for: [finished], timeout: 5)
      XCTAssertEqual(messages.values.count, 2)
    }

    func testSecondInstallWithSameConfigurationIsNotReported() {
      let messages = captureFeedback()
      install()

      install()

      XCTAssertTrue(messages.values.isEmpty)
    }

    func testFirstInstallConfigurationIsKept() {
      install(configuration: AppLaunchInstrumentationConfiguration(launchTypes: [.resume]))
      install()

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertTrue(rootSpans().isEmpty)
    }

    func testInstallAfterAppBecameActiveSkipsLaunch() {
      install(isAppActive: true)

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(firstFrameReader.readCount, 0)
      XCTAssertTrue(rootSpans().isEmpty)
    }

    func testInstallAfterAppBecameActiveRecordsNextActivationAsResume() {
      install(isAppActive: true)

      post(didEnterBackground, at: Date(timeIntervalSince1970: 2_000))
      post(willEnterForeground, at: Date(timeIntervalSince1970: 2_010))
      post(didBecomeActive, at: Date(timeIntervalSince1970: 2_010.2))
      firstFrameReader.displayFrame(at: Date(timeIntervalSince1970: 2_010.3))

      let spans = rootSpans()
      XCTAssertEqual(spans.map { startType($0) }, [.string("resume")])
      XCTAssertEqual(spans.first?.startTime, Date(timeIntervalSince1970: 2_010))
    }

    func testInstallAfterAppBecameActiveStillUpdatesLaunchHistory() {
      install(isAppActive: true)

      XCTAssertEqual(launchHistory.exchangeCount, 1)
    }

    func testFirstForegroundAfterBackgroundLaunchIsResume() {
      install(isBackgroundLaunch: true)
      let enteredForeground = Date(timeIntervalSince1970: 2_000)
      let resumedFrame = Date(timeIntervalSince1970: 2_000.3)

      post(willEnterForeground, at: enteredForeground)
      post(didBecomeActive, at: Date(timeIntervalSince1970: 2_000.2))
      firstFrameReader.displayFrame(at: resumedFrame)

      let spans = rootSpans()
      XCTAssertEqual(spans.count, 1)
      XCTAssertEqual(startType(spans.first), .string("resume"))
      XCTAssertEqual(spans.first?.startTime, enteredForeground)
      XCTAssertEqual(spans.first?.endTime, resumedFrame)
    }

    func testFirstForegroundAfterBackgroundLaunchRunsFromSceneConnecting() {
      install(isBackgroundLaunch: true)
      let sceneConnected = Date(timeIntervalSince1970: 2_000)

      post(sceneWillConnect, at: sceneConnected)
      post(willEnterForeground, at: Date(timeIntervalSince1970: 2_000.1))
      post(didBecomeActive, at: Date(timeIntervalSince1970: 2_000.4))
      firstFrameReader.displayFrame(at: Date(timeIntervalSince1970: 2_000.5))

      let spans = rootSpans()
      XCTAssertEqual(spans.map { startType($0) }, [.string("resume")])
      XCTAssertEqual(spans.first?.startTime, sceneConnected)
    }

    func testEnteringBackgroundBeforeFirstActivationMakesItAResume() {
      install()
      let enteredForeground = Date(timeIntervalSince1970: 2_000)

      post(didEnterBackground)
      post(willEnterForeground, at: enteredForeground)
      post(didBecomeActive, at: Date(timeIntervalSince1970: 2_000.2))
      firstFrameReader.displayFrame(at: Date(timeIntervalSince1970: 2_000.3))

      let spans = rootSpans()
      XCTAssertEqual(spans.map { startType($0) }, [.string("resume")])
      XCTAssertEqual(spans.first?.startTime, enteredForeground)
      XCTAssertEqual(spans.first?.attributes["app.resume.type"], .string("hot"),
                     "the user left this launch, and the system didn't start the process in the background")
    }

    func testAResumeBeforeTheFirstActivationIsBackgroundLaunchedOnlyForABackgroundLaunch() {
      install(isBackgroundLaunch: true)
      let enteredForeground = Date(timeIntervalSince1970: 2_000)

      post(didEnterBackground)
      post(willEnterForeground, at: enteredForeground)
      post(didBecomeActive, at: Date(timeIntervalSince1970: 2_000.2))
      firstFrameReader.displayFrame(at: Date(timeIntervalSince1970: 2_000.3))

      XCTAssertEqual(rootSpans().first?.attributes["app.resume.type"], .string("background_launched"))
    }

    func testSceneConnectingInBackgroundDoesNotStartResume() {
      install(isBackgroundLaunch: true)
      let enteredForeground = Date(timeIntervalSince1970: 2_000)

      post(sceneWillConnect, at: Date(timeIntervalSince1970: 1_500))
      eventQueue.finishCurrentEvent()
      post(willEnterForeground, at: enteredForeground)
      post(didBecomeActive, at: Date(timeIntervalSince1970: 2_000.2))
      firstFrameReader.displayFrame(at: Date(timeIntervalSince1970: 2_000.3))

      let spans = rootSpans()
      XCTAssertEqual(spans.map { startType($0) }, [.string("resume")])
      XCTAssertEqual(spans.first?.startTime, enteredForeground)
    }

    func testBackgroundRoleWithoutEnteringForegroundIsRecordedAsLaunch() {
      install(isBackgroundLaunch: true)

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      let spans = rootSpans()
      XCTAssertEqual(spans.map { startType($0) }, [.string("cold")])
      XCTAssertEqual(spans.first?.startTime, processStart)
    }

    func testRegainingFocusAfterLaunchWithBackgroundRoleIsNotAStart() {
      install(isBackgroundLaunch: true)
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: Date(timeIntervalSince1970: 2_000))

      XCTAssertEqual(rootSpans().count, 1)
    }

    func testEnteringBackgroundAfterBackgroundRoleKeepsNextActivationAResume() {
      install(isBackgroundLaunch: true)

      post(didEnterBackground)
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertTrue(rootSpans().isEmpty)
    }

    func testBackgroundLaunchStillUpdatesLaunchHistory() {
      install(isBackgroundLaunch: true)

      XCTAssertEqual(launchHistory.exchangeCount, 1)
    }

    func testRegainingFocusAfterInstallInBackgroundLaunchedActiveAppIsNotAStart() {
      install(isAppActive: true, isBackgroundLaunch: true)

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertTrue(rootSpans().isEmpty)
    }

    func testReadIsAppActiveIsFalseOffMainThread() {
      let isActive = expectation(description: "read off the main thread")
      DispatchQueue.global().async {
        XCTAssertFalse(AppLaunchRuntime.readIsAppActive())
        isActive.fulfill()
      }
      wait(for: [isActive], timeout: 5)
    }

    func testEnteringBackgroundBeforeFirstFrameAbandonsLaunch() {
      install()

      post(didBecomeActive)
      post(didEnterBackground)
      firstFrameReader.displayFrame(at: Date(timeIntervalSince1970: 5_000))

      XCTAssertEqual(firstFrameReader.readCount, 1)
      let spans = rootSpans()
      XCTAssertEqual(spans.count, 1)
      XCTAssertEqual(spans.first?.attributes["app.start.outcome"], .string("abandoned"))
      XCTAssertEqual(spans.first?.endTime, becameActive, "the late frame must not end the launch")
    }

    func testEnteringBackgroundCancelsThePendingFirstFrameRead() {
      install()

      post(didBecomeActive)
      XCTAssertEqual(firstFrameReader.pendingCount, 1)
      post(didEnterBackground)

      XCTAssertEqual(firstFrameReader.cancelCount, 1, "the frame it would report is from the next time the app returns")
      XCTAssertEqual(firstFrameReader.pendingCount, 0)
    }

    func testStoppingCancelsThePendingFirstFrameRead() {
      install()

      post(didBecomeActive)
      XCTAssertEqual(firstFrameReader.pendingCount, 1)
      AppLaunchRuntime.reset()

      XCTAssertEqual(firstFrameReader.cancelCount, 1)
      XCTAssertEqual(firstFrameReader.pendingCount, 0)
    }

    func testACompletedFirstFrameReadIsNotCancelledLater() {
      install()

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)
      post(didEnterBackground)

      XCTAssertEqual(firstFrameReader.cancelCount, 0, "the read reported, so there's nothing left to stop")
      XCTAssertEqual(rootSpans().first?.attributes["app.start.outcome"], .string("completed"))
    }

    func testEnteringBackgroundBeforeFirstFrameAbandonsResume() {
      launch()

      post(didEnterBackground)
      post(willEnterForeground)
      post(didBecomeActive)
      post(didEnterBackground)
      firstFrameReader.displayFrame(at: Date(timeIntervalSince1970: 5_000))

      XCTAssertEqual(firstFrameReader.readCount, 2)
      let spans = rootSpans()
      XCTAssertEqual(spans.map(\.name), ["app.start", "app.resume"])
      XCTAssertEqual(spans.last?.attributes["app.resume.outcome"], .string("abandoned"))
      XCTAssertNotEqual(spans.last?.endTime, Date(timeIntervalSince1970: 5_000), "the late frame must not end the resume")
    }

    func testStartAfterAbandonedFirstFrameIsRecorded() {
      install()
      post(didBecomeActive)
      post(didEnterBackground)
      firstFrameReader.displayFrame(at: firstFrame)

      post(willEnterForeground, at: Date(timeIntervalSince1970: 2_000))
      post(didBecomeActive, at: Date(timeIntervalSince1970: 2_000.2))
      firstFrameReader.displayFrame(at: Date(timeIntervalSince1970: 2_000.3))

      XCTAssertEqual(rootSpans().map { startType($0) }, [.string("cold"), .string("resume")])
    }

    func testSpanDoesNotEndBeforeAppBecameActive() {
      install()

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: becameActive.addingTimeInterval(-0.008))

      XCTAssertEqual(rootSpans().first?.endTime, becameActive)
    }

    func testBackgroundLaunchLongerThanMaxLaunchDurationIsDropped() {
      // A background launch: app code ran right after process start, long before the first frame.
      install(processStartTime: { Date(timeIntervalSince1970: 1_002.6 - 3_600) },
              earliestAppCodeTime: Date(timeIntervalSince1970: 1_002.6 - 3_599.9))

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertTrue(rootSpans().isEmpty)
    }

    func testPrewarmedLaunchWithoutEarliestAppCodeTimeIsDroppedWhenLongerThanMaxLaunchDuration() {
      install(processStartTime: { Date(timeIntervalSince1970: 1_002.6 - 3_600) },
              isActivePrewarm: true,
              earliestAppCodeTime: nil)

      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertTrue(rootSpans().isEmpty)
    }

    func testSameBootSessionIsWarmEvenWhenBootTimeMoved() {
      var current = launchContext
      current.bootSessionID = "boot-a"
      var previous = current
      previous.bootTime -= 120

      XCTAssertTrue(current.isSameState(as: previous))
    }

    func testDifferentBootSessionIsCold() {
      var current = launchContext
      current.bootSessionID = "boot-b"
      var previous = launchContext
      previous.bootSessionID = "boot-a"

      XCTAssertFalse(current.isSameState(as: previous))
    }

    func testBootTimeIsComparedWhenEitherBootSessionIDIsMissing() {
      var current = launchContext
      current.bootSessionID = "boot-a"
      var previous = launchContext
      previous.bootTime -= 120

      XCTAssertFalse(current.isSameState(as: previous))
    }

    func testReadIsActivePrewarmIsFalseWhenNotPrewarmed() {
      XCTAssertFalse(readIsActivePrewarm())
    }

    func testReadEarliestAppCodeTimeIsBetweenProcessStartAndNow() throws {
      let earliestAppCode = try XCTUnwrap(readEarliestAppCodeTime())
      let processStart = try XCTUnwrap(readProcessStartTime())

      // `p_starttime` has microsecond precision, so allow for rounding.
      XCTAssertGreaterThanOrEqual(earliestAppCode, processStart.addingTimeInterval(-0.001))
      XCTAssertLessThanOrEqual(earliestAppCode, Date())
    }

    func testReadProcessStartTimeIsInThePast() throws {
      let start = try XCTUnwrap(readProcessStartTime())

      XCTAssertLessThanOrEqual(start, Date())
      XCTAssertGreaterThan(start, Date(timeIntervalSinceNow: -24 * 60 * 60))
    }
  }

  final class FeedbackMessages: @unchecked Sendable {
    private let lock = NSLock()
    private var _values: [String] = []

    var values: [String] { lock.withLock { _values } }

    func append(_ message: String) {
      lock.withLock { _values.append(message) }
    }
  }

  extension MincoreLaunchInstrumentationTests {
    /// Captures feedback messages until the test ends, then restores the default handler.
    func captureFeedback() -> FeedbackMessages {
      let messages = FeedbackMessages()
      OpenTelemetry.registerFeedbackHandler { messages.append($0) }
      addTeardownBlock {
        OpenTelemetry.setDebugEnabled(false)
        OpenTelemetry.registerFeedbackHandler { message in os_log("%{public}s", message) }
      }
      return messages
    }
  }

  #if canImport(UIKit)
    final class DisplayLinkFirstFrameReaderTests: XCTestCase {
      func testReportsFrameTimeCloseToNow() {
        let frameDisplayed = expectation(description: "frame displayed")
        let before = Date()
        var frameTime: Date?

        DisplayLinkFirstFrameReader().readFirstFrame { date in
          frameTime = date
          frameDisplayed.fulfill()
        }

        wait(for: [frameDisplayed], timeout: 5)
        XCTAssertNotNil(frameTime)
        if let frameTime {
          XCTAssertGreaterThan(frameTime, before.addingTimeInterval(-1))
          XCTAssertLessThanOrEqual(frameTime, Date())
        }
      }

      func testReportsOnlyOnce() {
        let frameDisplayed = expectation(description: "frame displayed")
        frameDisplayed.assertForOverFulfill = true

        DisplayLinkFirstFrameReader().readFirstFrame { _ in
          frameDisplayed.fulfill()
        }

        wait(for: [frameDisplayed], timeout: 5)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
      }
    }
  #endif
#endif

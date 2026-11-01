/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  @testable import AppLaunchInstrumentationCore
  @testable import InferredAppLaunchInstrumentation
  @testable import MincoreLaunchInstrumentation
  import Foundation
  import OpenTelemetryApi
  import OpenTelemetrySdk
  import XCTest

  struct FakeLaunchPageSampler: LaunchPageSampler {
    var sample: LaunchPageSample?
    var pageIns: LaunchPageIns?

    func readSample() -> LaunchPageSample? {
      sample
    }

    func readPageIns() -> LaunchPageIns? {
      pageIns
    }
  }

  private let didFinishLaunching = Notification.Name("MincoreLaunchInstrumentationTests.didFinishLaunching")

  private final class CapturingMetricExporter: MetricExporter, @unchecked Sendable {
    private let lock = NSLock()
    private var _metrics: [MetricData] = []

    var metrics: [MetricData] { lock.withLock { _metrics } }

    func export(metrics: [MetricData]) -> ExportResult {
      lock.withLock { _metrics.append(contentsOf: metrics) }
      return .success
    }

    func flush() -> ExportResult { .success }
    func shutdown() -> ExportResult { .success }
    func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality { .cumulative }
  }

  extension InferredAppLaunchInstrumentationTests {
    private func installMincore(sample: LaunchPageSample?,
                                pageIns: LaunchPageIns? = nil,
                                isActivePrewarm: Bool = false,
                                isBackgroundLaunch: Bool = false,
                                configuration: AppLaunchInstrumentationConfiguration = MincoreLaunchInstrumentation.defaultConfiguration) {
      MincoreLaunchInstrumentation.install(
        dependencies: mincoreDependencies(sample: sample,
                                          pageIns: pageIns,
                                          isActivePrewarm: isActivePrewarm,
                                          isBackgroundLaunch: isBackgroundLaunch,
                                          configuration: configuration)
      )
    }

    private func mincoreDependencies(sample: LaunchPageSample?,
                                     pageIns: LaunchPageIns? = nil,
                                     isActivePrewarm: Bool = false,
                                     isBackgroundLaunch: Bool = false,
                                     configuration: AppLaunchInstrumentationConfiguration = MincoreLaunchInstrumentation.defaultConfiguration) -> MincoreLaunchInstrumentation.Dependencies {
      var dependencies = makeDependencies(isActivePrewarm: isActivePrewarm, isBackgroundLaunch: isBackgroundLaunch, configuration: configuration)
      let pageSampler = FakeLaunchPageSampler(sample: sample, pageIns: pageIns)
      dependencies.didFinishLaunchingNotification = didFinishLaunching
      dependencies.makeClassifier = { dependencies in
        MincoreLaunchClassifier(
          fallback: InferredLaunchClassifier(dependencies: dependencies),
          pageSampler: pageSampler,
          isActivePrewarm: dependencies.isActivePrewarm,
          coldPageInRatio: dependencies.configuration.coldPageInRatio
        )
      }
      dependencies.makeRecorder = { MincoreAppStartRecorder(dependencies: $0, pageSampler: pageSampler) }
      return dependencies
    }

    private func launchSpan() -> SpanData? {
      finishedSpans().first { $0.name == "app.start" }
    }

    private func span(_ name: String) -> SpanData? {
      finishedSpans().first { $0.name == name }
    }

    private func activate() {
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)
    }

    func testMincoreLaunchThatPagedInMostOfItsCodeIsCold() {
      launchHistory = FakeLaunchHistory(previous: launchContext)
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 120))

      activate()

      let attributes = launchSpan()?.attributes
      XCTAssertEqual(attributes?["app.start.type"], .string("cold"))
      XCTAssertEqual(attributes?["app.start.sampled_pages.resident_at_end"], .int(128))
      XCTAssertEqual(attributes?["app.start.sampled_pages.paged_in"], .int(120))
      XCTAssertEqual(attributes?["app.start.sampled_page_in_ratio"], .double(0.9375))
    }

    func testMincoreLaunchThatFoundItsCodeInMemoryIsWarm() {
      // No launch history, so inference would have said `cold`.
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0))

      activate()

      XCTAssertEqual(launchSpan()?.attributes["app.start.type"], .string("warm"))
      XCTAssertEqual(launchSpan()?.attributes["app.start.sampled_page_in_ratio"], .double(0))
    }

    func testMincoreLaunchAtTheThresholdIsCold() {
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 64))

      activate()

      XCTAssertEqual(launchSpan()?.attributes["app.start.type"], .string("cold"))
    }

    func testMincoreLaunchJustBelowTheThresholdIsWarm() {
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 63))

      activate()

      XCTAssertEqual(launchSpan()?.attributes["app.start.type"], .string("warm"))
    }

    func testColdPageInRatioDefaultsToHalf() {
      XCTAssertEqual(AppLaunchInstrumentationConfiguration().coldPageInRatio, 0.5)
      XCTAssertEqual(MincoreLaunchInstrumentation.defaultConfiguration.coldPageInRatio, 0.5)
    }

    func testLaunchBelowAConfiguredThresholdIsWarm() {
      installMincore(sample: LaunchPageSample(residentAtEnd: 100, pagedIn: 70),
                     configuration: AppLaunchInstrumentationConfiguration(coldPageInRatio: 0.75))

      activate()

      XCTAssertEqual(launchSpan()?.attributes["app.start.type"], .string("warm"))
      XCTAssertEqual(launchSpan()?.attributes["app.start.sampled_page_in_ratio"], .double(0.7))
    }

    func testLaunchAtAConfiguredThresholdIsCold() {
      installMincore(sample: LaunchPageSample(residentAtEnd: 100, pagedIn: 25),
                     configuration: AppLaunchInstrumentationConfiguration(coldPageInRatio: 0.25))

      activate()

      XCTAssertEqual(launchSpan()?.attributes["app.start.type"], .string("cold"))
    }

    func testPrewarmCacheStateUsesTheConfiguredThreshold() {
      installMincore(sample: LaunchPageSample(residentAtEnd: 100, pagedIn: 70),
                     isActivePrewarm: true,
                     configuration: AppLaunchInstrumentationConfiguration(launchTypes: [.prewarmed], coldPageInRatio: 0.75))

      activate()

      XCTAssertEqual(launchSpan()?.attributes["app.start.prewarm.cache_state"], .string("warm"))
    }

    func testColdPageInRatioOutOfRangeUsesTheDefault() {
      let messages = captureFeedback()

      for ratio in [0, -1, 1.5, Double.nan] {
        let configuration = AppLaunchInstrumentationConfiguration(coldPageInRatio: ratio)

        XCTAssertEqual(MincoreLaunchInstrumentation.resolved(configuration).coldPageInRatio, 0.5)
      }

      XCTAssertEqual(messages.values.filter { $0.contains("coldPageInRatio") }.count, 4)
    }

    func testColdPageInRatioAtTheEndsOfItsRangeIsKept() {
      for ratio in [0.01, 1] {
        let configuration = AppLaunchInstrumentationConfiguration(coldPageInRatio: ratio)

        XCTAssertEqual(MincoreLaunchInstrumentation.resolved(configuration).coldPageInRatio, ratio)
      }
    }

    func testPrewarmedMincoreLaunchIsPrewarmedAndKeepsItsSample() {
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 120), isActivePrewarm: true)

      activate()

      let attributes = launchSpan()?.attributes
      XCTAssertEqual(attributes?["app.start.type"], .string("prewarmed"))
      XCTAssertEqual(attributes?["app.start.determined_by"], .string("prewarm_flag"))
      XCTAssertEqual(attributes?["app.start.sampled_pages.paged_in"], .int(120))
    }

    func testPrewarmedLaunchThatCantBeSampledIsStillPrewarmed() {
      installMincore(sample: nil, isActivePrewarm: true)

      activate()

      XCTAssertEqual(launchSpan()?.attributes["app.start.type"], .string("prewarmed"))
      XCTAssertNil(launchSpan()?.attributes["app.start.sampled_page_in_ratio"])
    }

    func testPrewarmedCanBeLeftOutOfLaunchTypes() {
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0),
                      isActivePrewarm: true,
                      configuration: AppLaunchInstrumentationConfiguration(launchTypes: [.cold, .warm, .resume]))

      activate()

      XCTAssertTrue(finishedSpans().isEmpty)
    }

    func testLaunchThatCantBeSampledIsInferredWithoutSampleAttributes() {
      launchHistory = FakeLaunchHistory(previous: launchContext)
      let messages = captureFeedback()
      OpenTelemetry.setDebugEnabled(true)
      installMincore(sample: nil)

      activate()

      let attributes = launchSpan()?.attributes
      XCTAssertEqual(attributes?["app.start.type"], .string("warm"))
      XCTAssertNil(attributes?["app.start.sampled_pages.resident_at_end"])
      XCTAssertNil(attributes?["app.start.sampled_pages.paged_in"])
      XCTAssertNil(attributes?["app.start.sampled_page_in_ratio"])
      XCTAssertTrue(messages.values.contains { $0.hasPrefix("[warn]") && $0.contains("inferred") })
    }

    func testLaunchWithNoResidentPagesIsInferred() {
      launchHistory = FakeLaunchHistory(previous: launchContext)
      installMincore(sample: LaunchPageSample(residentAtEnd: 0, pagedIn: 0))

      activate()

      XCTAssertEqual(launchSpan()?.attributes["app.start.type"], .string("warm"))
      XCTAssertNil(launchSpan()?.attributes["app.start.sampled_page_in_ratio"])
    }

    func testLaunchWithTooFewResidentPagesIsInferred() {
      // No launch history, so inference says `cold`, where the ratio of 0 would have said `warm`.
      installMincore(sample: LaunchPageSample(residentAtEnd: 3, pagedIn: 0))

      activate()

      let attributes = launchSpan()?.attributes
      XCTAssertEqual(attributes?["app.start.type"], .string("cold"))
      XCTAssertEqual(attributes?["app.start.determined_by"], .string("launch_history"))
      XCTAssertNil(attributes?["app.start.sampled_page_in_ratio"])
      XCTAssertNil(attributes?["app.start.sampled_pages.total"])
    }

    func testLaunchWithTheMinimumResidentPagesIsMeasured() {
      launchHistory = FakeLaunchHistory(previous: launchContext)
      installMincore(sample: LaunchPageSample(residentAtEnd: MincoreLaunchClassifier.minimumResidentPages, pagedIn: 16))

      activate()

      XCTAssertEqual(launchSpan()?.attributes["app.start.type"], .string("cold"))
      XCTAssertEqual(launchSpan()?.attributes["app.start.determined_by"], .string("page_sampling"))
    }

    func testAppSmallerThanTheMinimumIsMeasured() {
      launchHistory = FakeLaunchHistory(previous: launchContext)
      installMincore(sample: LaunchPageSample(residentAtEnd: 8, pagedIn: 8, sampled: 8))

      activate()

      XCTAssertEqual(launchSpan()?.attributes["app.start.type"], .string("cold"))
      XCTAssertEqual(launchSpan()?.attributes["app.start.determined_by"], .string("page_sampling"))
      XCTAssertEqual(launchSpan()?.attributes["app.start.sampled_pages.total"], .int(8))
    }

    func testPrewarmedLaunchWithTooFewResidentPagesIsStillPrewarmed() {
      installMincore(sample: LaunchPageSample(residentAtEnd: 3, pagedIn: 0), isActivePrewarm: true)

      activate()

      XCTAssertEqual(launchSpan()?.attributes["app.start.type"], .string("prewarmed"))
      XCTAssertNil(launchSpan()?.attributes["app.start.prewarm.cache_state"])
    }

    func testLaunchRecordsHowManyPagesWereSampled() {
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0, sampled: 200))

      activate()

      XCTAssertEqual(launchSpan()?.attributes["app.start.sampled_pages.total"], .int(200))
    }

    func testConfigurationThatDidntChooseLaunchTypesRecordsPrewarmed() {
      let configuration = MincoreLaunchInstrumentation.resolved(AppLaunchInstrumentationConfiguration(maxLaunchDuration: 30))

      XCTAssertTrue(configuration.launchTypes.contains(.prewarmed))
      XCTAssertEqual(configuration.maxLaunchDuration, 30)
    }

    func testConfigurationThatChoseLaunchTypesKeepsThem() {
      let chosen = AppLaunchInstrumentationConfiguration(launchTypes: [.cold, .warm, .resume])
      var changed = AppLaunchInstrumentationConfiguration()
      changed.launchTypes = [.cold]

      XCTAssertEqual(MincoreLaunchInstrumentation.resolved(chosen).launchTypes, [.cold, .warm, .resume])
      XCTAssertEqual(MincoreLaunchInstrumentation.resolved(changed).launchTypes, [.cold])
    }

    func testInferredLibraryDefaultLeavesOutPrewarmed() {
      XCTAssertFalse(AppLaunchInstrumentationConfiguration().launchTypes.contains(.prewarmed))
    }

    func testMincoreInstallStillUpdatesLaunchHistory() {
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0))

      XCTAssertEqual(launchHistory.exchangeCount, 1)
    }

    func testResumeHasNoSampleAttributes() {
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0))
      activate()

      post(didEnterBackground)
      post(willEnterForeground)
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame.addingTimeInterval(10))

      let resume = finishedSpans().last
      XCTAssertEqual(resume?.name, "app.resume")
      XCTAssertEqual(resume?.attributes["app.resume.type"], .string("hot"))
      XCTAssertNil(resume?.attributes["app.start.sampled_page_in_ratio"])
    }

    func testLaunchIsARootSpanWithAChildSpanPerPhase() throws {
      let didFinish = Date(timeIntervalSince1970: 1_002.1)
      let sceneConnect = Date(timeIntervalSince1970: 1_002.2)
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 120))
      post(didFinishLaunching, at: didFinish)
      post(sceneWillConnect, at: sceneConnect)

      post(didBecomeActive, at: becameActive)
      firstFrameReader.displayFrame(at: firstFrame)

      let root = try XCTUnwrap(launchSpan())
      XCTAssertEqual(root.kind, .internal)
      XCTAssertNil(root.parentSpanId)
      XCTAssertEqual(root.instrumentationScope.name, "io.opentelemetry.lifecycle")
      XCTAssertEqual(root.instrumentationScope.version, "2.0.0")
      XCTAssertEqual(root.startTime, processStart)
      XCTAssertEqual(root.endTime, firstFrame)
      XCTAssertEqual(root.attributes["app.start.outcome"], .string("completed"))
      XCTAssertEqual(root.attributes["app.start.determined_by"], .string("page_sampling"))
      XCTAssertNil(root.attributes["start.type"])

      let preInit = try XCTUnwrap(span("app.start.pre_init"))
      let appInit = try XCTUnwrap(span("app.start.app_init"))
      let render = try XCTUnwrap(span("app.start.render"))
      let sceneSetup = try XCTUnwrap(span("app.start.scene_setup"))
      XCTAssertEqual(preInit.parentSpanId, root.spanId)
      XCTAssertEqual(appInit.parentSpanId, root.spanId)
      XCTAssertEqual(render.parentSpanId, root.spanId)
      XCTAssertEqual(sceneSetup.parentSpanId, render.spanId)
      XCTAssertEqual(preInit.startTime, processStart)
      XCTAssertEqual(preInit.endTime, appCodeStart)
      XCTAssertEqual(appInit.startTime, appCodeStart)
      XCTAssertEqual(appInit.endTime, didFinish)
      XCTAssertEqual(render.startTime, didFinish)
      XCTAssertEqual(render.endTime, firstFrame)
      XCTAssertEqual(sceneSetup.startTime, sceneConnect)
      XCTAssertEqual(sceneSetup.endTime, firstFrame)
      XCTAssertTrue(appInit.attributes.isEmpty, "child spans have no attributes")

      XCTAssertEqual(root.attributes["app.start.pre_init.duration"], .double(1))
      XCTAssertEqual(root.attributes["app.start.app_init.duration"], .double(didFinish.timeIntervalSince(appCodeStart)))
      XCTAssertEqual(root.attributes["app.start.render_delay.duration"], .double(firstFrame.timeIntervalSince(didFinish)))
    }

    func testPrewarmedLaunchStartsAtActivation() throws {
      let didFinish = Date(timeIntervalSince1970: 1_002.1)
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 120), isActivePrewarm: true)
      post(didFinishLaunching, at: didFinish)

      post(didBecomeActive, at: becameActive)
      firstFrameReader.displayFrame(at: firstFrame)

      let root = try XCTUnwrap(launchSpan())
      XCTAssertEqual(root.startTime, appCodeStart)
      XCTAssertEqual(root.endTime, firstFrame)
      XCTAssertEqual(root.attributes["app.start.pre_activation.duration"], .double(1))
      XCTAssertEqual(root.attributes["app.start.prewarm.cache_state"], .string("cold"))
      XCTAssertNil(span("app.start.pre_init"), "a phase before the span starts isn't recorded")
      XCTAssertNil(root.attributes["app.start.pre_init.duration"])
      XCTAssertEqual(span("app.start.app_init")?.startTime, appCodeStart)
    }

    func testPrewarmedLaunchThatFoundItsCodeInMemoryHasAWarmCache() {
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0), isActivePrewarm: true)

      activate()

      XCTAssertEqual(launchSpan()?.attributes["app.start.prewarm.cache_state"], .string("warm"))
    }

    func testPhaseMissingATimestampIsNotRecorded() {
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0))

      activate()

      XCTAssertEqual(Set(finishedSpans().map(\.name)), ["app.start", "app.start.pre_init"])
      XCTAssertNil(launchSpan()?.attributes["app.start.app_init.duration"])
      XCTAssertNil(launchSpan()?.attributes["app.start.render_delay.duration"])
    }

    func testInferredLaunchSaysItWasDeterminedByLaunchHistory() {
      installMincore(sample: nil)

      activate()

      XCTAssertEqual(launchSpan()?.attributes["app.start.determined_by"], .string("launch_history"))
    }

    func testLaunchRecordsPageIns() {
      installMincore(sample: nil, pageIns: LaunchPageIns(preInitializer: 1_180, postInitializer: 96))

      activate()

      XCTAssertEqual(launchSpan()?.attributes["app.start.page_ins.pre_initializer"], .int(1_180))
      XCTAssertEqual(launchSpan()?.attributes["app.start.page_ins.post_initializer"], .int(96))
    }

    func testLaunchAbandonedBeforeItsFirstFrameEndsWhenTheAppLeft() throws {
      let left = Date(timeIntervalSince1970: 1_002.55)
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0))
      post(sceneWillConnect, at: Date(timeIntervalSince1970: 1_002.2))
      post(didBecomeActive, at: becameActive)

      post(didEnterBackground, at: left)
      firstFrameReader.displayFrame(at: firstFrame.addingTimeInterval(60))

      let root = try XCTUnwrap(launchSpan())
      XCTAssertEqual(root.attributes["app.start.outcome"], .string("abandoned"))
      XCTAssertEqual(root.endTime, left)
      XCTAssertEqual(finishedSpans().filter { $0.name == "app.start" }.count, 1)
    }

    func testCompletedLaunchIsNotAbandonedByLeavingLater() {
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0))
      activate()

      post(didEnterBackground)

      XCTAssertEqual(finishedSpans().filter { $0.name == "app.start" }.count, 1)
      XCTAssertEqual(launchSpan()?.attributes["app.start.outcome"], .string("completed"))
    }

    func testHotResumeReportsItsTimeInTheBackground() throws {
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0))
      activate()
      let left = firstFrame.addingTimeInterval(10)
      let back = firstFrame.addingTimeInterval(14)
      let end = firstFrame.addingTimeInterval(15)

      post(didEnterBackground, at: left)
      post(willEnterForeground, at: back)
      post(didBecomeActive, at: back)
      firstFrameReader.displayFrame(at: end)

      let resume = try XCTUnwrap(span("app.resume"))
      XCTAssertNil(resume.parentSpanId)
      XCTAssertEqual(resume.startTime, back)
      XCTAssertEqual(resume.endTime, end)
      XCTAssertEqual(resume.attributes["app.resume.type"], .string("hot"))
      XCTAssertEqual(resume.attributes["app.resume.outcome"], .string("completed"))
      XCTAssertEqual(resume.attributes["app.resume.background.duration"], .double(4))
      XCTAssertNil(span("app.resume.scene_setup"))
    }

    func testSceneReconnectStartsTheResumeWhenTheSceneConnected() throws {
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0))
      activate()
      let connect = firstFrame.addingTimeInterval(13)
      let foreground = firstFrame.addingTimeInterval(14)
      let end = firstFrame.addingTimeInterval(15)

      post(didEnterBackground, at: firstFrame.addingTimeInterval(10))
      post(sceneWillConnect, at: connect)
      post(willEnterForeground, at: foreground)
      post(didBecomeActive, at: foreground)
      firstFrameReader.displayFrame(at: end)

      let resume = try XCTUnwrap(span("app.resume"))
      let sceneSetup = try XCTUnwrap(span("app.resume.scene_setup"))
      XCTAssertEqual(resume.startTime, connect)
      XCTAssertEqual(resume.attributes["app.resume.type"], .string("scene_reconnect"))
      XCTAssertEqual(sceneSetup.parentSpanId, resume.spanId)
      XCTAssertEqual(sceneSetup.startTime, connect, "a child span must not start before its parent")
      XCTAssertEqual(sceneSetup.endTime, end)
    }

    func testFirstForegroundAfterABackgroundLaunchIsBackgroundLaunched() {
      installMincore(sample: nil, isBackgroundLaunch: true)

      post(willEnterForeground)
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(span("app.resume")?.attributes["app.resume.type"], .string("background_launched"))
      XCTAssertNil(span("app.resume")?.attributes["app.resume.background.duration"])
      XCTAssertNil(launchSpan())
    }

    func testAbandonedResumeIsRecorded() throws {
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0))
      activate()
      let back = firstFrame.addingTimeInterval(14)
      let left = firstFrame.addingTimeInterval(14.1)

      post(didEnterBackground)
      post(willEnterForeground, at: back)
      post(didBecomeActive, at: back)
      post(didEnterBackground, at: left)

      let resume = try XCTUnwrap(span("app.resume"))
      XCTAssertEqual(resume.attributes["app.resume.outcome"], .string("abandoned"))
      XCTAssertEqual(resume.endTime, left)
    }

    func testOnlyCompletedStartsRecordADurationMetric() throws {
      let exporter = CapturingMetricExporter()
      let meterProvider = MeterProviderSdk.builder()
        .registerMetricReader(reader: PeriodicMetricReaderBuilder(exporter: exporter).build())
        .registerView(selector: InstrumentSelectorBuilder().build(), view: View.builder().build())
        .build()
      OpenTelemetry.registerMeterProvider(meterProvider: meterProvider)
      defer { OpenTelemetry.registerMeterProvider(meterProvider: DefaultMeterProvider.instance) }
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0))

      activate()
      post(didEnterBackground)
      post(willEnterForeground)
      post(didBecomeActive)
      post(didEnterBackground)
      _ = meterProvider.forceFlush()

      let names = Set(exporter.metrics.map(\.name))
      XCTAssertTrue(names.contains("app.start.duration"))
      XCTAssertFalse(names.contains("app.resume.duration"), "an abandoned resume has no metric value")
    }

    func testDurationMetricHasTheSchemaVersion() throws {
      let exporter = CapturingMetricExporter()
      let meterProvider = MeterProviderSdk.builder()
        .registerMetricReader(reader: PeriodicMetricReaderBuilder(exporter: exporter).build())
        .registerView(selector: InstrumentSelectorBuilder().build(), view: View.builder().build())
        .build()
      OpenTelemetry.registerMeterProvider(meterProvider: meterProvider)
      defer { OpenTelemetry.registerMeterProvider(meterProvider: DefaultMeterProvider.instance) }
      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0))

      activate()
      _ = meterProvider.forceFlush()

      let metric = try XCTUnwrap(exporter.metrics.first { $0.name == "app.start.duration" })
      XCTAssertEqual(metric.instrumentationScopeInfo.name, "io.opentelemetry.lifecycle")
      XCTAssertEqual(metric.instrumentationScopeInfo.version, "2.0.0")
    }

    func testSecondLibraryIsIgnoredAndReported() {
      let messages = captureFeedback()
      install()

      installMincore(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 120),
                      configuration: AppLaunchInstrumentationConfiguration())
      activate()

      XCTAssertEqual(messages.values.count, 1)
      XCTAssertTrue(messages.values.first?.contains("different library") ?? false)
      XCTAssertEqual(finishedSpans().count, 1, "a start must only be recorded once")
      XCTAssertNil(finishedSpans().first?.attributes["start.sampled_page_in_ratio"])
    }

    func testPageInRatio() {
      XCTAssertEqual(LaunchPageSample(residentAtEnd: 4, pagedIn: 1).pageInRatio, 0.25)
      XCTAssertNil(LaunchPageSample(residentAtEnd: 0, pagedIn: 0).pageInRatio)
    }

    // The test host decides what can be sampled: plain `xctest` is a single page, the header the
    // sampler skips, so a sample may not exist here. The `app-start-mincore` integration launch
    // covers the sampler in a real app.
    func testKernelSamplerReadsPageIns() throws {
      let pageIns = try XCTUnwrap(KernelLaunchPageSampler().readPageIns())

      XCTAssertGreaterThanOrEqual(pageIns.preInitializer, 0)
      XCTAssertGreaterThanOrEqual(pageIns.postInitializer, 0)
    }

    func testKernelSamplerSampleIsConsistent() {
      guard let sample = KernelLaunchPageSampler().readSample() else { return }

      XCTAssertLessThanOrEqual(sample.residentAtEnd, 256)
      XCTAssertLessThanOrEqual(sample.pagedIn, sample.residentAtEnd)
      XCTAssertLessThanOrEqual(sample.residentAtEnd, sample.sampled)
      XCTAssertLessThanOrEqual(sample.sampled, 256)
    }
  }
#endif

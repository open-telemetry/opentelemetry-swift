/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  import AppLaunchInstrumentationCore
  import Foundation
  import InstrumentationSemanticConventions
  import OpenTelemetryApi

  /// Records activations with the `app.start` schema: a root span per launch or
  /// resume, a child span per phase, and a duration metric.
  struct MincoreAppStartRecorder: AppStartRecording {
    private typealias App = FederatedSemanticConventions.App

    // From the federated registry, so a rename there reaches the recorder instead of diverging.
    private enum Name {
      static let appStart = FederatedSemanticConventions.SpanName.appStart.rawValue
      static let preInit = FederatedSemanticConventions.SpanName.appStartPreInit.rawValue
      static let appInit = FederatedSemanticConventions.SpanName.appStartAppInit.rawValue
      static let render = FederatedSemanticConventions.SpanName.appStartRender.rawValue
      static let sceneSetup = FederatedSemanticConventions.SpanName.appStartSceneSetup.rawValue
      static let appResume = FederatedSemanticConventions.SpanName.appResume.rawValue
      static let resumeSceneSetup = FederatedSemanticConventions.SpanName.appResumeSceneSetup.rawValue
      static let appStartDuration = FederatedSemanticConventions.MetricName.appStartDuration.rawValue
      static let appResumeDuration = FederatedSemanticConventions.MetricName.appResumeDuration.rawValue
    }

    let dependencies: AppLaunchRuntime.Dependencies
    let pageSampler: LaunchPageSampler

    func prepare(_ start: AppStart) -> ((AppStartEnd) -> Void)? {
      let launchType = start.launchType
      guard dependencies.configuration.launchTypes.contains(launchType) else {
        InternalLogger.debug("not recording a \(launchType) start, because it isn't in `launchTypes`.")
        return nil
      }

      // Read when the app becomes active, so a tracer provider registered after install is used.
      let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: AppLaunchRuntime.instrumentationScope)

      switch start {
      case let .launch(classification, marks):
        guard let processStartTime = dependencies.processStartTime() else {
          InternalLogger.warn("dropped a \(launchType) launch, because the process start time can't be read.")
          return nil
        }
        return { end in
          recordLaunch(tracer: tracer, classification: classification, marks: marks, processStartTime: processStartTime, end: end)
        }
      case let .resume(resume):
        return { end in
          recordResume(tracer: tracer, resume: resume, end: end)
        }
      }
    }

    private func recordLaunch(tracer: Tracer,
                              classification: LaunchClassification,
                              marks: AppLaunchMarks,
                              processStartTime: Date,
                              end: AppStartEnd) {
      let type = classification.type
      let configuration = dependencies.configuration
      let isPrewarmed = type == .prewarmed
      let initializerTime = dependencies.earliestAppCodeTime()
      // A prewarmed process started long before the user launched the app, so time the launch
      // from when app code first ran instead.
      let startTime = isPrewarmed ? initializerTime ?? processStartTime : processStartTime
      let endTime = end.time
      let duration = endTime.timeIntervalSince(startTime)
      // Every timestamp in the chain is wall clock, so a backward step between process start and
      // the first frame would emit a span that ended before it started, and a negative duration
      // sample. A launch with a bogus origin has nothing usable in it, so drop it rather than
      // clamp it, which would report a 0 ms launch.
      if duration < 0 {
        InternalLogger.warn(
          "dropped a \(type) launch of \(milliseconds(duration)) ms, which ended before it started, so the clock stepped backward."
        )
        return
      }
      if duration > configuration.maxLaunchDuration {
        InternalLogger.warn(
          "dropped a \(type) launch of \(milliseconds(duration)) ms, which is longer than `maxLaunchDuration`."
        )
        return
      }

      let root = tracer.spanBuilder(spanName: Name.appStart)
        .setNoParent()
        .setStartTime(time: startTime)
        .setAttribute(key: App.startType.rawValue, value: type.schemaValue.description)
        .setAttribute(key: App.startOutcome.rawValue, value: (end.isCompleted ? App.StartOutcomeValues.completed : .abandoned).description)
        .startSpan()
      classification.attributes.forEach { root.setAttribute(key: $0.key, value: $0.value) }
      if let pageIns = pageSampler.readPageIns() {
        root.setAttribute(key: App.startPageInsPreInitializer.rawValue, value: pageIns.preInitializer)
        root.setAttribute(key: App.startPageInsPostInitializer.rawValue, value: pageIns.postInitializer)
      }

      if isPrewarmed {
        if let initializerTime {
          root.setAttribute(key: App.startPreActivationDuration.rawValue, value: initializerTime.timeIntervalSince(processStartTime))
        }
      } else if let preInit = recordPhase(tracer, Name.preInit, parent: root, start: processStartTime, end: initializerTime) {
        root.setAttribute(key: App.startPreInitDuration.rawValue, value: preInit)
      }
      if let appInit = recordPhase(tracer, Name.appInit, parent: root, start: initializerTime, end: marks.didFinishLaunchingEnd, limit: endTime) {
        root.setAttribute(key: App.startAppInitDuration.rawValue, value: appInit)
      }
      if let renderStart = marks.didFinishLaunchingEnd, renderStart <= endTime {
        let render = tracer.spanBuilder(spanName: Name.render)
          .setParent(root)
          .setStartTime(time: renderStart)
          .startSpan()
        // UIKit connects a scene after `didFinishLaunching`, so floor the phase at its parent's
        // start in case a clock step or an out-of-order notification says otherwise.
        _ = recordPhase(tracer, Name.sceneSetup, parent: render, start: marks.sceneConnectStart.map { max($0, renderStart) }, end: endTime)
        render.end(time: endTime)
        root.setAttribute(key: App.startRenderDuration.rawValue, value: endTime.timeIntervalSince(renderStart))
      }
      root.end(time: endTime)

      if end.isCompleted {
        recordDuration(Name.appStartDuration, seconds: duration, attributes: [App.startType.rawValue: .string(type.schemaValue.description)])
      }
      InternalLogger.debug(
        "recorded a \(type) launch of \(milliseconds(duration)) ms, prewarmed \(isPrewarmed), completed \(end.isCompleted)."
      )
    }

    private func recordResume(tracer: Tracer, resume: AppResume, end: AppStartEnd) {
      let endTime = end.time
      let duration = endTime.timeIntervalSince(resume.start)
      // As for a launch, a backward wall-clock step would emit a span that ended before it
      // started, and a negative duration sample.
      if duration < 0 {
        InternalLogger.warn(
          "dropped a \(resume.kind) resume of \(milliseconds(duration)) ms, which ended before it started, so the clock stepped backward."
        )
        return
      }
      let root = tracer.spanBuilder(spanName: Name.appResume)
        .setNoParent()
        .setStartTime(time: resume.start)
        .setAttribute(key: App.resumeType.rawValue, value: resume.kind.schemaValue.description)
        .setAttribute(key: App.resumeOutcome.rawValue, value: (end.isCompleted ? App.ResumeOutcomeValues.completed : .abandoned).description)
        .startSpan()
      if let backgroundDuration = resume.backgroundDuration {
        root.setAttribute(key: App.resumeBackgroundDuration.rawValue, value: backgroundDuration)
      }
      // The counter is cumulative for the process, so only the difference belongs to this resume. A
      // counter that went backwards means it was reset or couldn't be read, so nothing is reported.
      if let atStart = resume.pageInsAtStart, let atEnd = pageSampler.readPageInsNow(), atEnd >= atStart {
        root.setAttribute(key: App.resumePageIns.rawValue, value: atEnd - atStart)
      }
      // A property of the binary rather than of this resume, so it doesn't depend on the baseline
      // below and is reported even when the app never entered the background.
      if let total = pageSampler.readTextPageTotal() {
        root.setAttribute(key: App.resumeTextPagesTotal.rawValue, value: total)
      }
      // Only the app's own code, unlike the page-in counter above, and only for a resume the app
      // entered the background before, since that's when the baseline is taken.
      if let sample = pageSampler.readBackgroundSample() {
        root.setAttribute(key: App.resumeTextPagesSampled.rawValue, value: sample.sampled)
        root.setAttribute(key: App.resumeTextPagesResidentAtEnd.rawValue, value: sample.residentAtEnd)
        root.setAttribute(key: App.resumeTextPagesPagedIn.rawValue, value: sample.pagedIn)
        if let ratio = sample.pageInRatio {
          root.setAttribute(key: App.resumeTextPagesPageInRatio.rawValue, value: ratio)
        }
      }
      _ = recordPhase(tracer, Name.resumeSceneSetup, parent: root, start: resume.sceneConnectStart, end: endTime)
      root.end(time: endTime)

      if end.isCompleted {
        recordDuration(Name.appResumeDuration, seconds: duration, attributes: [App.resumeType.rawValue: .string(resume.kind.schemaValue.description)])
      }
      InternalLogger.debug("recorded a \(resume.kind) resume of \(milliseconds(duration)) ms, completed \(end.isCompleted).")
    }

    /// Records a phase if both of its timestamps are known, and returns its duration. It ends no
    /// later than `limit`, so a phase cut short by an abandoned launch stays inside its parent.
    private func recordPhase(_ tracer: Tracer, _ name: String, parent: Span, start: Date?, end: Date?, limit: Date? = nil) -> TimeInterval? {
      guard let start, var end else { return nil }
      if let limit {
        end = min(end, limit)
      }
      guard start <= end else { return nil }
      tracer.spanBuilder(spanName: name)
        .setParent(parent)
        .setStartTime(time: start)
        .startSpan()
        .end(time: end)
      return end.timeIntervalSince(start)
    }

    private func recordDuration(_ name: String, seconds: TimeInterval, attributes: [String: AttributeValue]) {
      let meter = OpenTelemetry.instance.meterProvider.meterBuilder(name: AppLaunchRuntime.instrumentationScope).build()
      var histogram = meter.histogramBuilder(name: name).build()
      histogram.record(value: seconds, attributes: attributes)
    }

    private func milliseconds(_ seconds: TimeInterval) -> Int {
      Int((seconds * 1_000).rounded())
    }
  }

  private extension AppStartEnd {
    var time: Date {
      switch self {
      case let .firstFrame(time), let .abandoned(time): time
      }
    }

    var isCompleted: Bool {
      if case .firstFrame = self { return true }
      return false
    }
  }

  private extension AppLaunchRuntime.LaunchType {
    var schemaValue: FederatedSemanticConventions.App.StartTypeValues {
      switch self {
      case .cold: .cold
      case .warm: .warm
      case .prewarmed: .prewarmed
      // A resume is recorded as `app.resume`, so it never reaches this.
      case .resume: .warm
      }
    }
  }

  private extension ResumeKind {
    var schemaValue: FederatedSemanticConventions.App.ResumeTypeValues {
      switch self {
      case .hot: .hot
      case .sceneReconnect: .sceneReconnect
      case .backgroundLaunched: .backgroundLaunched
      }
    }
  }
#endif

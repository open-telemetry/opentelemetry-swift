/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  import Foundation
  import InstrumentationSemanticConventions
  import OpenTelemetryApi

  /// When the parts of a launch between the process starting and the app becoming active happened,
  /// if they were observed.
  package struct AppLaunchMarks: Sendable {
    package var didFinishLaunchingEnd: Date?
    package var sceneConnectStart: Date?
  }

  /// An activation, with its launch classified.
  package enum AppStart {
    case launch(LaunchClassification, AppLaunchMarks)
    case resume(AppResume)

    package var launchType: AppLaunchInstrumentationConfiguration.LaunchType {
      switch self {
      case let .launch(classification, _): classification.type
      case .resume: .resume
      }
    }
  }

  /// How an activation ended.
  package enum AppStartEnd {
    case firstFrame(Date)
    /// The app entered the background before the first frame.
    case abandoned(Date)
  }

  /// Decides which activations are recorded, and records them.
  package protocol AppStartRecording: Sendable {
    /// Returns what records `start` once it has ended, or `nil` if it won't be recorded.
    func prepare(_ start: AppStart) -> ((AppStartEnd) -> Void)?
  }

  /// Decides which activations are recorded, and records them as `AppStart` spans.
  struct AppStartRecorder: AppStartRecording {
    private typealias StartAttributes = FederatedSemanticConventions.Start

    let dependencies: AppLaunchRuntime.Dependencies

    func prepare(_ start: AppStart) -> ((AppStartEnd) -> Void)? {
      let launchType = start.launchType
      guard dependencies.configuration.launchTypes.contains(launchType) else {
        InternalLogger.debug("AppLaunchInstrumentation: not recording a \(launchType) start, because it isn't in `launchTypes`.")
        return nil
      }

      // Read when the app becomes active, so a tracer provider registered after install is used.
      let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: AppLaunchRuntime.instrumentationScope)

      switch start {
      case let .launch(classification, _):
        guard let processStartTime = dependencies.processStartTime() else {
          InternalLogger.warn("AppLaunchInstrumentation: dropped a \(launchType) launch, because the process start time can't be read.")
          return nil
        }
        return { end in
          guard case let .firstFrame(end) = end else { return }
          recordLaunch(tracer: tracer, classification: classification, processStartTime: processStartTime, end: end)
        }
      case let .resume(resume):
        return { end in
          guard case let .firstFrame(end) = end else { return }
          recordResume(tracer: tracer, start: resume.start, end: end)
        }
      }
    }

    private func recordResume(tracer: Tracer, start: Date, end: Date) {
      tracer.spanBuilder(spanName: AppLaunchRuntime.spanName)
        .setStartTime(time: start)
        .setAttribute(key: StartAttributes.type.rawValue, value: StartAttributes.TypeValues.resume.description)
        .startSpan()
        .end(time: end)
      InternalLogger.debug("AppLaunchInstrumentation: recorded a resume of \(milliseconds(end.timeIntervalSince(start))) ms.")
    }

    private func recordLaunch(tracer: Tracer, classification: LaunchClassification, processStartTime: Date, end: Date) {
      let type = classification.type
      let configuration = dependencies.configuration
      let isPrewarmed = dependencies.isActivePrewarm()
      if isPrewarmed, configuration.dropPrewarmed {
        InternalLogger.debug("AppLaunchInstrumentation: dropped a prewarmed \(type) launch, because `dropPrewarmed` is set.")
        return
      }
      // A prewarmed process started long before the user launched the app, so time the launch
      // from when app code first ran instead.
      let startTime = isPrewarmed ? dependencies.earliestAppCodeTime() ?? processStartTime : processStartTime
      // Too long for the user to have waited through all of it: a background launch that wasn't
      // detected, the prewarm ran app code, or the instrumentation was installed off the main
      // thread after the app first became active.
      if end.timeIntervalSince(startTime) > configuration.maxLaunchDuration {
        InternalLogger.warn(
          "AppLaunchInstrumentation: dropped a \(type) launch of \(milliseconds(end.timeIntervalSince(startTime))) ms, which is longer than `maxLaunchDuration`."
        )
        return
      }

      let span = tracer.spanBuilder(spanName: AppLaunchRuntime.spanName)
        .setStartTime(time: startTime)
        .setAttribute(key: StartAttributes.type.rawValue, value: type.startTypeValue.description)
        .setAttribute(key: StartAttributes.activePrewarmed.rawValue, value: isPrewarmed)
        .startSpan()
      classification.attributes.forEach { span.setAttribute(key: $0.key, value: $0.value) }
      span.end(time: end)
      InternalLogger.debug(
        "AppLaunchInstrumentation: recorded a \(type) launch of \(milliseconds(end.timeIntervalSince(startTime))) ms, prewarmed \(isPrewarmed)."
      )
    }

    private func milliseconds(_ seconds: TimeInterval) -> Int {
      Int((seconds * 1_000).rounded())
    }
  }

  extension AppLaunchInstrumentationConfiguration.LaunchType {
    var startTypeValue: FederatedSemanticConventions.Start.TypeValues {
      switch self {
      case .cold: .cold
      case .warm: .warm
      case .resume: .resume
      case .prewarmed: .prewarmed
      }
    }
  }
#endif

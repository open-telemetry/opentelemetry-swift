/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  import Foundation
  import InstrumentationSemanticConventions
  import OpenTelemetryApi

  /// Decides which activations are recorded, and records them as `AppStart` spans.
  struct AppStartRecorder: Sendable {
    private typealias StartAttributes = FederatedSemanticConventions.Start

    let dependencies: AppLaunchInstrumentation.Dependencies

    /// Returns what records `activation` once its end time is known, or `nil` if it won't be
    /// recorded.
    func prepare(_ activation: Activation) -> ((Date) -> Void)? {
      let launchType = activation.launchType
      guard dependencies.configuration.launchTypes.contains(launchType) else {
        InternalLogger.debug("AppLaunchInstrumentation: not recording a \(launchType) start, because it isn't in `launchTypes`.")
        return nil
      }

      // Read when the app becomes active, so a tracer provider registered after install is used.
      let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: AppLaunchInstrumentation.instrumentationScope)

      switch activation {
      case let .launch(type):
        guard let processStartTime = dependencies.processStartTime() else {
          InternalLogger.warn("AppLaunchInstrumentation: dropped a \(type) launch, because the process start time can't be read.")
          return nil
        }
        return { end in
          recordLaunch(tracer: tracer, type: type, processStartTime: processStartTime, end: end)
        }
      case let .resume(start):
        return { end in
          recordResume(tracer: tracer, start: start, end: end)
        }
      }
    }

    private func recordResume(tracer: Tracer, start: Date, end: Date) {
      tracer.spanBuilder(spanName: AppLaunchInstrumentation.spanName)
        .setStartTime(time: start)
        .setAttribute(key: StartAttributes.type.rawValue, value: StartAttributes.TypeValues.resume.description)
        .startSpan()
        .end(time: end)
      InternalLogger.debug("AppLaunchInstrumentation: recorded a resume of \(milliseconds(end.timeIntervalSince(start))) ms.")
    }

    private func recordLaunch(tracer: Tracer, type: AppLaunchInstrumentationConfiguration.LaunchType, processStartTime: Date, end: Date) {
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

      tracer.spanBuilder(spanName: AppLaunchInstrumentation.spanName)
        .setStartTime(time: startTime)
        .setAttribute(key: StartAttributes.type.rawValue, value: type.startTypeValue.description)
        .setAttribute(key: StartAttributes.activePrewarmed.rawValue, value: isPrewarmed)
        .startSpan()
        .end(time: end)
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
      }
    }
  }
#endif

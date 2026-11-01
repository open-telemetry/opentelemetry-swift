/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@_exported import AppLaunchInstrumentationCore
import InstrumentationCommon
import OpenTelemetryApi

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  /// Records each launch as an `app.start` span and each resume as an `app.resume` span, with a child span per phase and a duration metric. It measures `cold` and `warm`
  /// instead of inferring them: it compares a sample of the app's code pages before `main()` with
  /// the same pages when the app becomes active. Prewarmed launches are `prewarmed`.
  ///
  /// Linking this library runs `mincore` before `main()`, so unlike a configuration option it can't
  /// be turned off at runtime.
  ///
  /// Supported on iOS, iPadOS, tvOS, visionOS, Mac Catalyst and macOS. On watchOS this does nothing.
  public class MincoreLaunchInstrumentation: Instrumentation {
    typealias Dependencies = AppLaunchRuntime.Dependencies

    /// Whether the instrumentation is installed and observing app activations.
    public static var isInstalled: Bool { AppLaunchRuntime.isInstalled }

    /// Installs the instrumentation, the same as `install(configuration:)`. If it's already
    /// installed, `configuration` is ignored.
    public init(configuration: AppLaunchInstrumentationConfiguration = .init()) {
      super.init(scope: AppLaunchRuntime.instrumentationScope)
      Self.install(configuration: configuration)
    }

    /// Starts observing app activations. Idempotent and thread-safe. Call it as early as
    /// possible, before the app first becomes active, so the launch is recorded. Only the first
    /// call takes effect.
    public static func install(configuration: AppLaunchInstrumentationConfiguration = .init()) {
      let pageSampler = KernelLaunchPageSampler()
      install(dependencies: Dependencies(
        configuration: validated(configuration),
        makeClassifier: { dependencies in
          MincoreLaunchClassifier(
            fallback: InferredLaunchClassifier(dependencies: dependencies),
            pageSampler: pageSampler,
            isActivePrewarm: dependencies.isActivePrewarm,
            coldPageInRatio: dependencies.configuration.coldPageInRatio
          )
        },
        makeRecorder: { MincoreAppStartRecorder(dependencies: $0, pageSampler: pageSampler) }
      ))
    }

    static func install(dependencies: Dependencies) {
      AppLaunchRuntime.install(dependencies: dependencies)
    }

    /// A threshold outside its range would make every launch the same type, so it's replaced with
    /// the default.
    static func validated(_ configuration: AppLaunchInstrumentationConfiguration) -> AppLaunchInstrumentationConfiguration {
      var validated = configuration
      if !(configuration.coldPageInRatio > 0 && configuration.coldPageInRatio <= 1) {
        InternalLogger.error("`coldPageInRatio` must be above 0 and at most 1, so the default is used.")
        validated.coldPageInRatio = AppLaunchInstrumentationConfiguration().coldPageInRatio
      }
      return validated
    }
  }
#else
  /// Does nothing, because this platform isn't supported, so code shared with a supported platform
  /// doesn't need its own check. Supported on iOS, iPadOS, tvOS, visionOS, Mac Catalyst and macOS.
  public class MincoreLaunchInstrumentation: Instrumentation {
    private static let instrumentationScope = "io.opentelemetry.lifecycle"

    /// Always `false`.
    public static var isInstalled: Bool { false }

    public init(configuration: AppLaunchInstrumentationConfiguration = .init()) {
      super.init(scope: Self.instrumentationScope)
    }

    public static func install(configuration: AppLaunchInstrumentationConfiguration = .init()) {}
  }
#endif

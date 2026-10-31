/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@_exported import AppLaunchInstrumentationCore
import InstrumentationCommon
import OpenTelemetryApi

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  /// Records each activation of the app as an `AppStart` span, like
  /// `InferredAppLaunchInstrumentation`, but measures `cold` and `warm` instead of inferring them:
  /// it compares a sample of the app's code pages before `main()` with the same pages when the app
  /// becomes active. Prewarmed launches are `prewarmed`.
  ///
  /// Linking this library runs `mincore` before `main()`, so unlike a configuration option it can't
  /// be turned off at runtime. Link only one app launch library.
  ///
  /// Supported on iOS, iPadOS, tvOS, visionOS, Mac Catalyst and macOS. On watchOS this does nothing.
  public class MeasuredAppLaunchInstrumentation: Instrumentation {
    typealias Dependencies = AppLaunchRuntime.Dependencies

    /// Records every launch type, including `prewarmed`.
    public static let defaultConfiguration = AppLaunchInstrumentationConfiguration(
      launchTypes: Set(AppLaunchInstrumentationConfiguration.LaunchType.allCases)
    )

    /// Whether the instrumentation is installed and observing app activations.
    public static var isInstalled: Bool { AppLaunchRuntime.isInstalled }

    /// Installs the instrumentation, the same as `install(configuration:)`. If it's already
    /// installed, `configuration` is ignored.
    public init(configuration: AppLaunchInstrumentationConfiguration = defaultConfiguration) {
      super.init(scope: AppLaunchRuntime.instrumentationScope)
      Self.install(configuration: configuration)
    }

    /// Starts observing app activations. Idempotent and thread-safe. Call it as early as
    /// possible, before the app first becomes active, so the launch is recorded. Only the first
    /// call takes effect.
    public static func install(configuration: AppLaunchInstrumentationConfiguration = defaultConfiguration) {
      var dependencies = Dependencies(configuration: configuration)
      dependencies.makeClassifier = { dependencies in
        MeasuredLaunchClassifier(
          fallback: InferredLaunchClassifier(dependencies: dependencies),
          pageSampler: KernelLaunchPageSampler(),
          isActivePrewarm: dependencies.isActivePrewarm
        )
      }
      install(dependencies: dependencies)
    }

    static func install(dependencies: Dependencies) {
      AppLaunchRuntime.install(dependencies: dependencies)
    }
  }
#else
  /// Does nothing, because this platform isn't supported, so code shared with a supported platform
  /// doesn't need its own check. Supported on iOS, iPadOS, tvOS, visionOS, Mac Catalyst and macOS.
  public class MeasuredAppLaunchInstrumentation: Instrumentation {
    private static let instrumentationScope = "io.opentelemetry.lifecycle"

    /// Records every launch type, including `prewarmed`.
    public static let defaultConfiguration = AppLaunchInstrumentationConfiguration(
      launchTypes: Set(AppLaunchInstrumentationConfiguration.LaunchType.allCases)
    )

    /// Always `false`.
    public static var isInstalled: Bool { false }

    public init(configuration: AppLaunchInstrumentationConfiguration = defaultConfiguration) {
      super.init(scope: Self.instrumentationScope)
    }

    public static func install(configuration: AppLaunchInstrumentationConfiguration = defaultConfiguration) {}
  }
#endif

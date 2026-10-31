/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@_exported import AppLaunchInstrumentationCore
import InstrumentationCommon
import OpenTelemetryApi

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  /// Records each activation of the app, as Apple defines it, as an `AppStart` span that ends at
  /// the first frame displayed after the app becomes active:
  ///
  /// - `cold`: a launch the system is unlikely to have cached: the app's first launch, or its
  ///   first launch after a reboot or an app update. Starts at process start.
  /// - `warm`: any other launch. Starts at process start.
  /// - `resume`: the app's process was still alive. Starts when the app begins returning to the
  ///   foreground.
  ///
  /// Launches that iOS prewarmed are marked with `start.active_prewarmed` and start when app code
  /// first ran. On macOS only launches are recorded, and they end when the app becomes active.
  ///
  /// Supported on iOS, iPadOS, tvOS, visionOS, Mac Catalyst and macOS. On watchOS this does nothing.
  ///
  /// This library infers `cold` and `warm` from what changed since the previous launch.
  /// `MeasuredAppLaunchInstrumentation` measures them instead. Link only one of them.
  public class InferredAppLaunchInstrumentation: Instrumentation {
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
    /// possible, before the app first becomes active, so the launch is recorded. If it's called on
    /// the main thread while the app is active, the launch isn't recorded and the next activation
    /// is recorded as `resume`. Called later than that while the app is inactive or in the
    /// background, the next activation is recorded as a launch from process start, because a
    /// scene-based app is also in the background state during a normal launch.
    ///
    /// Only the first call takes effect. A later call with a different configuration is ignored
    /// and reported through `OpenTelemetry.instance.feedbackHandler`.
    public static func install(configuration: AppLaunchInstrumentationConfiguration = .init()) {
      install(dependencies: Dependencies(configuration: configuration))
    }

    static func install(dependencies: Dependencies) {
      AppLaunchRuntime.install(dependencies: dependencies)
    }

    /// Removes the observers and clears all state so the next install starts over. Tests only.
    static func reset() {
      AppLaunchRuntime.reset()
    }

    static func readIsAppActive() -> Bool {
      AppLaunchRuntime.readIsAppActive()
    }
  }
#else
  /// Does nothing, because this platform isn't supported, so code shared with a supported platform
  /// doesn't need its own check. Supported on iOS, iPadOS, tvOS, visionOS, Mac Catalyst and macOS.
  public class InferredAppLaunchInstrumentation: Instrumentation {
    private static let instrumentationScope = "io.opentelemetry.lifecycle"

    /// Always `false`.
    public static var isInstalled: Bool { false }

    public init(configuration: AppLaunchInstrumentationConfiguration = .init()) {
      super.init(scope: Self.instrumentationScope)
    }

    public static func install(configuration: AppLaunchInstrumentationConfiguration = .init()) {}
  }
#endif

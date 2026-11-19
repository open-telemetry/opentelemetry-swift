/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !CrashReporting

  @available(*, unavailable, message: "Crash requires the `CrashReporting` package trait.")
  public class KSCrashInstrumentationConfig {
    public var maxStackTraceBytes: Int = 0

    public static var `default`: KSCrashInstrumentationConfig {
      KSCrashInstrumentationConfig()
    }

    public init() {}
  }

  @available(*, unavailable, message: "Crash requires the `CrashReporting` package trait.")
  public class KSCrashInstrumentation {
    public static var isInstalled: Bool {
      false
    }

    public init(config: KSCrashInstrumentationConfig = .default) {}

    public static func install(config: KSCrashInstrumentationConfig = .default) {}
  }

#endif

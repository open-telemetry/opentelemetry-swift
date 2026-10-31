/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin)
  import AppLaunchEnvironment
  import Foundation

  /// Whether the system set `ActivePrewarm=1` when it created this process.
  func readIsActivePrewarm() -> Bool {
    otel_app_launch_is_active_prewarm()
  }

  /// Whether the system started this process in the background rather than for the user.
  func readIsBackgroundLaunch() -> Bool {
    otel_app_launch_is_background_launch()
  }

  /// When app code first ran in this process, or `nil` if it can't be read.
  func readEarliestAppCodeTime() -> Date? {
    let time = otel_app_launch_initializer_time()
    return time > 0 ? Date(timeIntervalSince1970: time) : nil
  }
#endif

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public struct AppLaunchInstrumentationConfiguration: Equatable, Sendable {
  /// The kind of activation an `AppStart` span describes, reported as its `start.type`.
  public enum LaunchType: CaseIterable, Sendable {
    /// A new process the system is unlikely to have cached: the app's first launch, or its first
    /// launch after a reboot or an app update.
    case cold
    /// Any other new process.
    case warm
    /// The app's process was still alive.
    case resume
  }

  /// The launch types to record. Activations of other types are still tracked, so later ones are
  /// classified correctly, but don't produce spans.
  public var launchTypes: Set<LaunchType>

  /// Whether to drop launches that the system prewarmed instead of recording them. A prewarmed
  /// launch is timed from when app code first ran, so it leaves out the work the system did ahead
  /// of time. Like Sentry's `enablePreWarmedAppStartTracing`, prewarmed launches are recorded by
  /// default and marked with `start.active_prewarmed`.
  public var dropPrewarmed: Bool

  /// The longest launch, in seconds, that's recorded. A longer launch wasn't waited through by the
  /// user, for example because the system launched the app in the background. Like Datadog, it's
  /// measured from process start, or from when app code first ran for a prewarmed launch, and
  /// the default is 60 seconds.
  public var maxLaunchDuration: TimeInterval

  public init(launchTypes: Set<LaunchType> = [.cold, .warm, .resume],
              dropPrewarmed: Bool = false,
              maxLaunchDuration: TimeInterval = 60) {
    self.launchTypes = launchTypes
    self.dropPrewarmed = dropPrewarmed
    self.maxLaunchDuration = maxLaunchDuration
  }
}

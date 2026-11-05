/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public struct AppLaunchInstrumentationConfiguration: Equatable, Sendable {
  /// The kind of activation an `app.start` or `app.resume` span describes.
  public enum LaunchType: CaseIterable, Sendable {
    /// A new process whose launch had to page in the app's code from disk, as Apple defines a cold
    /// launch: typically the app's first launch, or its first launch after a reboot or an app
    /// update. It's `cold` when the share of sampled code the launch paged in is at least
    /// `coldPageInRatio`. A launch that found the app's code in memory is `warm` even if it's the
    /// first.
    case cold
    /// Any other new process: the app's code was already in memory, so the launch paged in little
    /// or none of it.
    case warm
    /// The app's process was still alive.
    case resume
    /// A launch the system prewarmed, so the libraries were already loaded when the user launched
    /// it. It's timed from when app code first ran.
    case prewarmed
  }

  /// The launch types to record. Activations of other types are still tracked, so later ones are
  /// classified correctly, but don't produce spans. By default every type is recorded.
  public var launchTypes: Set<LaunchType>

  /// The longest launch, in seconds, that's recorded. A longer launch wasn't waited through by the
  /// user, for example because a background launch wasn't detected. Like Datadog, it's
  /// measured from process start, or from when app code first ran for a prewarmed launch, and
  /// the default is 60 seconds.
  public var maxLaunchDuration: TimeInterval

  /// The share of sampled code, `app.start.pages.text.page_in_ratio`, that a launch must page in from
  /// disk to be `cold`, above 0 and at most 1. Apple describes cold and warm launches as a
  /// spectrum, so this is where this library draws the line. The default of 0.5 means at least half
  /// of the launch's code had to come from disk. Check the ratios your app reports before changing
  /// it, because how high they go depends on the app.
  ///
  /// The line is drawn on the device, so `app.start.type` carries this library's verdict rather
  /// than a property of the launch. The measurements it was computed from are reported too:
  /// `app.start.pages.text.page_in_ratio` and the `paged_in`, `resident_at_end`, `sampled` and
  /// `total` counts behind it. A backend that prefers a different line can recalculate from those
  /// and ignore `app.start.type`. Two caveats: this threshold isn't reported, so a span doesn't say
  /// which line produced its label, and the measurements are only present when
  /// `app.start.determined_by` is `page_sampling` — a launch that fell back to `launch_history` has
  /// no ratio to recalculate from.
  public var coldPageInRatio: Double

  /// - Parameter launchTypes: The launch types to record. By default all of them.
  public init(launchTypes: Set<LaunchType> = Set(LaunchType.allCases),
              maxLaunchDuration: TimeInterval = 60,
              coldPageInRatio: Double = 0.5) {
    self.launchTypes = launchTypes
    self.maxLaunchDuration = maxLaunchDuration
    self.coldPageInRatio = coldPageInRatio
  }
}

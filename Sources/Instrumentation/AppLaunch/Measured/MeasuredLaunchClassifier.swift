/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  import AppLaunchInstrumentationCore
  import AppLaunchPageSampling
  import InstrumentationSemanticConventions
  import OpenTelemetryApi

  /// How the app's sampled pages changed between process start and the app becoming active.
  struct LaunchPageSample: Equatable, Sendable {
    var residentAtEnd: Int
    var pagedIn: Int

    /// How much of what the launch ended up with in memory it had to bring in, from 0 to 1, or
    /// `nil` if nothing was in memory to compare.
    var pageInRatio: Double? {
      residentAtEnd > 0 ? Double(pagedIn) / Double(residentAtEnd) : nil
    }
  }

  protocol LaunchPageSampler: Sendable {
    func readSample() -> LaunchPageSample?
  }

  /// Compares the pages now with the sample the `AppLaunchPageSampling` initializer took.
  struct KernelLaunchPageSampler: LaunchPageSampler {
    func readSample() -> LaunchPageSample? {
      var residentAtEnd: Int32 = 0
      var pagedIn: Int32 = 0
      guard otel_app_launch_read_page_sample(&residentAtEnd, &pagedIn) else { return nil }
      return LaunchPageSample(residentAtEnd: Int(residentAtEnd), pagedIn: Int(pagedIn))
    }
  }

  /// Measures the launch type from how much of the app's code the launch had to bring into memory.
  /// Infers it instead if that can't be read.
  struct MeasuredLaunchClassifier: LaunchClassifier {
    private typealias StartAttributes = FederatedSemanticConventions.Start

    // At least half of the launch's code had to come from disk.
    static let coldPageInRatio = 0.5

    let fallback: LaunchClassifier
    let pageSampler: LaunchPageSampler
    let isActivePrewarm: @Sendable () -> Bool

    func begin() -> @Sendable () -> LaunchClassification {
      // Always started, so the launch history stays current for launches that can't be measured.
      let inferred = fallback.begin()
      return { [pageSampler, isActivePrewarm] in
        let isPrewarmed = isActivePrewarm()
        guard let sample = pageSampler.readSample(), let ratio = sample.pageInRatio else {
          InternalLogger.warn("AppLaunchInstrumentation: couldn't sample the launch's pages, so the launch type is inferred.")
          return isPrewarmed ? LaunchClassification(type: .prewarmed) : inferred()
        }
        // A prewarm loads the libraries ahead of time, so the ratio says nothing about the cache.
        let type: AppLaunchInstrumentationConfiguration.LaunchType =
          isPrewarmed ? .prewarmed : ratio >= Self.coldPageInRatio ? .cold : .warm
        return LaunchClassification(type: type, attributes: [
          StartAttributes.sampledPagesResidentAtEnd.rawValue: .int(sample.residentAtEnd),
          StartAttributes.sampledPagesPagedIn.rawValue: .int(sample.pagedIn),
          StartAttributes.sampledPageInRatio.rawValue: .double(ratio),
        ])
      }
    }
  }
#endif

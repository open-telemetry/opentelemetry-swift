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
    var sampled = 256

    /// How much of what the launch ended up with in memory it had to bring in, from 0 to 1, or
    /// `nil` if nothing was in memory to compare.
    var pageInRatio: Double? {
      residentAtEnd > 0 ? Double(pagedIn) / Double(residentAtEnd) : nil
    }
  }

  /// The process's page-ins on either side of the `AppLaunchPageSampling` initializer.
  struct LaunchPageIns: Equatable, Sendable {
    var preInitializer: Int
    var postInitializer: Int
  }

  protocol LaunchPageSampler: Sendable {
    func readSample() -> LaunchPageSample?
    func readPageIns() -> LaunchPageIns?
  }

  /// Compares the pages now with the sample the `AppLaunchPageSampling` initializer took.
  struct KernelLaunchPageSampler: LaunchPageSampler {
    func readSample() -> LaunchPageSample? {
      var sampled: Int32 = 0
      var residentAtEnd: Int32 = 0
      var pagedIn: Int32 = 0
      guard otel_app_launch_read_page_sample(&sampled, &residentAtEnd, &pagedIn) else { return nil }
      return LaunchPageSample(residentAtEnd: Int(residentAtEnd), pagedIn: Int(pagedIn), sampled: Int(sampled))
    }

    func readPageIns() -> LaunchPageIns? {
      var preInitializer: Int32 = 0
      var postInitializer: Int32 = 0
      guard otel_app_launch_read_page_ins(&preInitializer, &postInitializer) else { return nil }
      return LaunchPageIns(preInitializer: Int(preInitializer), postInitializer: Int(postInitializer))
    }
  }

  /// Measures the launch type from how much of the app's code the launch had to bring into memory.
  /// Infers it instead if that can't be read.
  struct MincoreLaunchClassifier: LaunchClassifier {
    private typealias App = FederatedSemanticConventions.App

    // Fewer resident pages than this are too few for a ratio to mean anything, unless that's all
    // the app has. Real launches had over 100 in testing.
    static let minimumResidentPages = 16

    let fallback: LaunchClassifier
    let pageSampler: LaunchPageSampler
    let isActivePrewarm: @Sendable () -> Bool
    let coldPageInRatio: Double

    func begin() -> @Sendable () -> LaunchClassification {
      // Always started, so the launch history stays current for launches that can't be measured.
      let inferred = fallback.begin()
      return { [pageSampler, isActivePrewarm, coldPageInRatio] in
        let isPrewarmed = isActivePrewarm()
        guard let sample = pageSampler.readSample(),
              sample.residentAtEnd >= min(Self.minimumResidentPages, sample.sampled),
              let ratio = sample.pageInRatio else {
          InternalLogger.warn("MincoreLaunchInstrumentation: couldn't sample the launch's pages, so the launch type is inferred.")
          if isPrewarmed {
            return LaunchClassification(type: .prewarmed, attributes: Self.determinedBy(.prewarmFlag))
          }
          var classification = inferred()
          classification.attributes = Self.determinedBy(.launchHistory)
          return classification
        }
        let isCold = ratio >= coldPageInRatio
        let type: AppLaunchInstrumentationConfiguration.LaunchType = isPrewarmed ? .prewarmed : isCold ? .cold : .warm
        var attributes = Self.determinedBy(isPrewarmed ? .prewarmFlag : .pageSampling)
        attributes[App.startSampledPagesTotal.rawValue] = .int(sample.sampled)
        attributes[App.startSampledPagesResidentAtEnd.rawValue] = .int(sample.residentAtEnd)
        attributes[App.startSampledPagesPagedIn.rawValue] = .int(sample.pagedIn)
        attributes[App.startSampledPageInRatio.rawValue] = .double(ratio)
        if isPrewarmed {
          let cacheState: App.StartPrewarmCacheStateValues = isCold ? .cold : .warm
          attributes[App.startPrewarmCacheState.rawValue] = .string(cacheState.description)
        }
        return LaunchClassification(type: type, attributes: attributes)
      }
    }

    private static func determinedBy(_ value: App.StartDeterminedByValues) -> [String: AttributeValue] {
      [App.startDeterminedBy.rawValue: .string(value.description)]
    }
  }
#endif

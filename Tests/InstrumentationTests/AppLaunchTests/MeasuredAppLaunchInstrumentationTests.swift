/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  @testable import AppLaunchInstrumentationCore
  @testable import InferredAppLaunchInstrumentation
  @testable import MeasuredAppLaunchInstrumentation
  import Foundation
  import OpenTelemetryApi
  import OpenTelemetrySdk
  import XCTest

  struct FakeLaunchPageSampler: LaunchPageSampler {
    var sample: LaunchPageSample?

    func readSample() -> LaunchPageSample? {
      sample
    }
  }

  extension InferredAppLaunchInstrumentationTests {
    private func installMeasured(sample: LaunchPageSample?,
                                 isActivePrewarm: Bool = false,
                                 configuration: AppLaunchInstrumentationConfiguration = MeasuredAppLaunchInstrumentation.defaultConfiguration) {
      MeasuredAppLaunchInstrumentation.install(
        dependencies: measuredDependencies(sample: sample, isActivePrewarm: isActivePrewarm, configuration: configuration)
      )
    }

    private func measuredDependencies(sample: LaunchPageSample?,
                                      isActivePrewarm: Bool = false,
                                      configuration: AppLaunchInstrumentationConfiguration = MeasuredAppLaunchInstrumentation.defaultConfiguration) -> MeasuredAppLaunchInstrumentation.Dependencies {
      var dependencies = makeDependencies(isActivePrewarm: isActivePrewarm, configuration: configuration)
      dependencies.makeClassifier = { dependencies in
        MeasuredLaunchClassifier(
          fallback: InferredLaunchClassifier(dependencies: dependencies),
          pageSampler: FakeLaunchPageSampler(sample: sample),
          isActivePrewarm: dependencies.isActivePrewarm
        )
      }
      return dependencies
    }

    private func activate() {
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame)
    }

    func testMeasuredLaunchThatPagedInMostOfItsCodeIsCold() {
      launchHistory = FakeLaunchHistory(previous: launchContext)
      installMeasured(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 120))

      activate()

      let attributes = finishedSpans().first?.attributes
      XCTAssertEqual(attributes?["start.type"], .string("cold"))
      XCTAssertEqual(attributes?["start.sampled_pages.resident_at_end"], .int(128))
      XCTAssertEqual(attributes?["start.sampled_pages.paged_in"], .int(120))
      XCTAssertEqual(attributes?["start.sampled_page_in_ratio"], .double(0.9375))
    }

    func testMeasuredLaunchThatFoundItsCodeInMemoryIsWarm() {
      // No launch history, so inference would have said `cold`.
      installMeasured(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0))

      activate()

      XCTAssertEqual(finishedSpans().first?.attributes["start.type"], .string("warm"))
      XCTAssertEqual(finishedSpans().first?.attributes["start.sampled_page_in_ratio"], .double(0))
    }

    func testMeasuredLaunchAtTheThresholdIsCold() {
      installMeasured(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 64))

      activate()

      XCTAssertEqual(finishedSpans().first?.attributes["start.type"], .string("cold"))
    }

    func testMeasuredLaunchJustBelowTheThresholdIsWarm() {
      installMeasured(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 63))

      activate()

      XCTAssertEqual(finishedSpans().first?.attributes["start.type"], .string("warm"))
    }

    func testPrewarmedMeasuredLaunchIsPrewarmedAndKeepsItsSample() {
      installMeasured(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 120), isActivePrewarm: true)

      activate()

      let attributes = finishedSpans().first?.attributes
      XCTAssertEqual(attributes?["start.type"], .string("prewarmed"))
      XCTAssertEqual(attributes?["start.active_prewarmed"], .bool(true))
      XCTAssertEqual(attributes?["start.sampled_pages.paged_in"], .int(120))
    }

    func testPrewarmedLaunchThatCantBeSampledIsStillPrewarmed() {
      installMeasured(sample: nil, isActivePrewarm: true)

      activate()

      XCTAssertEqual(finishedSpans().first?.attributes["start.type"], .string("prewarmed"))
      XCTAssertNil(finishedSpans().first?.attributes["start.sampled_page_in_ratio"])
    }

    func testPrewarmedCanBeLeftOutOfLaunchTypes() {
      installMeasured(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0),
                      isActivePrewarm: true,
                      configuration: AppLaunchInstrumentationConfiguration(launchTypes: [.cold, .warm, .resume]))

      activate()

      XCTAssertTrue(finishedSpans().isEmpty)
    }

    func testLaunchThatCantBeSampledIsInferredWithoutSampleAttributes() {
      launchHistory = FakeLaunchHistory(previous: launchContext)
      let messages = captureFeedback()
      OpenTelemetry.setDebugEnabled(true)
      installMeasured(sample: nil)

      activate()

      let attributes = finishedSpans().first?.attributes
      XCTAssertEqual(attributes?["start.type"], .string("warm"))
      XCTAssertNil(attributes?["start.sampled_pages.resident_at_end"])
      XCTAssertNil(attributes?["start.sampled_pages.paged_in"])
      XCTAssertNil(attributes?["start.sampled_page_in_ratio"])
      XCTAssertTrue(messages.values.contains { $0.hasPrefix("[warn]") && $0.contains("inferred") })
    }

    func testLaunchWithNoResidentPagesIsInferred() {
      launchHistory = FakeLaunchHistory(previous: launchContext)
      installMeasured(sample: LaunchPageSample(residentAtEnd: 0, pagedIn: 0))

      activate()

      XCTAssertEqual(finishedSpans().first?.attributes["start.type"], .string("warm"))
      XCTAssertNil(finishedSpans().first?.attributes["start.sampled_page_in_ratio"])
    }

    func testMeasuredInstallStillUpdatesLaunchHistory() {
      installMeasured(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0))

      XCTAssertEqual(launchHistory.exchangeCount, 1)
    }

    func testResumeHasNoSampleAttributes() {
      installMeasured(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 0))
      activate()

      post(didEnterBackground)
      post(willEnterForeground)
      post(didBecomeActive)
      firstFrameReader.displayFrame(at: firstFrame.addingTimeInterval(10))

      let resume = finishedSpans().last
      XCTAssertEqual(resume?.attributes["start.type"], .string("resume"))
      XCTAssertNil(resume?.attributes["start.sampled_page_in_ratio"])
    }

    func testSecondLibraryIsIgnoredAndReported() {
      let messages = captureFeedback()
      install()

      installMeasured(sample: LaunchPageSample(residentAtEnd: 128, pagedIn: 120),
                      configuration: AppLaunchInstrumentationConfiguration())
      activate()

      XCTAssertEqual(messages.values.count, 1)
      XCTAssertTrue(messages.values.first?.contains("different library") ?? false)
      XCTAssertEqual(finishedSpans().count, 1, "a start must only be recorded once")
      XCTAssertNil(finishedSpans().first?.attributes["start.sampled_page_in_ratio"])
    }

    func testPageInRatio() {
      XCTAssertEqual(LaunchPageSample(residentAtEnd: 4, pagedIn: 1).pageInRatio, 0.25)
      XCTAssertNil(LaunchPageSample(residentAtEnd: 0, pagedIn: 0).pageInRatio)
    }

    // `xctest` is a single page, the header the sampler skips, so there's nothing to sample here. The
    // `app-start-measured` integration launch covers the sampler in a real app.
    func testKernelSamplerReportsNothingForAnImageWithNoCode() {
      XCTAssertNil(KernelLaunchPageSampler().readSample())
    }
  }
#endif

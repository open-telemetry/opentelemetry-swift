/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
@testable import ResourceExtension
import SharedTestUtils
import XCTest

/// Stress tests for resource detection. Some data sources hop to the main
/// queue when called from another thread, so the workers run off the main
/// thread while the test pumps the main run loop. They only run under Thread
/// Sanitizer (or with `OTEL_CONCURRENCY_TESTS=1`).
final class ResourceExtensionConcurrencyTests: XCTestCase {
  override func setUpWithError() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
  }

  private func runOffMainThread(timeout: TimeInterval = 120, _ body: @escaping @Sendable () -> Void) {
    let finished = expectation(description: "workers finished")
    Thread.detachNewThread {
      body()
      finished.fulfill()
    }
    wait(for: [finished], timeout: timeout)
  }

  func testDefaultResourcesFromManyBackgroundThreads() {
    let resources = UncheckedSendable(DefaultResources())
    let expected = UncheckedSendable(resources.value.get())
    let mismatches = ConcurrentCounter()

    runOffMainThread {
      ConcurrencyTesting.stress(threads: ConcurrencyTesting.defaultThreads, iterations: 20) { _, _ in
        let resource = resources.value.get()
        if resource.attributes != expected.value.attributes {
          mismatches.increment()
        }
      }
    }

    XCTAssertEqual(mismatches.value, 0)
  }

  func testDataSourcesFromManyBackgroundThreads() {
    let reads = ConcurrentCounter()

    runOffMainThread {
      ConcurrencyTesting.stress(threads: ConcurrencyTesting.defaultThreads, iterations: 20) { _, _ in
        let device = DeviceDataSource()
        _ = device.model
        _ = device.identifier
        let os = OperatingSystemDataSource()
        _ = os.name
        _ = os.version
        _ = os.description
        _ = os.type
        let application = ApplicationDataSource()
        _ = application.name
        _ = application.identifier
        _ = application.version
        _ = application.build
        _ = TelemetryDataSource().version
        reads.increment()
      }
    }

    XCTAssertEqual(reads.value, ConcurrencyTesting.defaultThreads * 20)
  }
}

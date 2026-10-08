/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest

final class ResourceAttributesTests: XCTestCase {
  private func assertResource(_ resource: ProtoAttributes, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(resource.string("service.name"), "HackerNewsDemo", file: file, line: line)
    XCTAssertEqual(resource.string("service.version"), "1.0.0", file: file, line: line)
    XCTAssertEqual(resource.string("telemetry.sdk.name"), "opentelemetry", file: file, line: line)
    XCTAssertEqual(resource.string("telemetry.sdk.language"), "swift", file: file, line: line)
    XCTAssertNotNil(resource.string("telemetry.sdk.version"), file: file, line: line)
    XCTAssertEqual(resource.string("os.type"), "darwin", file: file, line: line)
    XCTAssertEqual(resource.string("os.name"), "iOS", file: file, line: line)
    XCTAssertNotNil(resource.string("os.version"), file: file, line: line)
    XCTAssertNotNil(resource.string("os.description"), file: file, line: line)
    XCTAssertNotNil(resource.string("device.id"), file: file, line: line)
    XCTAssertNotNil(resource.string("device.model.identifier"), file: file, line: line)
  }

  func testSpansCarryResourceAttributes() {
    XCTAssertFalse(OTLPOutput.spans.isEmpty)
    for exported in OTLPOutput.spans {
      assertResource(exported.resource)
    }
  }

  func testLogsCarryResourceAttributes() {
    XCTAssertFalse(OTLPOutput.logs.isEmpty)
    for exported in OTLPOutput.logs {
      assertResource(exported.resource)
    }
  }
}

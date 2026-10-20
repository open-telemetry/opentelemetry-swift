//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class InMemoryLogExporterTests: XCTestCase {
  let exporter = InMemoryLogRecordExporter()

  func testInMemoryExporter() {
    XCTAssertEqual(exporter.export(logRecords: [ReadableLogRecord(resource: Resource(), instrumentationScopeInfo: InstrumentationScopeInfo(name: "default"), timestamp: Date(), attributes: [String: AttributeValue]())]), .success)
    XCTAssertEqual(exporter.getFinishedLogRecords().count, 1)
    XCTAssertEqual(exporter.forceFlush(), .success)

    exporter.shutdown()

    XCTAssertEqual(exporter.getFinishedLogRecords().count, 0)
    XCTAssertEqual(exporter.export(logRecords: [ReadableLogRecord(resource: Resource(), instrumentationScopeInfo: InstrumentationScopeInfo(name: "default"), timestamp: Date(), attributes: [String: AttributeValue]())]), .failure)
    XCTAssertEqual(exporter.forceFlush(), .failure)
  }
}

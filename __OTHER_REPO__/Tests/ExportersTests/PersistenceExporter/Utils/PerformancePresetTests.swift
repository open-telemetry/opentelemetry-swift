/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import PersistenceExporter
import XCTest

class PerformancePresetTests: XCTestCase {
  func testDefaultPreset() {
    XCTAssertEqual(PersistencePerformancePreset.default, .lowRuntimeImpact)
  }

  func testPresetsConsistency() {
    let presets: [PersistencePerformancePreset] = [.lowRuntimeImpact, .instantDataDelivery]

    presets.forEach { preset in
      XCTAssertLessThan(preset.maxFileSize,
                        preset.maxDirectorySize,
                        "Size of individual file must not exceed the directory size limit.")
      XCTAssertLessThan(preset.maxFileAgeForWrite,
                        preset.minFileAgeForRead,
                        "File should not be considered for export (read) while it is eligible for writes.")
      XCTAssertGreaterThan(preset.maxFileAgeForRead,
                           preset.minFileAgeForRead,
                           "File read boundaries must be consistent.")
      XCTAssertGreaterThan(preset.maxExportDelay,
                           preset.minExportDelay,
                           "Export delay boundaries must be consistent.")
      XCTAssertGreaterThan(preset.maxExportDelay,
                           preset.minExportDelay,
                           "Export delay boundaries must be consistent.")
      XCTAssertLessThanOrEqual(preset.exportDelayChangeRate,
                               1,
                               "Export delay should not change by more than %100 at once.")
      XCTAssertGreaterThan(preset.exportDelayChangeRate,
                           0,
                           "Export delay must change at non-zero rate.")
    }
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import DatadogExporter
import XCTest

class PerformancePresetTests: XCTestCase {
    func testDefaultPreset() {
        XCTAssertEqual(PerformancePreset.default, .lowRuntimeImpact)
    }

    func testPresetsConsistency() {
        let presets: [PerformancePreset] = [.lowRuntimeImpact, .instantDataDelivery]

        presets.forEach { preset in
            XCTAssertLessThan(
                preset.maxFileSize,
                preset.maxDirectorySize,
                "Size of individual file must not exceed the directory size limit."
            )
            XCTAssertLessThan(
                preset.maxFileAgeForWrite,
                preset.minFileAgeForRead,
                "File should not be considered for upload (read) while it is eligible for writes."
            )
            XCTAssertGreaterThan(
                preset.maxFileAgeForRead,
                preset.minFileAgeForRead,
                "File read boundaries must be consistent."
            )
            XCTAssertGreaterThan(
                preset.maxUploadDelay,
                preset.minUploadDelay,
                "Upload delay boundaries must be consistent."
            )
            XCTAssertGreaterThan(
                preset.maxUploadDelay,
                preset.minUploadDelay,
                "Upload delay boundaries must be consistent."
            )
            XCTAssertLessThanOrEqual(
                preset.uploadDelayChangeRate,
                1,
                "Upload delay should not change by more than %100 at once."
            )
            XCTAssertGreaterThan(
                preset.uploadDelayChangeRate,
                0,
                "Upload delay must change at non-zero rate."
            )
        }
    }
}

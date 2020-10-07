// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

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

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
@testable import FaroExporter

final class FaroSdkFactoryTests: XCTestCase {
    func testGetInstance_ReturnsSameInstance() throws {
        // Given
        let options = FaroExporterOptions(
            collectorUrl: "https://example.com/collect/test-api-key",
            appName: "TestApp",
            appVersion: "1.0.0",
            appEnvironment: "test"
        )
        
        // When
        let firstInstance = try FaroSdkFactory.getInstance(options: options)
        let secondInstance = try FaroSdkFactory.getInstance(options: options)
        
        // Then
        XCTAssertTrue(firstInstance === secondInstance, "Factory should return the same instance")
    }
} 
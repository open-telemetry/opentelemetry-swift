/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
@testable import FaroExporter

final class FaroAppInfoExtensionTests: XCTestCase {
    func testCreateFromOptionsCreatesCorrectAppInfo() {
        // Given
        let options = FaroExporterOptions(
            collectorUrl: "https://example.com",
            appName: "TestApp",
            appVersion: "1.0.0",
            appEnvironment: "test"
        )
        
        // When
        let appInfo = FaroAppInfo.create(from: options)
        
        // Then
        XCTAssertEqual(appInfo.name, "TestApp")
        XCTAssertEqual(appInfo.version, "1.0.0")
        XCTAssertEqual(appInfo.environment, "test")
        XCTAssertNil(appInfo.namespace)
        XCTAssertNil(appInfo.bundleId)
        XCTAssertNil(appInfo.release)
    }
    
    func testCreateFromOptionsWithNilValuesCreatesAppInfoWithNilValues() {
        // Given
        let options = FaroExporterOptions(
            collectorUrl: "https://example.com"
        )
        
        // When
        let appInfo = FaroAppInfo.create(from: options)
        
        // Then
        XCTAssertNil(appInfo.name)
        XCTAssertNil(appInfo.version)
        XCTAssertNil(appInfo.environment)
        XCTAssertNil(appInfo.namespace)
        XCTAssertNil(appInfo.bundleId)
        XCTAssertNil(appInfo.release)
    }
} 
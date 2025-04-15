/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
@testable import FaroExporter

final class FaroEndpointConfigurationExtensionTests: XCTestCase {
    
    func testCreateWithValidUrl() throws {
        // Given
        let options = FaroExporterOptions(
            collectorUrl: "https://example.com/api/v1/12345abcdef"
        )
        
        // When
        let config = try FaroEndpointConfiguration.create(from: options)
        
        // Then
        XCTAssertEqual(config.collectorUrl, URL(string: "https://example.com/api/v1/12345abcdef")!)
        XCTAssertEqual(config.apiKey, "12345abcdef")
    }
    
    func testCreateWithInvalidUrl() {
        // Given
        let options = FaroExporterOptions(
            collectorUrl: ""
        )
        
        // When/Then
        XCTAssertThrowsError(try FaroEndpointConfiguration.create(from: options)) { error in
            XCTAssertEqual(error as? FaroExporterError, .invalidCollectorUrl)
        }
    }
    
    func testCreateWithEmptyUrl() {
        // Given
        let options = FaroExporterOptions(
            collectorUrl: ""
        )
        
        // When/Then
        XCTAssertThrowsError(try FaroEndpointConfiguration.create(from: options)) { error in
            XCTAssertEqual(error as? FaroExporterError, .invalidCollectorUrl)
        }
    }
    
    func testCreateWithMissingApiKey() {
        // Given
        let options = FaroExporterOptions(
            collectorUrl: "https://example.com/"
        )
        
        // When/Then
        XCTAssertThrowsError(try FaroEndpointConfiguration.create(from: options)) { error in
            XCTAssertEqual(error as? FaroExporterError, .missingApiKey)
        }
    }
    
    func testCreateWithCollectAsLastPathComponent() {
        // Given
        let options = FaroExporterOptions(
            collectorUrl: "https://example.com/api/collect"
        )
        
        // When/Then
        XCTAssertThrowsError(try FaroEndpointConfiguration.create(from: options)) { error in
            XCTAssertEqual(error as? FaroExporterError, .missingApiKey)
        }
    }
    
    func testCreateWithMultiplePathComponents() throws {
        // Given
        let options = FaroExporterOptions(
            collectorUrl: "https://example.com/api/v1/path/subpath/apikey123"
        )
        
        // When
        let config = try FaroEndpointConfiguration.create(from: options)
        
        // Then
        XCTAssertEqual(config.collectorUrl, URL(string: "https://example.com/api/v1/path/subpath/apikey123")!)
        XCTAssertEqual(config.apiKey, "apikey123")
    }
    
    func testCreateWithNonHttpsUrl() {
        // Given - not explicitly testing HTTPS, as that requirement is in FaroExporter's validateOptions
        // This test shows that the endpoint configuration extractor itself doesn't validate the scheme
        let options = FaroExporterOptions(
            collectorUrl: "http://example.com/api/key123"
        )
        
        // When/Then - should not throw as we're not validating the scheme here
        XCTAssertNoThrow(try FaroEndpointConfiguration.create(from: options))
    }
} 
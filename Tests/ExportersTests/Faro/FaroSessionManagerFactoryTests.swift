/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
 
import XCTest
@testable import FaroExporter

final class FaroSessionManagerFactoryTests: XCTestCase {
    private var dateProvider: MockDateProvider!
    
    override func setUp() {
        super.setUp()
        dateProvider = MockDateProvider(initialDate: Date())
    }
    
    override func tearDown() {
        dateProvider = nil
        super.tearDown()
    }
    
    func test_shared_returnsSameInstance() {
        // Given
        let firstManager = FaroSessionManagerFactory.shared(dateProvider: dateProvider)
        let secondManager = FaroSessionManagerFactory.shared(dateProvider: dateProvider)
        
        // Then
        XCTAssertNotNil(firstManager)
        XCTAssertNotNil(secondManager)
        XCTAssertTrue(firstManager === secondManager, "Factory should return the same instance")
    }
    
    func test_shared_withDifferentDateProvider_returnsSameInstance() {
        // Given
        let firstManager = FaroSessionManagerFactory.shared(dateProvider: dateProvider)
        let newDateProvider = MockDateProvider(initialDate: Date())
        
        // When
        let secondManager = FaroSessionManagerFactory.shared(dateProvider: newDateProvider)
        
        // Then
        XCTAssertTrue(firstManager === secondManager, "Factory should return same instance even with different date provider")
    }
} 
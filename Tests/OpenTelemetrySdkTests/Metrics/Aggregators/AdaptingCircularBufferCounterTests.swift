/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetrySdk
import XCTest

final class AdaptingCircularBufferCounterTests: XCTestCase {
    
    public func testReturnsZeroOutsidePopulatedRange() {
        let counter = AdaptingCircularBufferCounter(maxSize: 10)
        XCTAssertEqual(counter.get(index: 0), 0)
        XCTAssertEqual(counter.get(index: 100), 0)
        XCTAssertTrue(counter.increment(index: 2, delta: 1))
        XCTAssertFalse(counter.increment(index: 99, delta: 1))
        XCTAssertEqual(counter.get(index: 0), 0)
        XCTAssertEqual(counter.get(index: 2), 1)
        XCTAssertEqual(counter.get(index: 99), 0)
        XCTAssertEqual(counter.get(index: 100), 0)
    }
    
    public func testExpandLower() {
        let counter = AdaptingCircularBufferCounter(maxSize: 160)
        
        XCTAssertTrue(counter.increment(index: 10, delta: 10))
        XCTAssertTrue(counter.increment(index: 0, delta: 1))
        XCTAssertEqual(counter.get(index: 10), 10)
        XCTAssertEqual(counter.get(index: 0), 1)
        XCTAssertEqual(counter.startIndex, 0)
        XCTAssertEqual(counter.endIndex, 10)
        
        XCTAssertTrue(counter.increment(index: 20, delta: 20))
        XCTAssertEqual(counter.get(index: 20), 20)
        XCTAssertEqual(counter.get(index: 10), 10)
        XCTAssertEqual(counter.get(index: 0), 1)
        XCTAssertEqual(counter.startIndex, 0)
        XCTAssertEqual(counter.endIndex, 20)
    }
    
    public func testShouldFailAtLimit() {
        let counter = AdaptingCircularBufferCounter(maxSize: 160)
        XCTAssertTrue(counter.increment(index: 0, delta: 1))
        XCTAssertTrue(counter.increment(index: 120, delta: 12))
        
        XCTAssertEqual(counter.startIndex, 0)
        XCTAssertEqual(counter.endIndex, 120)
        XCTAssertEqual(counter.get(index: 0), 1)
        XCTAssertEqual(counter.get(index: 120), 12)
        
        XCTAssertFalse(counter.increment(index: 161, delta: 1))
    }
    
    public func testShouldCopyCounter() {
        let counter = AdaptingCircularBufferCounter(maxSize: 2)
        XCTAssertTrue(counter.increment(index: 2, delta: 2))
        XCTAssertTrue(counter.increment(index: 1, delta: 1))
        XCTAssertFalse(counter.increment(index: 3, delta: 1))
        
        let copy = counter.copy() as! AdaptingCircularBufferCounter
        XCTAssertEqual(counter.get(index: 2), 2)
        XCTAssertEqual(copy.get(index: 2), 2)
        XCTAssertEqual(counter.getMaxSize(), copy.getMaxSize())
        XCTAssertEqual(counter.startIndex, copy.startIndex)
        XCTAssertEqual(counter.endIndex, copy.endIndex)
        
        XCTAssertTrue(copy.increment(index: 2, delta: 2))
        XCTAssertEqual(copy.get(index: 2), 4)
        XCTAssertEqual(counter.get(index: 2), 2)
    }
}


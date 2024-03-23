/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetrySdk
import XCTest

final class AdaptingIntegerArrayTests: XCTestCase {
    
    let intValues: [Int64] = [Int64(1), Int64(127 + 1), Int64(32767 + 1), Int64(2147483647 + 1)]
    
    public func testSize() {
        for intValue in intValues {
            let arr = AdaptingIntegerArray(size: 10)
            XCTAssertEqual(arr.length(), 10)
            arr.increment(index: 0, count: intValue)
            XCTAssertEqual(arr.length(), 10)
        }
    }
    
    public func testIncrementAndGet() {
        for intValue in intValues {
            let arr = AdaptingIntegerArray(size: 10)
            
            for i in 0..<10 {
                XCTAssertEqual(arr.get(index: i), 0)
                arr.increment(index: i, count: Int64(1))
                XCTAssertEqual(arr.get(index: i), 1)
                arr.increment(index: i, count: intValue)
                arr.increment(index: i, count: Int64(intValue + 1))
            }
        }
    }
    
    public func testCopy() {
        for intValue in intValues {
            let arr = AdaptingIntegerArray(size: 1)
            arr.increment(index: 0, count: intValue)
            
            let copy = arr.copy() as! AdaptingIntegerArray
            XCTAssertEqual(arr.get(index: 0), intValue)
            
            arr.increment(index: 0, count: 1)
            XCTAssertEqual(arr.get(index: 0), intValue + 1)
            XCTAssertEqual(copy.get(index: 0), intValue)
        }
    }
    
    public func testClear() {
        for intValue in intValues {
            let arr = AdaptingIntegerArray(size: 1)
            arr.increment(index: 0, count: intValue)
            XCTAssertEqual(arr.get(index: 0), intValue)
            
            arr.clear()
            arr.increment(index: 0, count: 1)
            XCTAssertEqual(arr.get(index: 0), 1)
        }
    }
    
    public func testHandleResize() {
        let arr = AdaptingIntegerArray(size: 4)
        let byteValue = Int64(1)
        arr.increment(index: 0, count: byteValue)
        XCTAssertEqual(arr.get(index: 0), byteValue)
        XCTAssertEqual(arr.cellSize, .byte)
        XCTAssertNotNil(arr.byteBacking)
        XCTAssertEqual(arr.shortBacking, nil)
        XCTAssertEqual(arr.intBacking, nil)
        XCTAssertEqual(arr.longBacking, nil)
        XCTAssertEqual(arr.length(), 4)
        
        let shortValue = Int64(127 + 1)
        arr.increment(index: 1, count: shortValue)
        XCTAssertEqual(arr.get(index: 0), byteValue)
        XCTAssertEqual(arr.get(index: 1), shortValue)
        XCTAssertEqual(arr.cellSize, .short)
        XCTAssertNotNil(arr.shortBacking)
        XCTAssertEqual(arr.byteBacking, nil)
        XCTAssertEqual(arr.intBacking, nil)
        XCTAssertEqual(arr.longBacking, nil)
        XCTAssertEqual(arr.length(), 4)
        
        let intValue = Int64(32767 + 1)
        arr.increment(index: 2, count: intValue)
        XCTAssertEqual(arr.get(index: 0), byteValue)
        XCTAssertEqual(arr.get(index: 1), shortValue)
        XCTAssertEqual(arr.get(index: 2), intValue)
        XCTAssertEqual(arr.cellSize, .int)
        XCTAssertNotNil(arr.intBacking)
        XCTAssertEqual(arr.byteBacking, nil)
        XCTAssertEqual(arr.shortBacking, nil)
        XCTAssertEqual(arr.longBacking, nil)
        XCTAssertEqual(arr.length(), 4)
        
        let longValue = Int64(2147483647 + 1)
        arr.increment(index: 3, count: longValue)
        XCTAssertEqual(arr.get(index: 0), byteValue)
        XCTAssertEqual(arr.get(index: 1), shortValue)
        XCTAssertEqual(arr.get(index: 2), intValue)
        XCTAssertEqual(arr.get(index: 3), longValue)
        XCTAssertEqual(arr.cellSize, .long)
        XCTAssertNotNil(arr.longBacking)
        XCTAssertEqual(arr.byteBacking, nil)
        XCTAssertEqual(arr.shortBacking, nil)
        XCTAssertEqual(arr.intBacking, nil)
        XCTAssertEqual(arr.length(), 4)
    }
}


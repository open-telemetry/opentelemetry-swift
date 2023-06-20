//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
@testable import OpenTelemetrySdk
import XCTest

class ComponentRegistryTests : XCTestCase {
    
    
    func testComponentRegistry() {
        let registry = ComponentRegistry<String> { instrumentationScope in
            return instrumentationScope.name + (instrumentationScope.version ?? "") + (instrumentationScope.schemaUrl ?? "")
        }
        
        let item1 = registry.get(name: "one")
        let item2 = registry.get(name: "one", version: "1")
        let item3 = registry.get(name:"one",version: "1", schemaUrl: "https://opentelemetry.io/schemas/1.15.0")
        let item4 = registry.get(name: "one", schemaUrl: "https://opentelemetry.io/schemas/1.15.0")
        
        XCTAssertNotIdentical(item2 as AnyObject, item1 as AnyObject)
        XCTAssertNotIdentical(item1 as AnyObject, item3 as AnyObject)
        XCTAssertNotIdentical(item2 as AnyObject, item3 as AnyObject)
        XCTAssertNotIdentical(item4 as AnyObject, item1 as AnyObject)
        XCTAssertNotIdentical(item4 as AnyObject, item2 as AnyObject)
        XCTAssertNotIdentical(item4 as AnyObject, item3 as AnyObject)
        
        XCTAssertIdentical(registry.get(name: "one") as AnyObject, item1 as AnyObject)
        XCTAssertIdentical(registry.get(name: "one", version: "1") as AnyObject, item2 as AnyObject)
        XCTAssertIdentical(registry.get(name:"one",version: "1", schemaUrl: "https://opentelemetry.io/schemas/1.15.0") as AnyObject, item3 as AnyObject)
        XCTAssertIdentical(registry.get(name: "one", schemaUrl: "https://opentelemetry.io/schemas/1.15.0") as AnyObject, item4 as AnyObject)
        
        
        
        
    }
}

#if swift(<5.4)
// Available from Xcode 12.5+ (Swift 5.4)
// https://xcodereleases.com
private extension XCTestCase {
    // https://developer.apple.com/documentation/xctest/3727243-xctassertidentical
    func XCTAssertIdentical(
        _ expression1: @autoclosure () throws -> AnyObject?,
        _ expression2: @autoclosure () throws -> AnyObject?,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(try expression1() === expression2(), message(), file: file, line: line)
    }

    // https://developer.apple.com/documentation/xctest/3727244-xctassertnotidentical
    func XCTAssertNotIdentical(
        _ expression1: @autoclosure () throws -> AnyObject?,
        _ expression2: @autoclosure () throws -> AnyObject?,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertFalse(try expression1() === expression2(), message(), file: file, line: line)
    }
}
#endif

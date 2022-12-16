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

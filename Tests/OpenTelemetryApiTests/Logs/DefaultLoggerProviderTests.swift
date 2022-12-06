//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
@testable import OpenTelemetryApi
import XCTest


class DefaultLoggerProviderTests : XCTestCase {
     
    func testDefaultLoggerProvider() {
       let logger = DefaultLoggerProvider().get(instrumentationScopeName: "test")
        XCTAssertIdentical(logger as AnyObject, DefaultLoggerProvider().get(instrumentationScopeName: "other") as AnyObject)
        
        let loggerWithDomain = DefaultLoggerProvider()
            .loggerBuilder(instrumentationScopeName: "Scope")
            .setEventDomain("Domain")
            .setIncludeTraceContext(true)
            .setSchemaUrl("https://opentelemetry.io/schemas/1.15.0")
            .setAttributes([:])
            .setInstrumentationVersion("1.0.0")
            .build()
        
        let loggerWithoutDomain = DefaultLoggerProvider()
            .loggerBuilder(instrumentationScopeName: "Scope")
            .setEventDomain("")
            .setIncludeTraceContext(true)
            .setSchemaUrl("https://opentelemetry.io/schemas/1.15.0")
            .setAttributes([:])
            .setInstrumentationVersion("1.0.0")
            .build()
        XCTAssertNotIdentical(loggerWithDomain as AnyObject, loggerWithoutDomain as AnyObject)
        
    }
    
}

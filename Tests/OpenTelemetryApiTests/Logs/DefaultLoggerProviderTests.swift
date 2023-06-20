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

import XCTest
import Logging
import OpenTelemetryApi
import OpenTelemetrySdk

@testable import OTelSwiftLog 

final class OTelLogHandlerTests: XCTestCase {

    // TODO: Check for all fields on scope
    func testLogHandlerInitialization() {
        let scope = InstrumentationScope(name: "TestScope")
        let logHandler = OTelLogHandler(scope: scope)
        
        XCTAssertEqual(logHandler.scope.name, "TestScope")
        XCTAssertEqual(logHandler.logLevel, .info)
    }

    // TODO: Test log level for permissive and restrictive case

    func testLogHandlerMetadata() {
        // TODO: Test different combination
        var logHandler = OTelLogHandler()
        logHandler.metadata = ["key": "value"]
        XCTAssertEqual(logHandler.metadata["key"], "value")
        logHandler["anotherKey"] = "anotherValue"
        XCTAssertEqual(logHandler.metadata["anotherKey"], "anotherValue")
    }

    
    func testConvertSeverity() {
        XCTAssertEqual(convertSeverity(level: .trace), OpenTelemetryApi.Severity.trace)
        XCTAssertEqual(convertSeverity(level: .debug), OpenTelemetryApi.Severity.debug)
        XCTAssertEqual(convertSeverity(level: .info), OpenTelemetryApi.Severity.info)
        XCTAssertEqual(convertSeverity(level: .notice), OpenTelemetryApi.Severity.info2)
        XCTAssertEqual(convertSeverity(level: .warning), OpenTelemetryApi.Severity.warn)
        XCTAssertEqual(convertSeverity(level: .error), OpenTelemetryApi.Severity.error)
        XCTAssertEqual(convertSeverity(level: .critical), OpenTelemetryApi.Severity.error2)
    }
}

// Run the tests
OTelLogHandlerTests.defaultTestSuite.run()
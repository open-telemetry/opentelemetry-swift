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
        logHandler[metadataKey:"anotherKey"] = "anotherValue"
        XCTAssertEqual(logHandler.metadata["anotherKey"], "anotherValue")
    }

     func testConvertToAttributeValue() {
        //string test
        let attributeValueString = convertToAttributeValue(Logging.Logger.Metadata.Value(stringLiteral: "HelloWorld"))
        XCTAssertEqual(attributeValueString, AttributeValue.string("HelloWorld"))
      
      
      let attributeValueInt = convertToAttributeValue(Logging.Logger.Metadata.Value.stringConvertible(100))
        XCTAssertEqual(attributeValueInt, AttributeValue.string("100"))

      let attributeValueDictionary = convertToAttributeValue(Logger.Metadata.Value.dictionary(["myAttributes":Logger.Metadata.Value.dictionary([:])]))
      XCTAssertEqual(attributeValueDictionary, AttributeValue.set(AttributeSet(labels: ["myAttributes": AttributeValue.set(AttributeSet(labels: [:]))])))
      
      let attributeValueEmptyArray =
      convertToAttributeValue(Logger.Metadata.Value.array([]))
      XCTAssertEqual(attributeValueEmptyArray, AttributeValue.stringArray([]))
      
      let attributeValueArray =
      convertToAttributeValue(Logger.Metadata.Value.array([Logger.Metadata.Value.stringConvertible(100),
                                                           Logger.Metadata.Value.string("string"),
                                                           Logger.Metadata.Value.array([]),
                                                           Logger.Metadata.Value.dictionary([:])]))

      // is this the expected behavior?
      XCTAssertEqual(attributeValueArray, nil)
      
      let attributeValueStringArray = convertToAttributeValue(Logger.Metadata.Value.array(
        [Logger.Metadata.Value.stringConvertible(100),
         Logger.Metadata.Value.string("string"),
         Logger.Metadata.Value.stringConvertible(true)
      ]))
      
      XCTAssertEqual(attributeValueStringArray, AttributeValue.stringArray(["100", "string", "true"]))
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

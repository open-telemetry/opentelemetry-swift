import XCTest
import Logging
import OpenTelemetryApi

@testable import OTelSwiftLog

final class OTelLogHandlerTests: XCTestCase {
  // TODO: Test log level for permissive and restrictive case

  func testLogHandlerMetadata() {
    // TODO: Test different combination
    var logHandler = OTelLogHandler()
    logHandler.metadata = ["key": "value"]
    XCTAssertEqual(logHandler.metadata["key"], "value")
    logHandler[metadataKey: "anotherKey"] = "anotherValue"
    XCTAssertEqual(logHandler.metadata["anotherKey"], "anotherValue")
  }

  func testConvertToAttributeValue() {
    // string test
    let attributeValueString = convertToAttributeValue(Logging.Logger.Metadata.Value(stringLiteral: "HelloWorld"))
    XCTAssertEqual(attributeValueString, AttributeValue.string("HelloWorld"))

    let attributeValueInt = convertToAttributeValue(Logging.Logger.Metadata.Value.stringConvertible(100))
    XCTAssertEqual(attributeValueInt, AttributeValue.string("100"))

    let attributeValueDictionary = convertToAttributeValue(Logger.Metadata.Value.dictionary(["myAttributes": Logger.Metadata.Value.dictionary([:])]))
    XCTAssertEqual(attributeValueDictionary, AttributeValue.set(AttributeSet(labels: ["myAttributes": AttributeValue.set(AttributeSet(labels: [:]))])))

    let attributeValueEmptyArray =
      convertToAttributeValue(Logger.Metadata.Value.array([]))
    XCTAssertEqual(attributeValueEmptyArray, AttributeValue.array(AttributeArray.empty))

    let attributeValueArray =
      convertToAttributeValue(Logger.Metadata.Value.array([Logger.Metadata.Value.stringConvertible(100),
                                                           Logger.Metadata.Value.string("string"),
                                                           Logger.Metadata.Value.array(["index0"]),
                                                           Logger.Metadata.Value.dictionary(["key": "value"])]))

    // is this the expected behavior?
    XCTAssertEqual(attributeValueArray,
                   AttributeValue.array(AttributeArray(values: [.string("100"),
                                                                .string("string"),
                                                                .array(AttributeArray(values: [.string("index0")])),
                                                                .set(AttributeSet(labels: ["key": .string("value")]))])))

    let attributeValueStringArray = convertToAttributeValue(Logger.Metadata.Value.array(
      [Logger.Metadata.Value.stringConvertible(100),
       Logger.Metadata.Value.string("string"),
       Logger.Metadata.Value.stringConvertible(true)]))

    XCTAssertEqual(attributeValueStringArray, AttributeValue.array(AttributeArray(values: [AttributeValue.string("100"), AttributeValue.string("string"), AttributeValue.string("true")])))
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

  func testLogHandlerNSError() {
    let recordBuilder = TestLogRecordBuilder()
    let logHandler = OTelLogHandler(loggerProvider: TestLoggerProvider(recordBuilder))
    let logger = Logger(label: "Test", factory: { _ in logHandler })
    logger.info("Test", error: NSError(domain: "Test error domain", code: 42))

    XCTAssertEqual(recordBuilder.attributes["exception.message"], .string("The operation couldn’t be completed. (Test error domain error 42.)"))
    XCTAssertEqual(recordBuilder.attributes["exception.type"], .string("42"))
  }

  func testLogHandlerCustomError() {
    let recordBuilder = TestLogRecordBuilder()
    let logHandler = OTelLogHandler(loggerProvider: TestLoggerProvider(recordBuilder))
    let logger = Logger(label: "Test", factory: { _ in logHandler })
    logger.info("Test", error: TestError(message: "Something went wrong"))

    XCTAssertEqual(recordBuilder.attributes["exception.message"], .string("The operation couldn’t be completed. (OTelSwiftLogTests.TestError error 1.)"))
    XCTAssertEqual(recordBuilder.attributes["exception.type"], .string("1"))

    XCTExpectFailure("Below would be more reasonable values")
    XCTAssertEqual(recordBuilder.attributes["exception.message"], .string("Something went wrong"))
    XCTAssertEqual(recordBuilder.attributes["exception.type"], .string("OTelSwiftLogTests.TestError"))
  }
}

struct TestError: CustomStringConvertible, LocalizedError {
  let message: String

  var description: String { message }
  var localizedDescription: String { message }
}

private class TestLoggerProvider: LoggerProvider {
  let recordBuilder: TestLogRecordBuilder

  init(_ recordBuilder: TestLogRecordBuilder) {
    self.recordBuilder = recordBuilder
  }

  func get(instrumentationScopeName: String) -> any OpenTelemetryApi.Logger {
    return loggerBuilder(instrumentationScopeName: instrumentationScopeName).build()
  }

  func loggerBuilder(instrumentationScopeName: String) -> any LoggerBuilder {
    TestLoggerBuilder(recordBuilder: recordBuilder)
  }
}

private struct TestLoggerBuilder: LoggerBuilder {
  let recordBuilder: TestLogRecordBuilder

  func setEventDomain(_ eventDomain: String) -> TestLoggerBuilder {
    self
  }

  func setSchemaUrl(_ schemaUrl: String) -> TestLoggerBuilder {
    self
  }

  func setInstrumentationVersion(_ instrumentationVersion: String) -> TestLoggerBuilder {
    self
  }

  func setIncludeTraceContext(_ includeTraceContext: Bool) -> TestLoggerBuilder {
    self
  }

  func setAttributes(_ attributes: [String : OpenTelemetryApi.AttributeValue]) -> TestLoggerBuilder {
    self
  }

  func build() -> any OpenTelemetryApi.Logger {
    TestLogger(recordBuilder: recordBuilder)
  }
}

private struct TestLogger: OpenTelemetryApi.Logger {
  let recordBuilder: TestLogRecordBuilder

  func eventBuilder(name: String) -> any OpenTelemetryApi.EventBuilder {
    return recordBuilder
  }

  func logRecordBuilder() -> any OpenTelemetryApi.LogRecordBuilder {
    return recordBuilder
  }
}

private class TestLogRecordBuilder: EventBuilder {
  var attributes: [String : AttributeValue] = [:]

  func setAttributes(_ attributes: [String : AttributeValue]) -> Self {
    self.attributes = attributes
    return self
  }
}
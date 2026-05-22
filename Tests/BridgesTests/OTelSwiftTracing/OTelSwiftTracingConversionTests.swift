import XCTest
import OpenTelemetryApi
import Tracing

@testable import OTelSwiftTracing

final class OTelSwiftTracingConversionTests: XCTestCase {
  func testMapSpanKind() {
    XCTAssertEqual(OTelTracer.mapSpanKind(.server), .server)
    XCTAssertEqual(OTelTracer.mapSpanKind(.client), .client)
    XCTAssertEqual(OTelTracer.mapSpanKind(.producer), .producer)
    XCTAssertEqual(OTelTracer.mapSpanKind(.consumer), .consumer)
    XCTAssertEqual(OTelTracer.mapSpanKind(.internal), .internal)
  }

  func testConvertAttributeValue() {
    XCTAssertEqual(OTelSpan.convertAttributeValue(.int32(1)), .int(1))
    XCTAssertEqual(OTelSpan.convertAttributeValue(.int64(2)), .int(2))
    XCTAssertEqual(OTelSpan.convertAttributeValue(.double(3.5)), .double(3.5))
    XCTAssertEqual(OTelSpan.convertAttributeValue(.bool(true)), .bool(true))
    XCTAssertEqual(OTelSpan.convertAttributeValue(.string("value")), .string("value"))
    XCTAssertEqual(OTelSpan.convertAttributeValue(.stringConvertible(TestDescription("described"))), .string("described"))
  }

  func testConvertAttributeArrayValues() {
    XCTAssertEqual(
      OTelSpan.convertAttributeValue(.int32Array([1, 2])),
      .array(AttributeArray(values: [.int(1), .int(2)]))
    )
    XCTAssertEqual(
      OTelSpan.convertAttributeValue(.int64Array([3, 4])),
      .array(AttributeArray(values: [.int(3), .int(4)]))
    )
    XCTAssertEqual(
      OTelSpan.convertAttributeValue(.doubleArray([1.5, 2.5])),
      .array(AttributeArray(values: [.double(1.5), .double(2.5)]))
    )
    XCTAssertEqual(
      OTelSpan.convertAttributeValue(.boolArray([true, false])),
      .array(AttributeArray(values: [.bool(true), .bool(false)]))
    )
    XCTAssertEqual(
      OTelSpan.convertAttributeValue(.stringArray(["a", "b"])),
      .array(AttributeArray(values: [.string("a"), .string("b")]))
    )
    XCTAssertEqual(
      OTelSpan.convertAttributeValue(.stringConvertibleArray([TestDescription("a"), TestDescription("b")])),
      .array(AttributeArray(values: [.string("a"), .string("b")]))
    )
  }

  func testConvertAttributes() {
    let converted = OTelSpan.convertAttributes([
      "string": .string("value"),
      "int": .int(1),
      "bool": .bool(true)
    ])

    XCTAssertEqual(converted.count, 3)
    XCTAssertEqual(converted["string"], .string("value"))
    XCTAssertEqual(converted["int"], .int(1))
    XCTAssertEqual(converted["bool"], .bool(true))
  }

  func testDateConversionFromTracerInstant() {
    let instant = TestInstant(nanosecondsSinceEpoch: 1_500_000_000)

    XCTAssertEqual(OTelTracer.date(from: instant), Date(timeIntervalSince1970: 1.5))
    XCTAssertEqual(OTelSpan.date(from: instant), Date(timeIntervalSince1970: 1.5))
  }

  func testDateConversionFromNanosecondsSinceEpoch() {
    XCTAssertEqual(
      OTelSpan.date(fromNanosecondsSinceEpoch: 2_250_000_000),
      Date(timeIntervalSince1970: 2.25)
    )
  }
}

private struct TestDescription: CustomStringConvertible, Sendable {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}

private struct TestInstant: TracerInstant {
  let nanosecondsSinceEpoch: UInt64

  static func < (lhs: TestInstant, rhs: TestInstant) -> Bool {
    lhs.nanosecondsSinceEpoch < rhs.nanosecondsSinceEpoch
  }
}

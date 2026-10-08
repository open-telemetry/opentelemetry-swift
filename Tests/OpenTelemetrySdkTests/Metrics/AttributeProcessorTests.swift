//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class AttributeProcessorTests: XCTestCase {
  func testStaticNoop() {
    XCTAssertNotNil(NoopAttributeProcessor.noop)
    XCTAssertEqual(NoopAttributeProcessor.noop.process(incoming: ["hello": AttributeValue.string("world")]), ["hello": AttributeValue.string("world")])
  }

  func testSimpleProcessor() {
    let incoming = ["hello": AttributeValue("world")]

    var processor: AttributeProcessor = SimpleAttributeProcessor.append(attributes: ["foo": .string("bar")])
    XCTAssertEqual(processor.process(incoming: incoming), ["hello": .string("world"), "foo": .string("bar")])

    processor = processor.then(other: SimpleAttributeProcessor.filterByKeyName(nameFilter: { $0 == "foo" }))
    XCTAssertEqual(processor.process(incoming: incoming), ["foo": .string("bar")])
  }

  func testJoinedProcessor() {
    let incoming = ["hello": AttributeValue("world")]

    let processor0 = SimpleAttributeProcessor.append(attributes: ["foo": .string("bar0")])
    let processor1 = SimpleAttributeProcessor.append(attributes: ["foo": .string("bar1")])
    let processor2 = SimpleAttributeProcessor.append(attributes: ["foo": .string("bar2")])

    var processor = JoinedAttributeProcessor([processor0])
    XCTAssertEqual(processor.process(incoming: incoming), ["hello": .string("world"), "foo": .string("bar0")])

    processor = processor.prepend(processor: processor1)
    XCTAssertEqual(processor.process(incoming: incoming), ["hello": .string("world"), "foo": .string("bar0")])

    processor = processor.append(processor: processor2)
    XCTAssertEqual(processor.process(incoming: incoming), ["hello": .string("world"), "foo": .string("bar2")])
  }
}

//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class NoopAttributesProcessorTests : XCTestCase {
  func testStaticNoop() {
    XCTAssertNotNil(NoopAttributeProcessor.noop)
    XCTAssertEqual(NoopAttributeProcessor.noop.process(incoming: ["hello": AttributeValue.string("world")]), ["hello" : AttributeValue.string("world")])
  }
}

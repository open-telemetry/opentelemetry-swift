/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

class SpanLimitTests: XCTestCase {
  func testDefaultSpanLimits() {
    XCTAssertEqual(SpanLimits().attributeCountLimit, 128)
    XCTAssertEqual(SpanLimits().eventCountLimit, 128)
    XCTAssertEqual(SpanLimits().linkCountLimit, 128)
    XCTAssertEqual(SpanLimits().attributePerEventCountLimit, 128)
    XCTAssertEqual(SpanLimits().attributePerLinkCountLimit, 128)
  }

  func testUpdateSpanLimit_All() {
    let spanLimits = SpanLimits().settingAttributeCountLimit(8)
      .settingEventCountLimit(10)
      .settingLinkCountLimit(11)
      .settingAttributePerEventCountLimit(1)
      .settingAttributePerLinkCountLimit(2)
    XCTAssertEqual(spanLimits.attributeCountLimit, 8)
    XCTAssertEqual(spanLimits.eventCountLimit, 10)
    XCTAssertEqual(spanLimits.linkCountLimit, 11)
    XCTAssertEqual(spanLimits.attributePerEventCountLimit, 1)
    XCTAssertEqual(spanLimits.attributePerLinkCountLimit, 2)
  }
}

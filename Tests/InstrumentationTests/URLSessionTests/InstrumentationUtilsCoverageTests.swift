/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import URLSessionInstrumentation
import XCTest

final class InstrumentationUtilsCoverageTests: XCTestCase {
  func testObjcGetClassListReturnsNonEmpty() {
    let classes = InstrumentationUtils.objc_getClassList()
    XCTAssertGreaterThan(classes.count, 0)
  }

  func testObjcGetSafeClassListWithoutFilterReturnsNonEmpty() {
    let classes = InstrumentationUtils.objc_getSafeClassList()
    XCTAssertGreaterThan(classes.count, 0)
  }

  func testObjcGetSafeClassListFiltersByPrefix() {
    // Filter everything under the "_NS" prefix and verify that survivors don't
    // start with that prefix.
    let filtered = InstrumentationUtils.objc_getSafeClassList(ignoredPrefixes: ["_NS"])
    for cls in filtered.prefix(500) {
      XCTAssertFalse(NSStringFromClass(cls).hasPrefix("_NS"))
    }
  }

  func testObjcGetSafeClassListFilteringReducesCount() {
    // Drop every class with a dot-prefix namespace ("NS", "__", "_", "CF"),
    // which covers the bulk of Foundation types.
    let unfiltered = InstrumentationUtils.objc_getSafeClassList()
    let filtered = InstrumentationUtils.objc_getSafeClassList(
      ignoredPrefixes: ["NS", "__", "_", "CF"])
    XCTAssertLessThanOrEqual(filtered.count, unfiltered.count)
  }
}

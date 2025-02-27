/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryProtocolExporterCommon
import XCTest

class EnvVarHeadersTests: XCTestCase {
  func test_attributesIsNil_whenAccessedThroughStaticProperty() throws {
    XCTAssertNil(EnvVarHeaders.attributes)
  }

  func test_attributesIsNil_whenNoRawValueProvided() throws {
    XCTAssertNil(EnvVarHeaders.attributes(for: nil))
  }

  func test_attributesContainOneKeyValuePair_whenRawValueProvidedHasOneKeyValuePair() throws {
    let capturedAttributes = EnvVarHeaders.attributes(for: "key1=value1")
    XCTAssertNotNil(capturedAttributes)
    XCTAssertEqual(capturedAttributes![0].0, "key1")
    XCTAssertEqual(capturedAttributes![0].1, "value1")
  }

  func test_attributesIsNil_whenInvalidRawValueProvided() throws {
    XCTAssertNil(EnvVarHeaders.attributes(for: "key1"))
  }

  func test_attributesContainTwoKeyValuePair_whenRawValueProvidedHasTwoKeyValuePair() throws {
    let capturedAttributes = EnvVarHeaders.attributes(for: " key1=value1,  key2 = value2 ")
    XCTAssertNotNil(capturedAttributes)
    XCTAssertEqual(capturedAttributes![0].0, "key1")
    XCTAssertEqual(capturedAttributes![0].1, "value1")
    XCTAssertEqual(capturedAttributes![1].0, "key2")
    XCTAssertEqual(capturedAttributes![1].1, "value2")
  }

  func test_attributesIsNil_whenRawValueContainsWhiteSpace() throws {
    let capturedAttributes = EnvVarHeaders.attributes(for: "key=value with\twhitespace")
    XCTAssertNil(capturedAttributes)
  }

  func test_attributesExcludesInvalidTuples_whenRawValueContainsInvalidCharacters() throws {
    let capturedAttributes = EnvVarHeaders.attributes(for: "key=value with whitespace")
    XCTAssertNil(capturedAttributes)
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetrySdk
import XCTest

final class LabelSetSdkTests: XCTestCase {
    func testRemovesDuplicates() {
        var labels = [String: String]()
        labels.updateValue("value1", forKey: "dim1")
        labels.updateValue("value2", forKey: "dim1")
        labels.updateValue("value3", forKey: "dim3")
        labels.updateValue("value4", forKey: "dim4")

        let labelSet = LabelSetSdk(labels: labels)
        XCTAssertEqual(labelSet.labels.count, 3)
        XCTAssertEqual(labelSet.labels["dim1"], "value2")
        XCTAssertEqual(labelSet.labels["dim3"], "value3")
        XCTAssertEqual(labelSet.labels["dim4"], "value4")
    }

    func testLabelSetEncodingIsSameInDifferentOrder() {
        let labels1 = ["dim1": "value1","dim2":"value2","dim3": "value3" ]
        // Construct labelset some labels.
        let labelSet1 = LabelSetSdk(labels: labels1)

        let labels2 = ["dim3": "value3","dim2":"value2","dim1": "value1" ]
        // Construct another labelset with same labels but in different order.
        let labelSet2 = LabelSetSdk(labels: labels2)

        XCTAssertEqual(labelSet1, labelSet2)
        XCTAssertEqual(labelSet1.labelSetEncoded, labelSet2.labelSetEncoded)
    }
}

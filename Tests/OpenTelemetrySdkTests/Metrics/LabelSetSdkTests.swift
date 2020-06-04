// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

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

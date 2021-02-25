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

import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

class SpanLimitTests: XCTestCase {
    func testDefaultSpanLimits() {
        XCTAssertEqual(SpanLimits().maxNumberOfAttributes, 1000)
        XCTAssertEqual(SpanLimits().maxNumberOfEvents, 1000)
        XCTAssertEqual(SpanLimits().maxNumberOfLinks, 1000)
        XCTAssertEqual(SpanLimits().maxNumberOfAttributesPerEvent, 32)
        XCTAssertEqual(SpanLimits().maxNumberOfAttributesPerLink, 32)
    }

    func testUpdateSpanLimit_All() {
        let spanLimits = SpanLimits().settingMaxNumberOfAttributes(8)
            .settingMaxNumberOfEvents(10)
            .settingMaxNumberOfLinks(11)
            .settingMaxNumberOfAttributesPerEvent(1)
            .settingMaxNumberOfAttributesPerLink(2)
        XCTAssertEqual(spanLimits.maxNumberOfAttributes, 8)
        XCTAssertEqual(spanLimits.maxNumberOfEvents, 10)
        XCTAssertEqual(spanLimits.maxNumberOfLinks, 11)
        XCTAssertEqual(spanLimits.maxNumberOfAttributesPerEvent, 1)
        XCTAssertEqual(spanLimits.maxNumberOfAttributesPerLink, 2)
    }
}

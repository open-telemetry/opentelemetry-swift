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

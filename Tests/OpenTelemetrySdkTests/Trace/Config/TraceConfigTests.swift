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
@testable import OpenTelemetrySdk
import XCTest

class TraceConfigTests: XCTestCase {
    func testDefaultTraceConfig() {
        XCTAssertTrue(TraceConfig().sampler === Samplers.alwaysOn)
        XCTAssertEqual(TraceConfig().maxNumberOfAttributes, 32)
        XCTAssertEqual(TraceConfig().maxNumberOfEvents, 128)
        XCTAssertEqual(TraceConfig().maxNumberOfLinks, 32)
        XCTAssertEqual(TraceConfig().maxNumberOfAttributesPerEvent, 32)
        XCTAssertEqual(TraceConfig().maxNumberOfAttributesPerLink, 32)
    }

    func testUpdateTraceConfig_All() {
        let traceConfig = TraceConfig().settingSampler(Samplers.alwaysOff).settingMaxNumberOfAttributes(8).settingMaxNumberOfEvents(10).settingMaxNumberOfLinks(11).settingMaxNumberOfAttributesPerEvent(1).settingMaxNumberOfAttributesPerLink(2)
        XCTAssertTrue(traceConfig.sampler === Samplers.alwaysOff)
        XCTAssertEqual(traceConfig.maxNumberOfAttributes, 8)
        XCTAssertEqual(traceConfig.maxNumberOfEvents, 10)
        XCTAssertEqual(traceConfig.maxNumberOfLinks, 11)
        XCTAssertEqual(traceConfig.maxNumberOfAttributesPerEvent, 1)
        XCTAssertEqual(traceConfig.maxNumberOfAttributesPerLink, 2)
    }
}

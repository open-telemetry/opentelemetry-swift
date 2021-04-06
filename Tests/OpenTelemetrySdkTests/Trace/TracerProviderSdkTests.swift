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

class TracerProviderSdkTests: XCTestCase {
    var tracerProviderSdk = TracerProviderSdk()

    func testDefaultGet() {
        XCTAssert(tracerProviderSdk.get(instrumentationName: "test") is TracerSdk)
    }

    func testgGtSameInstanceForSameName_WithoutVersion() {
        XCTAssert(tracerProviderSdk.get(instrumentationName: "test") === tracerProviderSdk.get(instrumentationName: "test"))
        XCTAssert(tracerProviderSdk.get(instrumentationName: "test") === tracerProviderSdk.get(instrumentationName: "test", instrumentationVersion: nil))
    }

    func testPropagatesInstrumentationLibraryInfoToTracer() {
        let expected = InstrumentationLibraryInfo(name: "theName", version: "theVersion")
        let tracer = tracerProviderSdk.get(instrumentationName: expected.name, instrumentationVersion: expected.version) as! TracerSdk
        XCTAssertEqual(tracer.instrumentationLibraryInfo, expected)
    }

    func testGetSameInstanceForSameName_WithVersion() {
        XCTAssert(tracerProviderSdk.get(instrumentationName: "test", instrumentationVersion: "version") === tracerProviderSdk.get(instrumentationName: "test", instrumentationVersion: "version"))
    }

    func testGetWithoutName() {
        let tracer = tracerProviderSdk.get(instrumentationName: "") as! TracerSdk
        XCTAssertEqual(tracer.instrumentationLibraryInfo.name, TracerProviderSdk.emptyName)
    }
}

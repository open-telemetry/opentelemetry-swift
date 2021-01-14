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
import Opentracing
@testable import OpenTracingShim
import XCTest

class TraceShimTests: XCTestCase {
    func testCreateTracerShimDefault() {
        let tracerShim = TraceShim.createTracerShim() as! TracerShim
        XCTAssert(OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: "opentracingshim", instrumentationVersion: nil) === tracerShim.tracer)
        XCTAssert(OpenTelemetrySDK.instance.baggageManager === tracerShim.baggageManager)
    }

    func testCreateTracerShim() {
        let sdk = OpenTelemetrySDK.instance.tracerProvider
        let baggageManager = DefaultBaggageManager.instance
        let tracerShim = TraceShim.createTracerShim(tracerProvider: sdk, baggageManager: baggageManager) as! TracerShim

        XCTAssert(sdk.get(instrumentationName: "opentracingshim", instrumentationVersion: nil) === tracerShim.tracer)
        XCTAssert(baggageManager === tracerShim.baggageManager)
    }
}

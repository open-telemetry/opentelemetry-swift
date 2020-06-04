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

final class LastValueAggregatorTests: XCTestCase {
    public func testAggregatesCorrectlyInt() {
        // create an aggregator
        let aggregator = LastValueAggregator<Int>()
        var sum = aggregator.toMetricData() as! SumData<Int>

        // we start with 0.
        XCTAssertEqual(0, sum.sum)

        aggregator.update(value: 10)
        aggregator.update(value: 20)
        aggregator.update(value: 30)
        aggregator.update(value: 40)

        aggregator.checkpoint()
        sum = aggregator.toMetricData() as! SumData<Int>
        XCTAssertEqual(40, sum.sum)
    }
    
    public func testAggregatesCorrectlyDouble() {
        // create an aggregator
        let aggregator = LastValueAggregator<Double>()
        var sum = aggregator.toMetricData() as! SumData<Double>

        // we start with 0.
        XCTAssertEqual(0.0, sum.sum)

        aggregator.update(value: 40.5)
        aggregator.update(value: 30.5)
        aggregator.update(value: 20.5)
        aggregator.update(value: 10.5)

        aggregator.checkpoint()
        sum = aggregator.toMetricData() as! SumData<Double>
        XCTAssertEqual(10.5, sum.sum)
    }
}

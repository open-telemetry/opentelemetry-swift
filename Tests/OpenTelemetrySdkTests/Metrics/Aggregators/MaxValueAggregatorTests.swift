// Copyright 2021, OpenTelemetry Authors
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

final class MaxValueAggregatorTests : XCTestCase {
    public func testAsyncSafety() {
        let agg = MaxValueAggregator<Int>()
        var sum = agg.toMetricData() as! SumData<Int>

        XCTAssertEqual(sum.sum, 0)

        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            for i in 0 ..< 10000 {
                agg.update(value: i)
            }
        }

        agg.update(value: 10001)

        agg.checkpoint()
        sum = agg.toMetricData() as! SumData<Int>

        XCTAssertEqual(sum.sum, 10001)
    }

    public func testMaxAggPeriod() {
        let agg = MaxValueAggregator<Int>()
        var sum = agg.toMetricData() as! SumData<Int>

        XCTAssertEqual(sum.sum, 0)

        agg.update(value: 100)
        agg.checkpoint()

        sum = agg.toMetricData() as! SumData<Int>

        XCTAssertEqual(sum.sum, 100)

        agg.update(value: 88)
        agg.checkpoint()

        sum = agg.toMetricData() as! SumData<Int>

        XCTAssertEqual(sum.sum, 88)

    }
}
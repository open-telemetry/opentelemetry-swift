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

final class MeasureMixMaxSumCountAggregatorTests: XCTestCase {
    public func testAggregatesCorrectlyWhenMultipleThreadsUpdatesInt() {
        // create an aggregator
        let aggregator = MeasureMinMaxSumCountAggregator<Int>()
        var summary = aggregator.toMetricData() as! SummaryData<Int>

        // we start with 0.
        XCTAssertEqual(0, summary.sum)
        XCTAssertEqual(0, summary.count)

        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            for _ in 0 ..< 10000 {
                aggregator.update(value: 10)
                aggregator.update(value: 50)
                aggregator.update(value: 100)
            }
        }

        // check point.
        aggregator.checkpoint()
        summary = aggregator.toMetricData() as! SummaryData<Int>

        // 100000 times (10+50+100) by each thread.
        XCTAssertEqual(16000000, summary.sum)

        // 100000 times 3 by each thread
        XCTAssertEqual(300000, summary.count)

        // Min and Max are 10 and 100
        XCTAssertEqual(10, summary.min)
        XCTAssertEqual(100, summary.max)
    }
    
    public func testAggregatesCorrectlyWhenMultipleThreadsUpdatesDouble() {
           // create an aggregator
           let aggregator = MeasureMinMaxSumCountAggregator<Double>()
           var summary = aggregator.toMetricData() as! SummaryData<Double>

           // we start with 0.0
           XCTAssertEqual(0, summary.sum)
           XCTAssertEqual(0, summary.count)

           DispatchQueue.concurrentPerform(iterations: 10) { _ in
               for _ in 0 ..< 10000 {
                aggregator.update(value: 10.0)
                aggregator.update(value: 50.0)
                aggregator.update(value: 100.0)
               }
           }

           // check point.
           aggregator.checkpoint()
           summary = aggregator.toMetricData() as! SummaryData<Double>

           // 100000 times (10+50+100) by each thread.
        XCTAssertEqual(16000000.0, summary.sum)

           // 100000 times 3 by each thread
        XCTAssertEqual(300000, summary.count)

           // Min and Max are 10 and 100
        XCTAssertEqual(10.0, summary.min)
        XCTAssertEqual(100.0, summary.max)
       }
}

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

@testable import DatadogExporter
import XCTest

class DateFormattingTests: XCTestCase {
    private let date: Date = .mockDecember15th2019At10AMUTC(addingTimeInterval: 0.001)

    func testISO8601DateFormatter() {
        XCTAssertEqual(
            iso8601DateFormatter.string(from: date),
            "2019-12-15T10:00:00.001Z"
        )
    }
}

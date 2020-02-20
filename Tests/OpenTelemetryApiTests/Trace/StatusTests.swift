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

@testable import OpenTelemetryApi
import XCTest

final class StatusTests: XCTestCase {
    func testStatus_Ok() {
        XCTAssertEqual(Status.ok.canonicalCode, Status.CanonicalCode.ok)
        XCTAssertNil(Status.ok.statusDescription)
        XCTAssertTrue(Status.ok.isOk)
    }

    func testCreateStatus_WithDescription() {
        let status = Status.unknown.withDescription(description: "This is an error.")
        XCTAssertEqual(status.canonicalCode, Status.CanonicalCode.unknown)
        XCTAssertEqual(status.statusDescription, "This is an error.")
        XCTAssertFalse(status.isOk)
    }

    func testStatus_EqualsAndHashCode() {
        XCTAssertEqual(Status.ok, Status.ok.withDescription(description: nil))
        XCTAssertNotEqual(Status.ok, Status.cancelled.withDescription(description: "ThisIsAnError"))
        XCTAssertNotEqual(Status.ok, Status.unknown.withDescription(description: "ThisIsAnError"))
        XCTAssertNotEqual(Status.ok.withDescription(description: nil), Status.cancelled.withDescription(description: "ThisIsAnError"))
        XCTAssertNotEqual(Status.ok.withDescription(description: nil), Status.unknown.withDescription(description: "ThisIsAnError"))
        XCTAssertEqual(Status.cancelled.withDescription(description: "ThisIsAnError"), Status.cancelled.withDescription(description: "ThisIsAnError"))
        XCTAssertNotEqual(Status.cancelled.withDescription(description: "ThisIsAnError"), Status.unknown.withDescription(description: "ThisIsAnError"))
    }
}

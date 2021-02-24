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
import XCTest

final class StatusTests: XCTestCase {
    func testStatusIsOk() {
        let statusOK = Status.ok
        XCTAssertTrue(statusOK.isOk)
        let statusUnset = Status.unset
        XCTAssertFalse(statusUnset.isOk)
        let statusError = Status.error(description: "Error")
        XCTAssertFalse(statusError.isOk)
    }

    func testStatusIsError() {
        let statusOK = Status.ok
        XCTAssertFalse(statusOK.isError)
        let statusUnset = Status.unset
        XCTAssertFalse(statusUnset.isError)
        let statusError = Status.error(description: "Error")
        XCTAssertTrue(statusError.isError)
    }
}

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

class CorrelationContextManagerSdkTests: XCTestCase {
    let distContext = CorrelationContextMock()
    let contextManager = CorrelationContextManagerSdk()

    func testGetCurrentContext_DefaultContext() {
        XCTAssertTrue(contextManager.getCurrentContext() === EmptyCorrelationContext.instance)
    }

    func testWithCorrelationContext() {
        XCTAssertTrue(contextManager.getCurrentContext() === EmptyCorrelationContext.instance)
        var wtm = contextManager.withContext(distContext: distContext)
        XCTAssertTrue(contextManager.getCurrentContext() === distContext)
        wtm.close()
        XCTAssertTrue(contextManager.getCurrentContext() === EmptyCorrelationContext.instance)
    }

    func testWithCorrelationContextUsingWrap() {
        let expec = expectation(description: "testWithCorrelationContextUsingWrap")
        var wtm = contextManager.withContext(distContext: distContext)
        XCTAssertTrue(contextManager.getCurrentContext() === distContext)
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            semaphore.wait()
            XCTAssertTrue(self.contextManager.getCurrentContext() === self.distContext)
            expec.fulfill()
        }
        wtm.close()
        semaphore.signal()
        waitForExpectations(timeout: 30) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
}

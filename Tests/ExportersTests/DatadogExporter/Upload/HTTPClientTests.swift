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

class HTTPClientTests: XCTestCase {
    func testWhenRequestIsDelivered_itReturnsHTTPResponse() {
        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 200)))
        let expectation = self.expectation(description: "receive response")
        let client = HTTPClient(session: .serverMockURLSession)

        client.send(request: .mockAny()) { result in
            switch result {
            case .success(let httpResponse):
                XCTAssertEqual(httpResponse.statusCode, 200)
                expectation.fulfill()
            case .failure:
                break
            }
        }

        waitForExpectations(timeout: 1, handler: nil)
        server.waitFor(requestsCompletion: 1)
    }

    func testWhenRequestIsNotDelivered_itReturnsHTTPRequestDeliveryError() {
        let server = ServerMock(delivery: .failure(error: ErrorMock("no internet connection")))
        let expectation = self.expectation(description: "receive response")
        let client = HTTPClient(session: .serverMockURLSession)

        client.send(request: .mockAny()) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                XCTAssertEqual((error as? ErrorMock)?.description, "no internet connection")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1, handler: nil)
        server.waitFor(requestsCompletion: 1)
    }
}

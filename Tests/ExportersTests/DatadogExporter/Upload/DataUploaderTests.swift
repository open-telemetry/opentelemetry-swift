/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import DatadogExporter
import XCTest

extension DataUploadStatus: EquatableInTests {}

class DataUploaderTests: XCTestCase {
    func testWhenUploadCompletesWithSuccess_itReturnsExpectedUploadStatus() throws {
        #if os(watchOS)
        throw XCTSkip("Implementation needs to be updated for watchOS to make this test pass")
        #else
        // Given
        let randomResponse: HTTPURLResponse = .mockResponseWith(statusCode: (100 ... 599).randomElement()!)
        let randomRequestIDOrNil: String? = Bool.random() ? .mockRandom() : nil
        let requestIDHeaderOrNil: RequestBuilder.HTTPHeader? = randomRequestIDOrNil.flatMap { randomRequestID in
            .init(field: RequestBuilder.HTTPHeader.ddRequestIDHeaderField, value: .constant(randomRequestID))
        }

        let server = ServerMock(delivery: .success(response: randomResponse))
        let uploader = DataUploader(
            httpClient: HTTPClient(session: server.getInterceptedURLSession()),
            requestBuilder: .mockWith(headers: requestIDHeaderOrNil.map { [$0] } ?? [])
        )

        // When
        let uploadStatus = uploader.upload(data: .mockAny())

        // Then
        let expectedUploadStatus = DataUploadStatus(httpResponse: randomResponse, ddRequestID: randomRequestIDOrNil)

        XCTAssertEqual(uploadStatus, expectedUploadStatus)
        server.waitFor(requestsCompletion: 1)
        #endif
    }

    func testWhenUploadCompletesWithFailure_itReturnsExpectedUploadStatus() throws {
        #if os(watchOS)
        throw XCTSkip("Implementation needs to be updated for watchOS to make this test pass")
        #else
        // Given
        let randomErrorDescription: String = .mockRandom()
        let randomError = NSError(domain: .mockRandom(), code: .mockRandom(), userInfo: [NSLocalizedDescriptionKey: randomErrorDescription])

        let server = ServerMock(delivery: .failure(error: randomError))
        let uploader = DataUploader(
            httpClient: HTTPClient(session: server.getInterceptedURLSession()),
            requestBuilder: .mockAny()
        )

        // When
        let uploadStatus = uploader.upload(data: .mockAny())

        // Then
        let expectedUploadStatus = DataUploadStatus(networkError: randomError)

        XCTAssertEqual(uploadStatus, expectedUploadStatus)
        server.waitFor(requestsCompletion: 1)
        #endif
    }
}

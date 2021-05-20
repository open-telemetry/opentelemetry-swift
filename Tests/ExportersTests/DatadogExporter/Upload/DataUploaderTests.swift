/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import DatadogExporter
import XCTest

class DataUploadURLProviderTests: XCTestCase {
    func testDDSourceQueryItem() {
        let item: UploadURLProvider.QueryItemProvider = .ddsource()

        XCTAssertEqual(item.value().name, "ddsource")
        XCTAssertEqual(item.value().value, "ios")
    }

    func testBatchTimeQueryItem() {
        let dateProvider = RelativeDateProvider(using: Date.mockDecember15th2019At10AMUTC())
        let item: UploadURLProvider.QueryItemProvider = .batchTime(using: dateProvider)

        XCTAssertEqual(item.value().name, "batch_time")
        XCTAssertEqual(item.value().value, "1576404000000")
        dateProvider.advance(bySeconds: 9.999)
        XCTAssertEqual(item.value().name, "batch_time")
        XCTAssertEqual(item.value().value, "1576404009999")
    }

    func testItBuildsValidURLUsingNoQueryItems() throws {
        let urlProvider = UploadURLProvider(
            urlWithClientToken: URL(string: "https://api.example.com/v1/endpoint/abc")!,
            queryItemProviders: []
        )

        XCTAssertEqual(urlProvider.url, URL(string: "https://api.example.com/v1/endpoint/abc?"))
    }

    func testItBuildsValidURLUsingAllQueryItems() throws {
        let dateProvider = RelativeDateProvider(using: Date.mockDecember15th2019At10AMUTC())
        let urlProvider = UploadURLProvider(
            urlWithClientToken: URL(string: "https://api.example.com/v1/endpoint/abc")!,
            queryItemProviders: [.ddsource(), .batchTime(using: dateProvider)]
        )

        XCTAssertEqual(urlProvider.url, URL(string: "https://api.example.com/v1/endpoint/abc?ddsource=ios&batch_time=1576404000000"))
        dateProvider.advance(bySeconds: 9.999)
        XCTAssertEqual(urlProvider.url, URL(string: "https://api.example.com/v1/endpoint/abc?ddsource=ios&batch_time=1576404009999"))
    }
}

class DataUploaderTests: XCTestCase {
    // MARK: - Upload Status

    func testWhenDataIsSentWith200Code_itReturnsDataUploadStatus_success() {
        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 200)))
        let uploader = DataUploader(
            urlProvider: .mockAny(),
            httpClient: HTTPClient(session: .serverMockURLSession),
            httpHeaders: .mockAny()
        )
        let status = uploader.upload(data: .mockAny())

        XCTAssertEqual(status, .success)
        server.waitFor(requestsCompletion: 1)
    }

    func testWhenDataIsSentWith300Code_itReturnsDataUploadStatus_redirection() {
        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 300)))
        let uploader = DataUploader(
            urlProvider: .mockAny(),
            httpClient: HTTPClient(session: .serverMockURLSession),
            httpHeaders: .mockAny()
        )
        let status = uploader.upload(data: .mockAny())

        XCTAssertEqual(status, .redirection)
        server.waitFor(requestsCompletion: 1)
    }

    func testWhenDataIsSentWith400Code_itReturnsDataUploadStatus_clientError() {
        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 400)))
        let uploader = DataUploader(
            urlProvider: .mockAny(),
            httpClient: HTTPClient(session: .serverMockURLSession),
            httpHeaders: .mockAny()
        )
        let status = uploader.upload(data: .mockAny())

        XCTAssertEqual(status, .clientError)
        server.waitFor(requestsCompletion: 1)
    }

    func testWhenDataIsSentWith403Code_itReturnsDataUploadStatus_clientTokenError() {
        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 403)))
        let uploader = DataUploader(
            urlProvider: .mockAny(),
            httpClient: HTTPClient(session: .serverMockURLSession),
            httpHeaders: .mockAny()
        )
        let status = uploader.upload(data: .mockAny())

        XCTAssertEqual(status, .clientTokenError)
        server.waitFor(requestsCompletion: 1)
    }

    func testWhenDataIsSentWith500Code_itReturnsDataUploadStatus_serverError() {
        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 500)))
        let uploader = DataUploader(
            urlProvider: .mockAny(),
            httpClient: HTTPClient(session: .serverMockURLSession),
            httpHeaders: .mockAny()
        )
        let status = uploader.upload(data: .mockAny())

        XCTAssertEqual(status, .serverError)
        server.waitFor(requestsCompletion: 1)
    }

    func testWhenDataIsNotSentDueToNetworkError_itReturnsDataUploadStatus_networkError() {
        let server = ServerMock(delivery: .failure(error: ErrorMock("network error")))
        let uploader = DataUploader(
            urlProvider: .mockAny(),
            httpClient: HTTPClient(session: .serverMockURLSession),
            httpHeaders: .mockAny()
        )
        let status = uploader.upload(data: .mockAny())

        XCTAssertEqual(status, .networkError)
        server.waitFor(requestsCompletion: 1)
    }

    func testWhenDataIsNotSentDueToUnknownStatusCode_itReturnsDataUploadStatus_unknown() {
        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: -1)))
        let uploader = DataUploader(
            urlProvider: .mockAny(),
            httpClient: HTTPClient(session: .serverMockURLSession),
            httpHeaders: .mockAny()
        )
        let status = uploader.upload(data: .mockAny())

        XCTAssertEqual(status, .unknown)
        server.waitFor(requestsCompletion: 1)
    }
}

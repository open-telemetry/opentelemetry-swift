/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import DatadogExporter
import XCTest

class DataUploadWorkerTests: XCTestCase {
    private let temporaryDirectory = obtainUniqueTemporaryDirectory()

    lazy var dateProvider = RelativeDateProvider(advancingBySeconds: 1)
    lazy var orchestrator = FilesOrchestrator(
        directory: temporaryDirectory,
        performance: StoragePerformanceMock.writeEachObjectToNewFileAndReadAllFiles,
        dateProvider: dateProvider
    )
    lazy var writer = FileWriter(
        dataFormat: .mockWith(prefix: "[", suffix: "]"),
        orchestrator: orchestrator
    )
    lazy var reader = FileReader(
        dataFormat: .mockWith(prefix: "[", suffix: "]"),
        orchestrator: orchestrator
    )

    override func setUp() {
        super.setUp()
        temporaryDirectory.create()
    }

    override func tearDown() {
        temporaryDirectory.delete()
        super.tearDown()
    }

    // MARK: - Data Uploads

    func testItUploadsAllData() throws {
        #if os(watchOS)
        throw XCTSkip("Implementation needs to be updated for watchOS to make this test pass")
        #else
        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 200)))
        let dataUploader = DataUploader(
            httpClient: HTTPClient(session: server.getInterceptedURLSession()),
            requestBuilder: .mockAny()
        )

        // Given
        writer.write(value: ["k1": "v1"])
        writer.write(value: ["k2": "v2"])
        writer.write(value: ["k3": "v3"])

        // When
        let worker = DataUploadWorker(
            fileReader: reader,
            dataUploader: dataUploader,
            uploadCondition: { true },
            delay: DataUploadDelay(performance: UploadPerformanceMock.veryQuick),
            featureName: .mockAny()
        )

        // Then
        let recordedRequests = server.waitAndReturnRequests(count: 3)
        XCTAssertTrue(recordedRequests.contains { $0.httpBody == #"[{"k1":"v1"}]"#.utf8Data })
        XCTAssertTrue(recordedRequests.contains { $0.httpBody == #"[{"k2":"v2"}]"#.utf8Data })
        XCTAssertTrue(recordedRequests.contains { $0.httpBody == #"[{"k3":"v3"}]"#.utf8Data })

        worker.cancelSynchronously()

        XCTAssertEqual(try temporaryDirectory.files().count, 0)
        #endif
    }

    func testGivenDataToUpload_whenUploadFinishesAndDoesNotNeedToBeRetried_thenDataIsDeleted() {
        let startUploadExpectation = self.expectation(description: "Upload has started")

        var mockDataUploader = DataUploaderMock(uploadStatus: .mockWith(needsRetry: false))
        mockDataUploader.onUpload = { startUploadExpectation.fulfill() }

        // Given
        writer.writeSync(value: ["key": "value"])
        XCTAssertEqual(try temporaryDirectory.files().count, 1)

        // When
        let worker = DataUploadWorker(
            fileReader: reader,
            dataUploader: mockDataUploader,
            uploadCondition: { true },
            delay: DataUploadDelay(performance: UploadPerformanceMock.veryQuick),
            featureName: .mockAny()
        )

        wait(for: [startUploadExpectation], timeout: .timeout)
        worker.cancelSynchronously()

        // Then
        XCTAssertEqual(try temporaryDirectory.files().count, 0, "When upload finishes with `needsRetry: false`, data should be deleted")
    }

    func testGivenDataToUpload_whenUploadFinishesAndNeedsToBeRetried_thenDataIsPreserved() {
        let startUploadExpectation = self.expectation(description: "Upload has started")

        var mockDataUploader = DataUploaderMock(uploadStatus: .mockWith(needsRetry: true))
        mockDataUploader.onUpload = { startUploadExpectation.fulfill() }

        // Given
        writer.writeSync(value: ["key": "value"])
        XCTAssertEqual(try temporaryDirectory.files().count, 1)

        // When
        let worker = DataUploadWorker(
            fileReader: reader,
            dataUploader: mockDataUploader,
            uploadCondition: { true },
            delay: DataUploadDelay(performance: UploadPerformanceMock.veryQuick),
            featureName: .mockAny()
        )

        wait(for: [startUploadExpectation], timeout: .timeout)
        worker.cancelSynchronously()

        // Then
        XCTAssertEqual(try temporaryDirectory.files().count, 1, "When upload finishes with `needsRetry: true`, data should be preserved")
    }

    // MARK: - Upload Interval Changes

    func testWhenThereIsNoBatch_thenIntervalIncreases() {
        let delayChangeExpectation = expectation(description: "Upload delay is increased")
        let mockDelay = MockDelay { command in
            if case .increase = command {
                delayChangeExpectation.fulfill()
            } else {
                XCTFail("Wrong command is sent!")
            }
        }

        // When
        XCTAssertEqual(try temporaryDirectory.files().count, 0)

        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 200)))
        let dataUploader = DataUploader(
            httpClient: HTTPClient(session: server.getInterceptedURLSession()),
            requestBuilder: .mockAny()
        )
        let worker = DataUploadWorker(
            fileReader: reader,
            dataUploader: dataUploader,
            uploadCondition: { false },
            delay: mockDelay,
            featureName: .mockAny()
        )

        // Then
        server.waitFor(requestsCompletion: 0)
        waitForExpectations(timeout: .timeout)
        worker.cancelSynchronously()
    }

    func testWhenBatchFails_thenIntervalIncreases() throws {
        #if os(watchOS)
        throw XCTSkip("Implementation needs to be updated for watchOS to make this test pass")
        #else
        let delayChangeExpectation = expectation(description: "Upload delay is increased")
        let mockDelay = MockDelay { command in
            if case .increase = command {
                delayChangeExpectation.fulfill()
            } else {
                XCTFail("Wrong command is sent!")
            }
        }

        // When
        writer.write(value: ["k1": "v1"])

        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 500)))
        let dataUploader = DataUploader(
            httpClient: HTTPClient(session: server.getInterceptedURLSession()),
            requestBuilder: .mockAny()
        )
        let worker = DataUploadWorker(
            fileReader: reader,
            dataUploader: dataUploader,
            uploadCondition: { true },
            delay: mockDelay,
            featureName: .mockAny()
        )

        // Then
        server.waitFor(requestsCompletion: 1)
        waitForExpectations(timeout: .timeout)
        worker.cancelSynchronously()
        #endif
    }

    func testWhenBatchSucceeds_thenIntervalDecreases() throws {
        #if os(watchOS)
        throw XCTSkip("Implementation needs to be updated for watchOS to make this test pass")
        #else
        let delayChangeExpectation = expectation(description: "Upload delay is decreased")
        let mockDelay = MockDelay { command in
            if case .decrease = command {
                delayChangeExpectation.fulfill()
            } else {
                XCTFail("Wrong command is sent!")
            }
        }

        // When
        writer.write(value: ["k1": "v1"])

        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 200)))
        let dataUploader = DataUploader(
            httpClient: HTTPClient(session: server.getInterceptedURLSession()),
            requestBuilder: .mockAny()
        )
        let worker = DataUploadWorker(
            fileReader: reader,
            dataUploader: dataUploader,
            uploadCondition: { true },
            delay: mockDelay,
            featureName: .mockAny()
        )

        // Then
        server.waitFor(requestsCompletion: 1)
        waitForExpectations(timeout: .timeout)
        worker.cancelSynchronously()
        #endif
    }

    // MARK: - Tearing Down

    func testWhenCancelled_itPerformsNoMoreUploads() {
        // Given
        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 200)))
        let dataUploader = DataUploader(
            httpClient: HTTPClient(session: server.getInterceptedURLSession()),
            requestBuilder: .mockAny()
        )
        let worker = DataUploadWorker(
            fileReader: reader,
            dataUploader: dataUploader,
            uploadCondition: { false },
            delay: MockDelay(),
            featureName: .mockAny()
        )

        // When
        worker.cancelSynchronously()

        // Then
        writer.write(value: ["k1": "v1"])

        server.waitFor(requestsCompletion: 0)
    }

    func testItFlushesAllData() throws {
        #if os(watchOS)
        throw XCTSkip("Implementation needs to be updated for watchOS to make this test pass")
        #else
        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 200)))
        let dataUploader = DataUploader(
            httpClient: HTTPClient(session: server.getInterceptedURLSession()),
            requestBuilder: .mockAny()
        )
        let worker = DataUploadWorker(
            fileReader: reader,
            dataUploader: dataUploader,
            uploadCondition: { true },
            delay: DataUploadDelay(performance: UploadPerformanceMock.veryQuick),
            featureName: .mockAny()
        )

        // Given
        writer.write(value: ["k1": "v1"])
        writer.write(value: ["k2": "v2"])
        writer.write(value: ["k3": "v3"])
        writer.queue.sync {}

        // When
        _ = worker.flush()

        // Then
        XCTAssertEqual(try temporaryDirectory.files().count, 0)

        let recordedRequests = server.waitAndReturnRequests(count: 3)
        XCTAssertTrue(recordedRequests.contains { $0.httpBody == #"[{"k1":"v1"}]"#.utf8Data })
        XCTAssertTrue(recordedRequests.contains { $0.httpBody == #"[{"k2":"v2"}]"#.utf8Data })
        XCTAssertTrue(recordedRequests.contains { $0.httpBody == #"[{"k3":"v3"}]"#.utf8Data })

        worker.cancelSynchronously()
        #endif
    }
}

struct MockDelay: Delay {
    enum Command {
        case increase, decrease
    }

    var callback: ((Command) -> Void)?
    let current: TimeInterval = 0.1

    mutating func decrease() {
        callback?(.decrease)
        callback = nil
    }

    mutating func increase() {
        callback?(.increase)
        callback = nil
    }
}

private extension TimeInterval {
    static let timeout: Self = 5
}

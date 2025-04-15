/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
@testable import FaroExporter

final class FaroTransportTests: XCTestCase {
    private var sut: FaroTransport!
    private var httpClient: MockFaroHttpClient!
    private var sessionManager: MockFaroSessionManager!
    private var endpointConfiguration: FaroEndpointConfiguration!
    
    override func setUp() {
        super.setUp()
        httpClient = MockFaroHttpClient()
        sessionManager = MockFaroSessionManager()
        endpointConfiguration = FaroEndpointConfiguration(
            collectorUrl: URL(string: "https://faro-collector.example.com/api/collect")!,
            apiKey: "test-api-key"
        )
        sut = FaroTransport(
            endpointConfiguration: endpointConfiguration,
            sessionManager: sessionManager,
            httpClient: httpClient
        )
    }
    
    override func tearDown() {
        sut = nil
        httpClient = nil
        sessionManager = nil
        endpointConfiguration = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func test_send_addsCorrectHeaders() {
        // Given
        let payload = createTestPayload()
        
        // When
        let expectation = expectation(description: "Request sent")
        sut.send(payload) { _ in
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(httpClient.lastRequest?.url, endpointConfiguration.collectorUrl)
        XCTAssertEqual(httpClient.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(httpClient.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(httpClient.lastRequest?.value(forHTTPHeaderField: "x-api-key"), endpointConfiguration.apiKey)
        XCTAssertEqual(httpClient.lastRequest?.value(forHTTPHeaderField: "x-faro-session-id"), sessionManager.sessionId)
    }
    
    func test_send_encodesPayload() {
        // Given
        let payload = createTestPayload()
        
        // When
        let expectation = expectation(description: "Request sent")
        sut.send(payload) { _ in
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(httpClient.lastRequest?.httpBody)
        
        // Validate the JSON structure matches our expected payload
        if let data = httpClient.lastRequest?.httpBody {
            let expectedData = try! JSONEncoder().encode(payload)
            
            // Convert both to dictionaries for comparison (order-independent)
            let actualJson = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
            let expectedJson = try! JSONSerialization.jsonObject(with: expectedData) as! [String: Any]
            
            // Compare top-level keys
            XCTAssertEqual(Set(actualJson.keys), Set(expectedJson.keys))
        }
    }
    
    func test_send_completesSuccessfully() {
        // Given
        let payload = createTestPayload()
        httpClient.mockResponse = (data: nil as Data?, response: HTTPURLResponse(url: endpointConfiguration.collectorUrl, statusCode: 200, httpVersion: nil, headerFields: nil), error: nil as Error?)
        
        // When
        let expectation = expectation(description: "Request completed")
        var receivedResult: Result<Void, Error>?
        sut.send(payload) { result in
            receivedResult = result
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        switch receivedResult {
        case .success:
            // Expected success
            break
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        case nil:
            XCTFail("Expected a result but got nil")
        }
    }
    
    func test_send_failsWithNetworkError() {
        // Given
        let payload = createTestPayload()
        let expectedError = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        httpClient.mockResponse = (data: nil as Data?, response: nil as URLResponse?, error: expectedError)
        
        // When
        let expectation = expectation(description: "Request completed")
        var receivedResult: Result<Void, Error>?
        sut.send(payload) { result in
            receivedResult = result
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        switch receivedResult {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error):
            guard case FaroTransportError.networkError(let underlyingError) = error else {
                XCTFail("Expected networkError but got \(error)")
                return
            }
            XCTAssertEqual(underlyingError as NSError, expectedError)
        case nil:
            XCTFail("Expected a result but got nil")
        }
    }
    
    func test_send_failsWithHttpError() {
        // Given
        let payload = createTestPayload()
        let responseData = "Error message".data(using: .utf8)
        httpClient.mockResponse = (
            data: responseData,
            response: HTTPURLResponse(url: endpointConfiguration.collectorUrl, statusCode: 400, httpVersion: nil, headerFields: nil),
            error: nil as Error?
        )
        
        // When
        let expectation = expectation(description: "Request completed")
        var receivedResult: Result<Void, Error>?
        sut.send(payload) { result in
            receivedResult = result
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        switch receivedResult {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error):
            guard case FaroTransportError.httpError(let statusCode, let message) = error else {
                XCTFail("Expected httpError but got \(error)")
                return
            }
            XCTAssertEqual(statusCode, 400)
            XCTAssertEqual(message, "Error message")
        case nil:
            XCTFail("Expected a result but got nil")
        }
    }
    
    // MARK: - Helpers
    
    private func createTestPayload() -> FaroPayload {
        return FaroPayload(
            meta: FaroMeta(
                sdk: FaroSdkInfo(name: "test-sdk", version: "1.0.0", integrations: []),
                app: FaroAppInfo(
                    name: "test-app", 
                    namespace: "com.example",
                    version: "1.0.0", 
                    environment: "test", 
                    bundleId: "com.example.app", 
                    release: "123"
                ),
                session: FaroSession(id: "test-session", attributes: [:]),
                user: FaroUser(id: "test-user", username: "user", email: "user@example.com", attributes: [:]),
                view: FaroView(name: "test-view")
            ),
            logs: [
                FaroLog(
                    timestamp: "2023-01-01T00:00:00Z",
                    level: .info,
                    message: "Test log",
                    context: nil,
                    trace: nil
                )
            ]
        )
    }
} 
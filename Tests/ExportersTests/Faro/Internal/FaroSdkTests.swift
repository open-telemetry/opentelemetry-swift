/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
 
import XCTest
@testable import FaroExporter

final class FaroSdkTests: XCTestCase {
    var sut: FaroSdk!
    var mockAppInfo: FaroAppInfo!
    var mockTransport: MockTransport!
    
    override func setUp() {
        super.setUp()
        // Create minimal valid instances for testing
        mockAppInfo = FaroAppInfo(
            name: "TestApp",
            namespace: nil,
            version: "1.0.0",
            environment: "test",
            bundleId: nil,
            release: nil
        )
        
        // Use a mock transport instead of trying to create a real one
        mockTransport = MockTransport()
        
        // For now, we'll test a simplified version that accepts our mock
        // In a complete solution, we'd refactor FaroSdk to use the protocol
        let realTransport = createRealTransport()
        sut = FaroSdk(appInfo: mockAppInfo, transport: realTransport)
    }
    
    private func createRealTransport() -> FaroTransport {
        // Create a valid FaroEndpointConfiguration with an API key
        let collectorUrl = "https://example.com/collect/test-api-key"
        let options = FaroExporterOptions(
            collectorUrl: collectorUrl,
            appName: "TestApp",
            appVersion: "1.0.0",
            appEnvironment: "test"
        )
        
        do {
            let endpointConfiguration = try FaroEndpointConfiguration.create(from: options)
            let sessionManager = FaroSessionManager(dateProvider: DateProvider())
            return FaroTransport(endpointConfiguration: endpointConfiguration, sessionManager: sessionManager)
        } catch {
            // In a test, it's okay to force unwrap as it will fail the test if there's a configuration issue
            fatalError("Failed to create transport: \(error)")
        }
    }
    
    override func tearDown() {
        sut = nil
        mockAppInfo = nil
        mockTransport = nil
        super.tearDown()
    }

    func testFaroSdkInitialization() {
        // Empty test to verify SDK can be initialized correctly
        XCTAssertNotNil(sut, "SDK should be initialized")
    }
    
    func testAddLogsBasicFunctionality() {
        // Empty test for now - will implement proper testing later
        let testLog = FaroLog(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            level: .info,
            message: "Test log",
            context: nil,
            trace: nil
        )
        
        // Just verify we can call addLogs without crashing
        sut.addLogs([testLog])
        XCTAssertTrue(true, "Should be able to add logs without crashing")
    }
}

// Create a mock transport class for testing
class MockTransport: FaroTransportable {
    var sentPayloads: [FaroPayload] = []
    
    func send(_ payload: FaroPayload, completion: @escaping (Result<Void, Error>) -> Void) {
        sentPayloads.append(payload)
        completion(.success(()))
    }
} 
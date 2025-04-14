/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
@testable import FaroExporter

final class FaroPayloadTests: XCTestCase {
    
    func testFaroPayloadEncoding() throws {
        // Given
        let sdk = FaroSdkInfo(
            name: "test-sdk",
            version: "1.0.0",
            integrations: [FaroIntegration(name: "test-integration", version: "1.0.0")]
        )
        
        let app = FaroAppInfo(
            name: "TestApp",
            namespace: "com.test",
            version: "1.0.0",
            environment: "test",
            bundleId: "com.test.app",
            release: "1.0.0"
        )
        
        let session = FaroSession(
            id: "test-session",
            attributes: ["test": "value"]
        )
        
        let user = FaroUser(
            id: "test-user",
            username: "test user",
            email: "test@example.com",
            attributes: ["test": "value"]
        )
        
        let view = FaroView(name: "TestView")
        
        let meta = FaroMeta(
            sdk: sdk,
            app: app,
            session: session,
            user: user,
            view: view
        )
        
        let log = FaroLog(
            timestamp: "2024-03-20T10:00:00Z",
            level: .info,
            message: "Test log message",
            context: ["context": "test"],
            trace: nil
        )
        
        let payload = FaroPayload(
            meta: meta,
            logs: [log]
        )
        
        // When
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(payload)
        
        // Then
        let expectedJson = """
        {
          "meta": {
            "sdk": {
              "name": "test-sdk",
              "version": "1.0.0",
              "integrations": [
                {
                  "name": "test-integration",
                  "version": "1.0.0"
                }
              ]
            },
            "app": {
              "name": "TestApp",
              "namespace": "com.test",
              "version": "1.0.0",
              "environment": "test",
              "bundleId": "com.test.app",
              "release": "1.0.0"
            },
            "session": {
              "id": "test-session",
              "attributes": {
                "test": "value"
              }
            },
            "user": {
              "id": "test-user",
              "username": "test user",
              "email": "test@example.com",
              "attributes": {
                "test": "value"
              }
            },
            "view": {
              "name": "TestView"
            }
          },
          "logs": [
            {
              "timestamp": "2024-03-20T10:00:00Z",
              "level": "info",
              "message": "Test log message",
              "context": {
                "context": "test"
              }
            }
          ]
        }
        """
        
        // Convert both strings to dictionaries for comparison (to avoid formatting differences)
        let actualDict = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let expectedDict = try JSONSerialization.jsonObject(with: expectedJson.data(using: .utf8)!) as! [String: Any]

        XCTAssertEqual(NSDictionary(dictionary: actualDict), NSDictionary(dictionary: expectedDict))
    }
} 

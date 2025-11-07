/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
import Foundation
@testable import MetricKitInstrumentation
import XCTest

@available(iOS 14.0, macOS 12.0, macCatalyst 14.0, visionOS 1.0, *)
class StackTraceTransformTests: XCTestCase {

    func testTransformStackTrace_FlattensSingleThreadWithSubFrames() throws {
        // Create Apple's format with nested subframes
        let appleFormat = """
        {
          "callStackTree": {
            "callStackPerThread": true,
            "callStacks": [
              {
                "threadAttributed": true,
                "callStackRootFrames": [
                  {
                    "binaryName": "MyApp",
                    "binaryUUID": "A1B2C3D4-5678-90AB-CDEF-1234567890AB",
                    "offsetIntoBinaryTextSegment": 1000,
                    "address": 12345678,
                    "sampleCount": 5,
                    "subFrames": [
                      {
                        "binaryName": "Foundation",
                        "binaryUUID": "B2C3D4E5-6789-01BC-DEF0-234567890ABC",
                        "offsetIntoBinaryTextSegment": 2000,
                        "address": 23456789,
                        "sampleCount": 3,
                        "subFrames": [
                          {
                            "binaryName": "libdyld.dylib",
                            "binaryUUID": "C3D4E5F6-7890-12CD-EF01-34567890ABCD",
                            "offsetIntoBinaryTextSegment": 3000,
                            "address": 34567890,
                            "sampleCount": 1
                          }
                        ]
                      }
                    ]
                  }
                ]
              }
            ]
          }
        }
        """

        let appleData = appleFormat.data(using: .utf8)!

        // Transform to simplified format
        let transformedData = transformStackTrace(appleData)
        XCTAssertNotNil(transformedData, "Transformation should succeed")

        // Parse transformed JSON
        let json = try JSONSerialization.jsonObject(with: transformedData!, options: []) as! [String: Any]

        // Verify top-level structure
        XCTAssertEqual(json["callStackPerThread"] as? Bool, true)

        let callStacks = json["callStacks"] as! [[String: Any]]
        XCTAssertEqual(callStacks.count, 1)

        let callStack = callStacks[0]
        XCTAssertEqual(callStack["threadAttributed"] as? Bool, true)

        // Verify frames are flattened in correct order (innermost to outermost)
        let frames = callStack["callStackFrames"] as! [[String: Any]]
        XCTAssertEqual(frames.count, 3, "Should have 3 flattened frames")

        // First frame (innermost)
        XCTAssertEqual(frames[0]["binaryName"] as? String, "MyApp")
        XCTAssertEqual(frames[0]["binaryUUID"] as? String, "A1B2C3D4-5678-90AB-CDEF-1234567890AB")
        XCTAssertEqual(frames[0]["offsetAddress"] as? Int, 1000)
        XCTAssertNil(frames[0]["address"], "address should be removed")
        XCTAssertNil(frames[0]["sampleCount"], "sampleCount should be removed")
        XCTAssertNil(frames[0]["subFrames"], "subFrames should be removed")

        // Second frame
        XCTAssertEqual(frames[1]["binaryName"] as? String, "Foundation")
        XCTAssertEqual(frames[1]["binaryUUID"] as? String, "B2C3D4E5-6789-01BC-DEF0-234567890ABC")
        XCTAssertEqual(frames[1]["offsetAddress"] as? Int, 2000)

        // Third frame (outermost)
        XCTAssertEqual(frames[2]["binaryName"] as? String, "libdyld.dylib")
        XCTAssertEqual(frames[2]["binaryUUID"] as? String, "C3D4E5F6-7890-12CD-EF01-34567890ABCD")
        XCTAssertEqual(frames[2]["offsetAddress"] as? Int, 3000)
    }

    func testTransformStackTrace_HandlesMultipleThreads() throws {
        // Create Apple's format with multiple threads
        let appleFormat = """
        {
          "callStackTree": {
            "callStackPerThread": false,
            "callStacks": [
              {
                "threadAttributed": false,
                "callStackRootFrames": [
                  {
                    "binaryName": "Thread1",
                    "binaryUUID": "11111111-1111-1111-1111-111111111111",
                    "offsetIntoBinaryTextSegment": 100
                  }
                ]
              },
              {
                "threadAttributed": true,
                "callStackRootFrames": [
                  {
                    "binaryName": "Thread2",
                    "binaryUUID": "22222222-2222-2222-2222-222222222222",
                    "offsetIntoBinaryTextSegment": 200,
                    "subFrames": [
                      {
                        "binaryName": "Thread2Sub",
                        "binaryUUID": "33333333-3333-3333-3333-333333333333",
                        "offsetIntoBinaryTextSegment": 300
                      }
                    ]
                  }
                ]
              }
            ]
          }
        }
        """

        let appleData = appleFormat.data(using: .utf8)!

        // Transform to simplified format
        let transformedData = transformStackTrace(appleData)
        XCTAssertNotNil(transformedData, "Transformation should succeed")

        // Parse transformed JSON
        let json = try JSONSerialization.jsonObject(with: transformedData!, options: []) as! [String: Any]

        // Verify top-level structure
        XCTAssertEqual(json["callStackPerThread"] as? Bool, false)

        let callStacks = json["callStacks"] as! [[String: Any]]
        XCTAssertEqual(callStacks.count, 2)

        // First thread
        let thread1 = callStacks[0]
        XCTAssertEqual(thread1["threadAttributed"] as? Bool, false)
        let frames1 = thread1["callStackFrames"] as! [[String: Any]]
        XCTAssertEqual(frames1.count, 1)
        XCTAssertEqual(frames1[0]["binaryName"] as? String, "Thread1")

        // Second thread (the one that crashed)
        let thread2 = callStacks[1]
        XCTAssertEqual(thread2["threadAttributed"] as? Bool, true)
        let frames2 = thread2["callStackFrames"] as! [[String: Any]]
        XCTAssertEqual(frames2.count, 2, "Should have 2 frames from root + subframe")
        XCTAssertEqual(frames2[0]["binaryName"] as? String, "Thread2")
        XCTAssertEqual(frames2[1]["binaryName"] as? String, "Thread2Sub")
    }

    func testTransformStackTrace_HandlesMultipleRootFrames() throws {
        // Create Apple's format with multiple root frames in a single thread
        let appleFormat = """
        {
          "callStackTree": {
            "callStackPerThread": true,
            "callStacks": [
              {
                "callStackRootFrames": [
                  {
                    "binaryName": "Root1",
                    "binaryUUID": "11111111-1111-1111-1111-111111111111",
                    "offsetIntoBinaryTextSegment": 100,
                    "subFrames": [
                      {
                        "binaryName": "Root1Sub",
                        "binaryUUID": "22222222-2222-2222-2222-222222222222",
                        "offsetIntoBinaryTextSegment": 200
                      }
                    ]
                  },
                  {
                    "binaryName": "Root2",
                    "binaryUUID": "33333333-3333-3333-3333-333333333333",
                    "offsetIntoBinaryTextSegment": 300
                  }
                ]
              }
            ]
          }
        }
        """

        let appleData = appleFormat.data(using: .utf8)!

        // Transform to simplified format
        let transformedData = transformStackTrace(appleData)
        XCTAssertNotNil(transformedData, "Transformation should succeed")

        // Parse transformed JSON
        let json = try JSONSerialization.jsonObject(with: transformedData!, options: []) as! [String: Any]

        let callStacks = json["callStacks"] as! [[String: Any]]
        XCTAssertEqual(callStacks.count, 1)

        // All frames from all root frames should be flattened
        let frames = callStacks[0]["callStackFrames"] as! [[String: Any]]
        XCTAssertEqual(frames.count, 3, "Should have 3 frames: Root1, Root1Sub, Root2")
        XCTAssertEqual(frames[0]["binaryName"] as? String, "Root1")
        XCTAssertEqual(frames[1]["binaryName"] as? String, "Root1Sub")
        XCTAssertEqual(frames[2]["binaryName"] as? String, "Root2")
    }

    func testTransformStackTrace_RemovesCallStackTreeWrapper() throws {
        // Verify that the callStackTree wrapper is removed in the output
        let appleFormat = """
        {
          "callStackTree": {
            "callStackPerThread": true,
            "callStacks": [
              {
                "callStackRootFrames": [
                  {
                    "binaryName": "Test",
                    "binaryUUID": "12345678-1234-1234-1234-123456789012",
                    "offsetIntoBinaryTextSegment": 100
                  }
                ]
              }
            ]
          }
        }
        """

        let appleData = appleFormat.data(using: .utf8)!
        let transformedData = transformStackTrace(appleData)
        XCTAssertNotNil(transformedData)

        let json = try JSONSerialization.jsonObject(with: transformedData!, options: []) as! [String: Any]

        // Should NOT have callStackTree wrapper
        XCTAssertNil(json["callStackTree"], "callStackTree wrapper should be removed")

        // Should have callStackPerThread and callStacks at root level
        XCTAssertNotNil(json["callStackPerThread"])
        XCTAssertNotNil(json["callStacks"])
    }

    func testTransformStackTrace_HandlesInvalidJSON() {
        // Test with invalid JSON
        let invalidData = "not valid json".data(using: .utf8)!

        let result = transformStackTrace(invalidData)

        // Should return nil on failure
        XCTAssertNil(result, "Should return nil for invalid JSON")
    }

    func testTransformStackTrace_HandlesMissingOptionalFields() throws {
        // Test with minimal valid data (no optional fields)
        let minimalFormat = """
        {
          "callStackTree": {
            "callStackPerThread": true,
            "callStacks": [
              {
                "callStackRootFrames": [
                  {
                    "binaryName": "Test",
                    "binaryUUID": "12345678-1234-1234-1234-123456789012",
                    "offsetIntoBinaryTextSegment": 100
                  }
                ]
              }
            ]
          }
        }
        """

        let appleData = minimalFormat.data(using: .utf8)!
        let transformedData = transformStackTrace(appleData)

        XCTAssertNotNil(transformedData, "Should handle minimal valid data")

        let json = try JSONSerialization.jsonObject(with: transformedData!, options: []) as! [String: Any]
        let callStacks = json["callStacks"] as! [[String: Any]]

        // threadAttributed is optional, should be present but might be nil
        XCTAssertEqual(callStacks[0]["threadAttributed"] as? Bool, nil)

        let frames = callStacks[0]["callStackFrames"] as! [[String: Any]]
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0]["binaryName"] as? String, "Test")
    }

    func testTransformStackTrace_PreservesFrameOrder() throws {
        // Test that frames are ordered correctly: innermost to outermost
        let appleFormat = """
        {
          "callStackTree": {
            "callStackPerThread": true,
            "callStacks": [
              {
                "callStackRootFrames": [
                  {
                    "binaryName": "Frame1_Innermost",
                    "binaryUUID": "11111111-1111-1111-1111-111111111111",
                    "offsetIntoBinaryTextSegment": 100,
                    "subFrames": [
                      {
                        "binaryName": "Frame2_Middle",
                        "binaryUUID": "22222222-2222-2222-2222-222222222222",
                        "offsetIntoBinaryTextSegment": 200,
                        "subFrames": [
                          {
                            "binaryName": "Frame3_Outer",
                            "binaryUUID": "33333333-3333-3333-3333-333333333333",
                            "offsetIntoBinaryTextSegment": 300,
                            "subFrames": [
                              {
                                "binaryName": "Frame4_Outermost",
                                "binaryUUID": "44444444-4444-4444-4444-444444444444",
                                "offsetIntoBinaryTextSegment": 400
                              }
                            ]
                          }
                        ]
                      }
                    ]
                  }
                ]
              }
            ]
          }
        }
        """

        let appleData = appleFormat.data(using: .utf8)!
        let transformedData = transformStackTrace(appleData)
        XCTAssertNotNil(transformedData)

        let json = try JSONSerialization.jsonObject(with: transformedData!, options: []) as! [String: Any]
        let callStacks = json["callStacks"] as! [[String: Any]]
        let frames = callStacks[0]["callStackFrames"] as! [[String: Any]]

        XCTAssertEqual(frames.count, 4)
        XCTAssertEqual(frames[0]["binaryName"] as? String, "Frame1_Innermost")
        XCTAssertEqual(frames[1]["binaryName"] as? String, "Frame2_Middle")
        XCTAssertEqual(frames[2]["binaryName"] as? String, "Frame3_Outer")
        XCTAssertEqual(frames[3]["binaryName"] as? String, "Frame4_Outermost")
    }
}
#endif

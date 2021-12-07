/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
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
    
    func testStatusCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        var status = Status.ok
        var decodedStatus = try decoder.decode(Status.self, from: try encoder.encode(status))
        XCTAssertEqual(status, decodedStatus)
        
        status = Status.unset
        decodedStatus = try decoder.decode(Status.self, from: try encoder.encode(status))
        XCTAssertEqual(status, decodedStatus)
        
        status = Status.error(description: "Error")
        decodedStatus = try decoder.decode(Status.self, from: try encoder.encode(status))
        XCTAssertEqual(status, decodedStatus)
        
        status = Status.error(description: "")
        decodedStatus = try decoder.decode(Status.self, from: try encoder.encode(status))
        XCTAssertEqual(status, decodedStatus)
        
        XCTAssertThrowsError(try decoder.decode(Status.self, from: "".data(using: .utf8)!))
        XCTAssertThrowsError(try decoder.decode(Status.self,
                                                from: #"{"error":{"description":"Error"}, "ok":{}}"#.data(using: .utf8)!))
    }
    
    #if swift(>=5.5)
    // this test covers forward compatibility of the pre swift 5.5 encoding with post swift 5.5 decoding
    func testStatusExplicitCodableForwardCompatibility() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        var status = StatusExplicitCodable(status: Status.ok)
        var decodedStatus = try decoder.decode(Status.self, from: try encoder.encode(status))
        XCTAssertEqual(status.status, decodedStatus)
        
        status = StatusExplicitCodable(status: Status.unset)
        decodedStatus = try decoder.decode(Status.self, from: try encoder.encode(status))
        XCTAssertEqual(status.status, decodedStatus)
        
        status = StatusExplicitCodable(status: Status.error(description: "Error"))
        decodedStatus = try decoder.decode(Status.self, from: try encoder.encode(status))
        XCTAssertEqual(status.status, decodedStatus)
        
        status = StatusExplicitCodable(status: Status.error(description: ""))
        decodedStatus = try decoder.decode(Status.self, from: try encoder.encode(status))
        XCTAssertEqual(status.status, decodedStatus)
        
        XCTAssertThrowsError(try decoder.decode(StatusExplicitCodable.self, from: "".data(using: .utf8)!))
        XCTAssertThrowsError(try decoder.decode(StatusExplicitCodable.self,
                                                from: #"{"error":{"description":"Error"}, "ok":{}}"#.data(using: .utf8)!))
    }
    #endif
}

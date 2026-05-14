/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryProtocolExporterHttp
import XCTest

final class OtlpHttpLockCoverageTests: XCTestCase {
  func testLockLockUnlock() {
    let lock = Lock()
    lock.lock()
    lock.unlock()
  }

  func testLockWithLockReturnsValue() {
    let lock = Lock()
    XCTAssertEqual(lock.withLock { "x" }, "x")
  }

  func testLockWithLockVoid() {
    let lock = Lock()
    var x = 0
    lock.withLockVoid { x = 1 }
    XCTAssertEqual(x, 1)
  }

  func testLockWithLockRethrowsErrors() {
    struct MyError: Error {}
    let lock = Lock()
    XCTAssertThrowsError(try lock.withLock { throw MyError() })
  }

  func testReadWriteLockReaderAndWriter() {
    let rw = ReadWriteLock()
    rw.lockRead()
    rw.unlock()
    rw.lockWrite()
    rw.unlock()
  }

  func testReadWriteLockWithReaderLockReturnsValue() {
    let rw = ReadWriteLock()
    XCTAssertEqual(rw.withReaderLock { "r" }, "r")
  }

  func testReadWriteLockWithWriterLockReturnsValue() {
    let rw = ReadWriteLock()
    XCTAssertEqual(rw.withWriterLock { 9 }, 9)
  }

  func testReadWriteLockVoidVariants() {
    let rw = ReadWriteLock()
    var r = 0, w = 0
    rw.withReaderLockVoid { r = 1 }
    rw.withWriterLockVoid { w = 2 }
    XCTAssertEqual(r, 1)
    XCTAssertEqual(w, 2)
  }

  func testReadWriteLockRethrowsReader() {
    struct MyError: Error {}
    let rw = ReadWriteLock()
    XCTAssertThrowsError(try rw.withReaderLock { () throws -> Int in throw MyError() })
  }

  func testReadWriteLockRethrowsWriter() {
    struct MyError: Error {}
    let rw = ReadWriteLock()
    XCTAssertThrowsError(try rw.withWriterLock { () throws -> Int in throw MyError() })
  }
}

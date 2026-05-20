/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTracingShim
import XCTest

final class OpenTracingShimLocksCoverageTests: XCTestCase {
  func testLockLockUnlock() {
    let lock = Lock()
    lock.lock()
    lock.unlock()
  }

  func testLockWithLockReturnsValue() {
    let lock = Lock()
    let result: Int = lock.withLock { 42 }
    XCTAssertEqual(result, 42)
  }

  func testLockWithLockVoid() {
    let lock = Lock()
    var counter = 0
    lock.withLockVoid { counter += 1 }
    XCTAssertEqual(counter, 1)
  }

  func testLockWithLockRethrowsErrors() {
    struct MyError: Error {}
    let lock = Lock()
    XCTAssertThrowsError(try lock.withLock { throw MyError() })
  }

  func testLockIsReentrantSafeAcrossCalls() {
    let lock = Lock()
    var sum = 0
    for _ in 0..<100 {
      lock.withLockVoid { sum += 1 }
    }
    XCTAssertEqual(sum, 100)
  }

  func testReadWriteLockReaders() {
    let rw = ReadWriteLock()
    rw.lockRead()
    rw.unlock()
  }

  func testReadWriteLockWriters() {
    let rw = ReadWriteLock()
    rw.lockWrite()
    rw.unlock()
  }

  func testReadWriteLockWithReaderLockReturnsValue() {
    let rw = ReadWriteLock()
    XCTAssertEqual(rw.withReaderLock { "hello" }, "hello")
  }

  func testReadWriteLockWithWriterLockReturnsValue() {
    let rw = ReadWriteLock()
    XCTAssertEqual(rw.withWriterLock { 7 }, 7)
  }

  func testReadWriteLockWithReaderLockVoid() {
    let rw = ReadWriteLock()
    var touched = false
    rw.withReaderLockVoid { touched = true }
    XCTAssertTrue(touched)
  }

  func testReadWriteLockWithWriterLockVoid() {
    let rw = ReadWriteLock()
    var counter = 0
    rw.withWriterLockVoid { counter = 5 }
    XCTAssertEqual(counter, 5)
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

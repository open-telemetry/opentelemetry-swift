/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import SwiftMetricsShim
import XCTest

final class SwiftMetricsShimLocksCoverageTests: XCTestCase {
  func testLockLockUnlock() {
    let lock = Lock()
    lock.lock()
    lock.unlock()
  }

  func testLockWithLockReturnsValue() {
    let lock = Lock()
    XCTAssertEqual(lock.withLock { 1 + 2 }, 3)
  }

  func testLockWithLockVoid() {
    let lock = Lock()
    var reached = false
    lock.withLockVoid { reached = true }
    XCTAssertTrue(reached)
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

  func testLockedStoresAndMutates() {
    let locked = Locked<Int>(initialValue: 0)
    XCTAssertEqual(locked.protectedValue, 0)
    locked.protectedValue = 42
    XCTAssertEqual(locked.protectedValue, 42)
  }

  func testLockedLockingApplies() {
    let locked = Locked<[String]>(initialValue: [])
    locked.locking { $0.append("hello") }
    locked.locking { $0.append("world") }
    XCTAssertEqual(locked.protectedValue, ["hello", "world"])
  }

  func testLockedLockingReturnsValue() {
    let locked = Locked<Int>(initialValue: 10)
    let r: Int = locked.locking { v in
      v += 5
      return v
    }
    XCTAssertEqual(r, 15)
    XCTAssertEqual(locked.protectedValue, 15)
  }
}

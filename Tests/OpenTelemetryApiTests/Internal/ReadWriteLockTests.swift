/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import XCTest
import OpenTelemetryApi

final class ReadWriteLockTests: XCTestCase {
  // MARK: - Basic semantics

  func testReaderLockReturnsBodyValue() {
    let lock = ReadWriteLock()
    XCTAssertEqual(lock.withReaderLock { 42 }, 42)
  }

  func testWriterLockReturnsBodyValue() {
    let lock = ReadWriteLock()
    XCTAssertEqual(lock.withWriterLock { "value" }, "value")
  }

  func testReaderLockRethrowsAndUnlocks() {
    let lock = ReadWriteLock()
    struct TestError: Error {}

    XCTAssertThrowsError(try lock.withReaderLock { throw TestError() })
    // If the error path leaked the lock, this writer acquisition would deadlock.
    XCTAssertEqual(lock.withWriterLock { 1 }, 1)
  }

  func testWriterLockRethrowsAndUnlocks() {
    let lock = ReadWriteLock()
    struct TestError: Error {}

    XCTAssertThrowsError(try lock.withWriterLock { throw TestError() })
    XCTAssertEqual(lock.withWriterLock { 1 }, 1)
  }

  func testSequentialReadAfterWrite() {
    let lock = ReadWriteLock()
    var value = 0
    lock.withWriterLock { value = 7 }
    XCTAssertEqual(lock.withReaderLock { value }, 7)
  }

  // MARK: - Concurrency

  /// Two readers must be able to hold the lock at the same time. Each reader
  /// waits inside its critical section until the other has also entered; if
  /// readers excluded each other this would time out.
  func testConcurrentReadersOverlap() {
    let lock = ReadWriteLock()
    let bothInside = DispatchSemaphore(value: 0)
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.readers.overlap", attributes: .concurrent)
    let entered = ManagedAtomic()

    for _ in 0 ..< 2 {
      group.enter()
      queue.async {
        lock.withReaderLock {
          if entered.incrementAndGet() == 2 {
            bothInside.signal()
            bothInside.signal()
          }
          XCTAssertEqual(bothInside.wait(timeout: .now() + 5), .success,
                         "Both readers should be inside the lock simultaneously")
        }
        group.leave()
      }
    }

    waitForConcurrentWork(group, "concurrent work should complete")
  }

  /// Writers must be mutually exclusive: unsynchronized increments from many
  /// threads would lose updates, so an exact final count proves exclusion.
  func testWriterMutualExclusion() {
    let lock = ReadWriteLock()
    let iterations = 10000
    let state = LockGuardedState()
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.writer.exclusion", attributes: .concurrent)

    for _ in 0 ..< iterations {
      group.enter()
      queue.async {
        lock.withWriterLock { state.a += 1 }
        group.leave()
      }
    }

    waitForConcurrentWork(group, "concurrent work should complete")
    XCTAssertEqual(lock.withReaderLock { state.a }, iterations)
  }

  /// Readers must never observe a writer's half-applied update. The writer
  /// updates two variables that should always be equal; a reader running
  /// during the write would see them differ.
  func testReadersNeverObserveTornWrites() {
    let lock = ReadWriteLock()
    let state = LockGuardedState()
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.torn.writes", attributes: .concurrent)

    for i in 0 ..< 2000 {
      group.enter()
      queue.async {
        if i % 4 == 0 {
          lock.withWriterLock {
            state.a += 1
            state.b += 1
          }
        } else {
          let (x, y) = lock.withReaderLock { (state.a, state.b) }
          XCTAssertEqual(x, y, "Reader observed a partially applied write")
        }
        group.leave()
      }
    }

    waitForConcurrentWork(group, "concurrent work should complete")
    XCTAssertEqual(lock.withReaderLock { state.a }, 500)
  }
}

/// Mutable state shared across test threads. Safe only because every access
/// happens inside the ReadWriteLock under test.
private final class LockGuardedState: @unchecked Sendable {
  var a = 0
  var b = 0
}

/// Minimal lock-free counter used to coordinate test threads without relying
/// on the lock under test.
private final class ManagedAtomic: @unchecked Sendable {
  private var value = 0
  private let sync = NSLock()

  func incrementAndGet() -> Int {
    sync.lock()
    defer { sync.unlock() }
    value += 1
    return value
  }
}

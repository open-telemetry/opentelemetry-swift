/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

final class TracerProviderSdkConcurrencyTests: XCTestCase {

  // MARK: - Concurrent get with same name returns same instance

  func testConcurrentGetSameName() {
    nonisolated(unsafe) let provider = TracerProviderSdk()
    let threads = 100
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.provider.sameName", attributes: .concurrent)
    let tracers = LockedArray<Tracer>()

    for _ in 0..<threads {
      group.enter()
      queue.async {
        let tracer = provider.get(instrumentationName: "shared-tracer", instrumentationVersion: "1.0")
        tracers.append(tracer)
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent get() should complete without deadlock")
    let allTracers = tracers.values
    XCTAssertEqual(allTracers.count, threads)

    let first = allTracers[0] as AnyObject
    for tracer in allTracers {
      XCTAssertTrue((tracer as AnyObject) === first,
                    "All threads must receive the same TracerSdk instance")
    }
  }

  // MARK: - Concurrent get with different names

  func testConcurrentGetDifferentNames() {
    nonisolated(unsafe) let provider = TracerProviderSdk()
    let threads = 100
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.provider.diffNames", attributes: .concurrent)
    let tracers = LockedDictionary<String, Tracer>()

    for i in 0..<threads {
      group.enter()
      queue.async {
        let name = "tracer-\(i)"
        let tracer = provider.get(instrumentationName: name)
        tracers.set(key: name, value: tracer)
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent get() with different names should complete")
    let allTracers = tracers.values
    XCTAssertEqual(allTracers.count, threads, "Each unique name should produce a unique tracer")

    let identities = Set(allTracers.values.map { ObjectIdentifier($0 as AnyObject) })
    XCTAssertEqual(identities.count, threads, "All tracers should be distinct instances")
  }

  // MARK: - Concurrent get during shutdown

  func testConcurrentGetDuringShutdown() {
    nonisolated(unsafe) let provider = TracerProviderSdk()
    let threads = 50
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.provider.shutdown", attributes: .concurrent)

    group.enter()
    queue.async {
      provider.shutdown()
      group.leave()
    }

    for i in 0..<threads {
      group.enter()
      queue.async {
        _ = provider.get(instrumentationName: "tracer-\(i)")
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent get() during shutdown should not crash or deadlock")
  }

  // MARK: - Concurrent addSpanProcessor while creating spans

  func testConcurrentAddSpanProcessor() {
    nonisolated(unsafe) let provider = TracerProviderSdk()
    let threads = 50
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.provider.addProcessor", attributes: .concurrent)

    for i in 0..<threads {
      group.enter()
      queue.async {
        if i % 2 == 0 {
          provider.addSpanProcessor(NoopSpanProcessor())
        } else {
          let tracer = provider.get(instrumentationName: "tracer-\(i)")
          let span = tracer.spanBuilder(spanName: "span-\(i)").startSpan()
          span.end()
        }
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent processor addition and span creation should not crash")
  }
}

// MARK: - Thread-safe collection wrappers

private final class LockedArray<T>: @unchecked Sendable {
  private let lock = NSLock()
  private var _values = [T]()

  var values: [T] {
    lock.lock()
    defer { lock.unlock() }
    return _values
  }

  func append(_ value: T) {
    lock.lock()
    _values.append(value)
    lock.unlock()
  }
}

private final class LockedDictionary<Key: Hashable, Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var _values = [Key: Value]()

  var values: [Key: Value] {
    lock.lock()
    defer { lock.unlock() }
    return _values
  }

  func set(key: Key, value: Value) {
    lock.lock()
    _values[key] = value
    lock.unlock()
  }
}

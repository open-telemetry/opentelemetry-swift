/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

final class ComponentRegistryConcurrencyTests: XCTestCase {

  // MARK: - Concurrent get with same key builds exactly once

  func testConcurrentGetSameKey() {
    let buildCount = AtomicCounter()
    nonisolated(unsafe) let registry = ComponentRegistry<String> { scope in
      buildCount.increment()
      return "component-\(scope.name)"
    }

    let threads = 100
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.registry.sameKey", attributes: .concurrent)
    let results = LockedArray<String>()

    for _ in 0..<threads {
      group.enter()
      queue.async {
        let component = registry.get(name: "shared")
        results.append(component)
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent get() should complete without deadlock")
    XCTAssertEqual(buildCount.value, 1, "Builder should be called exactly once for the same key")
    XCTAssertTrue(results.values.allSatisfy { $0 == "component-shared" })
  }

  // MARK: - Concurrent get with different keys

  func testConcurrentGetDifferentKeys() {
    let buildCount = AtomicCounter()
    nonisolated(unsafe) let registry = ComponentRegistry<String> { scope in
      buildCount.increment()
      return "component-\(scope.name)"
    }

    let threads = 100
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.registry.diffKeys", attributes: .concurrent)

    for i in 0..<threads {
      group.enter()
      queue.async {
        _ = registry.get(name: "key-\(i)")
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent get() with different keys should complete")
    XCTAssertEqual(buildCount.value, threads, "Each unique key should trigger one build")
    XCTAssertEqual(registry.getComponents().count, threads)
  }

  // MARK: - Concurrent get with version and schema combinations

  func testConcurrentGetWithVersionAndSchema() {
    nonisolated(unsafe) let registry = ComponentRegistry<String> { scope in
      return "\(scope.name)-\(scope.version ?? "nil")-\(scope.schemaUrl ?? "nil")"
    }

    let threads = 100
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.registry.versionSchema", attributes: .concurrent)

    for i in 0..<threads {
      group.enter()
      queue.async {
        switch i % 4 {
        case 0:
          _ = registry.get(name: "comp", version: "1.0", schemaUrl: "https://schema/v1")
        case 1:
          _ = registry.get(name: "comp", version: "1.0")
        case 2:
          _ = registry.get(name: "comp", version: nil, schemaUrl: "https://schema/v1")
        default:
          _ = registry.get(name: "comp")
        }
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Mixed version/schema lookups should not crash")
    XCTAssertEqual(registry.getComponents().count, 4,
                   "Four distinct combinations should produce four components")
  }

  // MARK: - getComponents returns consistent snapshot while registering

  func testGetComponentsWhileRegistering() {
    nonisolated(unsafe) let registry = ComponentRegistry<String> { scope in
      return scope.name
    }

    let writers = 50
    let readers = 50
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.registry.snapshot", attributes: .concurrent)

    for i in 0..<writers {
      group.enter()
      queue.async {
        _ = registry.get(name: "component-\(i)")
        group.leave()
      }
    }

    for _ in 0..<readers {
      group.enter()
      queue.async {
        let components = registry.getComponents()
        XCTAssertTrue(components.count <= writers,
                      "Snapshot should never contain more components than registered")
        group.leave()
      }
    }

    waitForConcurrentWork(group, "concurrent work should complete")
    XCTAssertEqual(registry.getComponents().count, writers)
  }
}

// MARK: - Thread-safe helpers

private final class AtomicCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var _value = 0

  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return _value
  }

  func increment() {
    lock.lock()
    _value += 1
    lock.unlock()
  }
}

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

//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import XCTest

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(Musl)
  import Musl
#endif

/// Gate and helpers for concurrency stress tests.
///
/// Stress tests hammer a shared object from many threads at once. On their own
/// they rarely fail deterministically, so they are only worth running under
/// Thread Sanitizer, which reports unsynchronized access even when the
/// interleaving happened to be benign. They are enabled when either:
///
/// - the process was built with `--sanitize=thread` (detected at runtime), or
/// - the `OTEL_CONCURRENCY_TESTS` environment variable is set to a truthy value.
///
/// Set `OTEL_CONCURRENCY_TESTS=0` to force them off even under TSan.
public enum ConcurrencyTesting {
  /// Environment variable that forces the stress tests on (`1`) or off (`0`).
  public static let environmentVariable = "OTEL_CONCURRENCY_TESTS"

  /// Whether the Thread Sanitizer runtime is linked into this process.
  public static let isThreadSanitizerActive: Bool = {
    guard let handle = dlopen(nil, RTLD_NOW) else { return false }
    return dlsym(handle, "__tsan_init") != nil
  }()

  /// Whether stress tests should run in this process.
  public static let isEnabled: Bool = {
    if let raw = ProcessInfo.processInfo.environment[environmentVariable]?
      .trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
      !raw.isEmpty {
      return !["0", "false", "no", "off"].contains(raw)
    }
    return isThreadSanitizerActive
  }()

  /// Throws `XCTSkip` unless stress tests are enabled. Call at the top of
  /// each stress test, or from `setUpWithError()`.
  public static func skipUnlessEnabled() throws {
    guard isEnabled else {
      throw XCTSkip(
        "Concurrency stress tests only run under Thread Sanitizer "
          + "(swift test --sanitize=thread) or with \(environmentVariable)=1"
      )
    }
  }

  /// Default number of worker threads for `stress`.
  public static let defaultThreads = 8

  /// Default number of iterations per worker for `stress`. Kept modest because
  /// TSan slows execution down considerably.
  public static let defaultIterations = 200

  /// Runs `body` on `threads` dedicated OS threads, `iterations` times each,
  /// and blocks until all of them finish.
  ///
  /// Every worker waits on a shared start gate so they contend from the very
  /// first iteration instead of trickling in as threads spin up. Dedicated
  /// `Thread`s are used rather than `DispatchQueue.concurrentPerform` so the
  /// worker count does not depend on the size of the GCD pool on the CI host.
  public static func stress(threads: Int = defaultThreads,
                            iterations: Int = defaultIterations,
                            timeout: TimeInterval = 60,
                            file: StaticString = #filePath,
                            line: UInt = #line,
                            _ body: @escaping @Sendable (_ thread: Int, _ iteration: Int) -> Void) {
    precondition(threads > 0 && iterations > 0)

    let startGate = DispatchSemaphore(value: 0)
    let done = DispatchGroup()

    for threadIndex in 0 ..< threads {
      done.enter()
      let worker = Thread {
        startGate.wait()
        for iteration in 0 ..< iterations {
          body(threadIndex, iteration)
        }
        done.leave()
      }
      worker.name = "ConcurrencyTesting.stress.\(threadIndex)"
      worker.start()
    }

    for _ in 0 ..< threads {
      startGate.signal()
    }

    if done.wait(timeout: .now() + timeout) == .timedOut {
      XCTFail("Stress workers did not finish within \(timeout)s", file: file, line: line)
    }
  }

  /// Runs each operation once, on its own thread, all released together, and
  /// blocks until every one has finished. Use this to mix distinct operations
  /// against the same object, e.g. `export` racing `shutdown`.
  public static func concurrently(timeout: TimeInterval = 60,
                                  file: StaticString = #filePath,
                                  line: UInt = #line,
                                  _ operations: [@Sendable () -> Void]) {
    guard !operations.isEmpty else { return }

    let startGate = DispatchSemaphore(value: 0)
    let done = DispatchGroup()

    for (index, operation) in operations.enumerated() {
      done.enter()
      let worker = Thread {
        startGate.wait()
        operation()
        done.leave()
      }
      worker.name = "ConcurrencyTesting.concurrently.\(index)"
      worker.start()
    }

    for _ in operations {
      startGate.signal()
    }

    if done.wait(timeout: .now() + timeout) == .timedOut {
      XCTFail("Concurrent operations did not finish within \(timeout)s", file: file, line: line)
    }
  }

  /// Async variant of `stress` for APIs that are `async`. Runs `tasks`
  /// concurrent child tasks, each performing `iterations` calls to `body`.
  public static func stress(tasks: Int = defaultThreads,
                            iterations: Int = defaultIterations,
                            _ body: @escaping @Sendable (_ task: Int, _ iteration: Int) async -> Void) async {
    precondition(tasks > 0 && iterations > 0)

    await withTaskGroup(of: Void.self) { group in
      for taskIndex in 0 ..< tasks {
        group.addTask {
          for iteration in 0 ..< iterations {
            await body(taskIndex, iteration)
          }
        }
      }
    }
  }
}

// MARK: - Helpers for stress bodies

/// Wraps a value so it can be captured by a `@Sendable` stress closure.
///
/// Use it only for objects that are documented as safe to share across
/// threads but are not annotated `Sendable`, or for objects whose thread
/// safety is exactly what the test is probing. It does no synchronization.
public struct UncheckedSendable<Value>: @unchecked Sendable {
  public let value: Value

  public init(_ value: Value) {
    self.value = value
  }
}

/// A lock-guarded append-only bag for collecting results from stress workers
/// so assertions can run on the test thread afterwards.
public final class ConcurrentCollector<Element>: @unchecked Sendable {
  private let lock = NSLock()
  private var elements: [Element] = []

  public init() {}

  public func append(_ element: Element) {
    lock.lock()
    elements.append(element)
    lock.unlock()
  }

  public var values: [Element] {
    lock.lock()
    defer { lock.unlock() }
    return elements
  }

  public var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return elements.count
  }
}

/// A lock-guarded counter for stress workers.
public final class ConcurrentCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  public init() {}

  public func increment(by amount: Int = 1) {
    lock.lock()
    count += amount
    lock.unlock()
  }

  public var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }
}

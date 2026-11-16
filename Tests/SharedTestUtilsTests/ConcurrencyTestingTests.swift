//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import SharedTestUtils
import XCTest

final class ConcurrencyTestingTests: XCTestCase {
  func testGateMatchesEnvironmentOrSanitizer() {
    let env = ProcessInfo.processInfo.environment[ConcurrencyTesting.environmentVariable]
    if let env, !env.isEmpty {
      let forcedOff = ["0", "false", "no", "off"].contains(env.lowercased())
      XCTAssertEqual(ConcurrencyTesting.isEnabled, !forcedOff)
    } else {
      XCTAssertEqual(ConcurrencyTesting.isEnabled, ConcurrencyTesting.isThreadSanitizerActive)
    }
  }

  func testStressRunsEveryIterationOnEveryThread() {
    let lock = NSLock()
    nonisolated(unsafe) var seen = Set<String>()

    ConcurrencyTesting.stress(threads: 4, iterations: 25) { thread, iteration in
      lock.lock()
      seen.insert("\(thread)-\(iteration)")
      lock.unlock()
    }

    XCTAssertEqual(seen.count, 4 * 25)
  }

  func testConcurrentlyRunsEachOperationOnce() {
    let lock = NSLock()
    nonisolated(unsafe) var order: [Int] = []

    ConcurrencyTesting.concurrently([
      { lock.lock(); order.append(1); lock.unlock() },
      { lock.lock(); order.append(2); lock.unlock() },
      { lock.lock(); order.append(3); lock.unlock() }
    ])

    XCTAssertEqual(order.sorted(), [1, 2, 3])
  }

  func testAsyncStressRunsEveryIteration() async {
    actor Counter {
      var value = 0
      func bump() { value += 1 }
    }
    let counter = Counter()

    await ConcurrencyTesting.stress(tasks: 4, iterations: 25) { _, _ in
      await counter.bump()
    }

    let value = await counter.value
    XCTAssertEqual(value, 100)
  }

  func testSkipUnlessEnabledSkipsWhenDisabled() throws {
    if ConcurrencyTesting.isEnabled {
      XCTAssertNoThrow(try ConcurrencyTesting.skipUnlessEnabled())
    } else {
      XCTAssertThrowsError(try ConcurrencyTesting.skipUnlessEnabled()) { error in
        XCTAssertTrue(error is XCTSkip)
      }
    }
  }
}

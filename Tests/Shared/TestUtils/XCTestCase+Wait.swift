//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import XCTest

extension XCTestCase {
  public func wait(timeout: TimeInterval = 3, interval: TimeInterval = 0.1, until block: @escaping () throws -> Bool) {
    let expectation = expectation(description: "wait for block to pass")
    let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
      do {
        if try block() {
          expectation.fulfill()
        }
      } catch {
        fatalError("Waiting for operation that threw an error: \(error)")
      }
    }
    
    wait(for: [expectation], timeout: timeout)
    timer.invalidate()
  }
}

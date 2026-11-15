/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// The crashes the demo can trigger, from the Settings tab or with `--crashType <rawValue>` in
/// integration test mode. They cover the main kinds of crash report: Swift runtime traps, an
/// uncaught NSException and a bad memory access.
enum CrashType: String, CaseIterable {
  case forceUnwrap = "force-unwrap"
  case indexOutOfBounds = "index-out-of-bounds"
  case fatalError = "fatal-error"
  case divideByZero = "divide-by-zero"
  case stackOverflow = "stack-overflow"
  case nsException = "ns-exception"
  case badAccess = "bad-access"

  var displayName: String {
    switch self {
    case .indexOutOfBounds: return "Index Out of Bounds"
    case .fatalError: return "Fatal Error"
    case .forceUnwrap: return "Force Unwrap Nil"
    case .divideByZero: return "Divide by Zero"
    case .stackOverflow: return "Stack Overflow"
    case .nsException: return "Uncaught NSException"
    case .badAccess: return "Bad Memory Access"
    }
  }

  func trigger() -> Never {
    switch self {
    case .indexOutOfBounds:
      let array = [1, 2, 3]
      _ = array[Int.random(in: 10 ... 10)]
    case .fatalError:
      Swift.fatalError("Intentional crash for testing")
    case .forceUnwrap:
      let nilValue: String? = nil
      _ = nilValue!
    case .divideByZero:
      let zero = Int.random(in: 0 ... 0) // Runtime zero
      _ = 42 / zero
    case .stackOverflow:
      func recursiveFunction(_ depth: Int) -> Int {
        recursiveFunction(depth + 1) + 1 // Infinite recursion
      }
      _ = recursiveFunction(0)
    case .nsException:
      _ = NSArray(array: [1, 2, 3]).object(at: Int.random(in: 10 ... 10))
    case .badAccess:
      let pointer = UnsafeMutablePointer<Int>(bitPattern: Int.random(in: 8 ... 8))!
      pointer.pointee = 42
    }
    Swift.fatalError("\(rawValue) did not crash")
  }
}

/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

/// Utility protocol adding `Equatable` conformance to any arbitrary type.
/// The equatabiliity is determined based on comparing type mirrors and values.
protocol EquatableInTests: Equatable {}

extension EquatableInTests {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    return equals(lhs: lhs, rhs: rhs)
  }
}

private func equals<T>(lhs: T, rhs: T) -> Bool {
  return equalsAny(lhs: lhs, rhs: rhs)
}

private func equalsAny(lhs: Any, rhs: Any) -> Bool {
  let lhsMirror = Mirror(reflecting: lhs)
  let rhsMirror = Mirror(reflecting: rhs)

  if lhsMirror.displayStyle != rhsMirror.displayStyle {
    return false // different types
  }

  if lhsMirror.children.count != rhsMirror.children.count {
    return false // different number of children
  }

  if lhsMirror.children.isEmpty, rhsMirror.children.isEmpty {
    return String(describing: lhs) == String(describing: rhs) // plain values, compare debug strings
  }

  switch (lhsMirror.displayStyle, rhsMirror.displayStyle) {
  case (.dictionary?, .dictionary?): // two dictionaries
    print("Two dictionaries: \(lhs) vs \(rhs)")
    let lhsDictionary = lhs as! [String: Any]
    let rhsDictionary = rhs as! [String: Any]

    if lhsDictionary.keys.count != rhsDictionary.keys.count {
      return false // difference on number of keys
    }

    for (lhsKey, lhsValue) in lhsDictionary {
      if let rhsValue = rhsDictionary[lhsKey] {
        if !equalsAny(lhs: lhsValue, rhs: rhsValue) {
          return false // difference on key values
        }
      } else {
        return false // difference on key names
      }
    }

    return true // dictionaries are equal
  case (.set?, .set?): // two sets
    let lhsSet = lhs as! Set<AnyHashable>
    let rhsSet = rhs as! Set<AnyHashable>

    let setsEqual = lhsSet == rhsSet // if sets are equal
    return setsEqual
  default:
    break // other than dictionary or set, continue...
  }

  let lhsChildren = lhsMirror.children.map(\.value)
  let rhsChildren = rhsMirror.children.map(\.value)

  for (lhsChild, rhsChild) in zip(lhsChildren, rhsChildren) { // compare each child
    if !equalsAny(lhs: lhsChild, rhs: rhsChild) {
      return false // childs are different
    }
  }

  return true
}

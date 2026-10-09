//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

extension Dictionary.Keys where Key == String, Value == AttributeValue {
  public func contains(_ element: any RawRepresentable<String>) -> Bool {
    self.contains(element.rawValue)
  }
}

extension Dictionary where Key == String, Value == AttributeValue {
  subscript(key: any RawRepresentable<String> ) -> Value? {
    get {
      return self[key.rawValue]
    }
    set(newValue) {
      if let x = newValue {
        self[key.rawValue] = x
      }
    }
  }
}



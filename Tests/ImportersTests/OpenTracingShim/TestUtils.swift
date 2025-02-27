/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import Opentracing

enum TestUtils {
  static func contextBaggageToDictionary(context: OTSpanContext) -> [String: String] {
    var dictionary = [String: String]()
    context.forEachBaggageItem { key, value -> Bool in
      dictionary[key] = value
      return true
    }
    return dictionary
  }
}

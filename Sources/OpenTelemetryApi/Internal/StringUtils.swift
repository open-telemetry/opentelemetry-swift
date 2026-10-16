/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Internal utility methods for working with attribute keys, attribute values, and metric names
public enum StringUtils {
  /// Determines whether the String contains only printable characters.
  /// - Parameter string: the String to be validated.
  public static func isPrintableString(_ string: String) -> Bool {
    for char in string.unicodeScalars where !isPrintableChar(char) {
      return false
    }
    return true
  }

  private static func isPrintableChar(_ char: Unicode.Scalar) -> Bool {
    return char >= UnicodeScalar(" ") && char <= UnicodeScalar("~")
  }

  /// Determines whether the metric name contains a valid metric name.
  /// - Parameter string: the String to be validated.
  public static func isValidMetricName(_ metricName: String) -> Bool {
    if metricName.range(of: "[aA-zZ][aA-zZ0-9_\\-.]*", options: .regularExpression, range: nil,
                        locale: nil) != nil {
      return true
    }
    return false
  }
}

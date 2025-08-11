/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct PrometheusMetric {
  let contentType = "text/plain; version = 0.0.4"

  static let firstCharacterNameCharset = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_:")
  static let nameCharset = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_:")
  static let firstCharacterLabelCharset = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_")
  static let labelCharset = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")

  var values = [PrometheusValue]()
  var name: String
  var description: String
  var type: String = ""

  func write(timeStamp: String) -> String {
    var output = ""

    let name = PrometheusMetric.getSafeMetricName(name: name)

    if !description.isEmpty {
      output += "# HELP "
      output += name
      output += PrometheusMetric.getSafeMetricDescription(description: description)
      output += "\n"
    }

    if !type.isEmpty {
      output += "# TYPE "
      output += name
      output += " "
      output += type
      output += "\n"
    }

    values.forEach { value in
      output += value.name != nil ? PrometheusMetric.getSafeMetricName(name: value.name!) : name

      if value.labels.count > 0 {
        output += "{"
        output += value.labels.map { "\(PrometheusMetric.getSafeLabelName(name: $0))=\"\(PrometheusMetric.getSafeLabelValue(value: $1))\"" }.joined(separator: ",")
        output += "}"
      }

      output += " "
      output += String(value.value)
      output += " "

      output += timeStamp
      output += "\n"
    }

    return output
  }

  private static func getSafeMetricName(name: String) -> String {
    return getSafeName(name: name, firstCharNameCharset: firstCharacterNameCharset, charNameCharset: nameCharset)
  }

  private static func getSafeLabelName(name: String) -> String {
    return getSafeName(name: name, firstCharNameCharset: firstCharacterLabelCharset, charNameCharset: labelCharset)
  }

  private static func getSafeName(name: String, firstCharNameCharset: CharacterSet, charNameCharset: CharacterSet) -> String {
    var output = name.replaceCharactersFromSet(characterSet: charNameCharset.inverted, replacementString: "_")

    if let first = output.unicodeScalars.first,
       !firstCharNameCharset.contains(first) {
      output = "_" + output.dropFirst()
    }
    return output
  }

  private static func getSafeLabelValue(value: String) -> String {
    var result = value.replacingOccurrences(of: "\\", with: "\\\\")
    result = result.replacingOccurrences(of: "\n", with: "\\n")
    result = result.replacingOccurrences(of: "\"", with: "\\\"")
    return result
  }

  private static func getSafeMetricDescription(description: String) -> String {
    var result = description.replacingOccurrences(of: "\\", with: "\\\\")
    result = result.replacingOccurrences(of: "\n", with: "\\n")
    return result
  }
}

struct PrometheusValue {
  var name: String?
  var labels = [String: String]()
  var value: Double
}

extension String {
  func replaceCharactersFromSet(characterSet: CharacterSet, replacementString: String = "") -> String {
    return components(separatedBy: characterSet).joined(separator: replacementString)
  }
}

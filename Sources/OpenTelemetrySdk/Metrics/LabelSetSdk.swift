/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// LabelSet implementation.
class LabelSetSdk: LabelSet {
  var labelSetEncoded: String

  required init(labels: [String: String]) {
    labelSetEncoded = LabelSetSdk.getLabelSetEncoded(labels: labels)
    super.init(labels: labels)
  }

  private static func getLabelSetEncoded(labels: [String: String]) -> String {
    var output = ""
    var isFirstLabel = true

    labels.map { "\($0)=\($1)" }.sorted().forEach {
      if !isFirstLabel {
        output += ","
      }
      output += $0
      isFirstLabel = false
    }
    return output
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi

public extension Session {
  /// Attribution and the saved decision for this snapshot, including delayed log records.
  var samplingAttributes: [String: AttributeValue] {
    var attributes: [String: AttributeValue] = [
      SemanticConventions.Session.id.rawValue: .string(id),
      SessionConstants.sessionSamplingDecision: .string(samplingDecision.rawValue)
    ]
    if let previousId {
      attributes[SemanticConventions.Session.previousId.rawValue] = .string(previousId)
    }
    return attributes
  }

  /// Records a measurement only when this session was sampled.
  /// Use the supplied attributes on the measurement, before metric aggregation. This does not
  /// filter instruments that are recorded elsewhere or retrofit an existing meter provider.
  @discardableResult
  func recordIfSampled(_ record: ([String: AttributeValue]) throws -> Void) rethrows -> Bool {
    guard samplingDecision.isSampled else { return false }
    try record(samplingAttributes)
    return true
  }
}

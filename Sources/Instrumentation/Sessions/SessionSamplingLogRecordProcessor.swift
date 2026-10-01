/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// Adds session attribution and filters logs before handing them to the next processor.
/// Historical records should carry `Session.samplingAttributes`. Records with an unknown
/// historical decision are preserved; they are never sampled using the current session.
public final class SessionSamplingLogRecordProcessor: LogRecordProcessor {
  private let sessionManager: SessionManager
  private let nextProcessor: LogRecordProcessor

  public init(nextProcessor: LogRecordProcessor, sessionManager: SessionManager) {
    self.nextProcessor = nextProcessor
    self.sessionManager = sessionManager
  }

  public func onEmit(logRecord: ReadableLogRecord) {
    let idKey = SemanticConventions.Session.id.rawValue
    let decisionKey = SessionConstants.sessionSamplingDecision
    if logRecord.attributes[idKey] != nil {
      if case let .string(rawDecision) = logRecord.attributes[decisionKey],
         let decision = SessionSamplingDecision(rawValue: rawDecision) {
        if decision.isSampled {
          nextProcessor.onEmit(logRecord: logRecord)
        }
      } else {
        nextProcessor.onEmit(logRecord: logRecord)
      }
      return
    }

    guard let session = sessionManager.sessionForSignalAttribution(), session.samplingDecision.isSampled else { return }
    var record = logRecord
    record.setAttribute(key: SemanticConventions.Session.previousId.rawValue, value: nil)
    for (key, value) in session.samplingAttributes {
      record.setAttribute(key: key, value: value)
    }
    nextProcessor.onEmit(logRecord: record)
  }

  public func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return nextProcessor.shutdown(explicitTimeout: explicitTimeout)
  }

  public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return nextProcessor.forceFlush(explicitTimeout: explicitTimeout)
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk
import OpenTelemetryApi

/// OpenTelemetry log record processor that adds session attributes to all log records
public class SessionLogRecordProcessor: LogRecordProcessor {
  /// Reference to the session manager for retrieving current session
  private var sessionManager: SessionManager
  /// The next processor in the chain
  private var nextProcessor: LogRecordProcessor

  /// Initializes the log record processor with a session manager
  public init(nextProcessor: LogRecordProcessor, sessionManager: SessionManager? = nil) {
    self.nextProcessor = nextProcessor
    self.sessionManager = sessionManager ?? SessionManagerProvider.getInstance()
  }

  /// Called when a log record is emitted - adds session attributes and forwards to next processor
  public func onEmit(logRecord: ReadableLogRecord) {
    if logRecord.eventName == SessionConstants.sessionStartEvent ||
      logRecord.eventName == SessionConstants.sessionEndEvent,
      logRecord.attributes[SemanticConventions.Session.id.rawValue] != nil {
      // Lifecycle events already carry the historical session context they describe.
      nextProcessor.onEmit(logRecord: logRecord)
      return
    }

    var enhancedRecord = logRecord

    // A record that already carries session.id was stamped by its producer
    // (e.g. a session.start/session.end event for a session that is no longer
    // current), so its session attributes are left untouched: filling in
    // session.previous_id from the current session would attach the wrong
    // session's predecessor.
    if logRecord.attributes[SemanticConventions.Session.id.rawValue] == nil {
      let session = sessionManager.getSession()
      enhancedRecord.setAttribute(key: SemanticConventions.Session.id.rawValue, value: session.id)

      if let previousId = session.previousId {
        enhancedRecord.setAttribute(key: SemanticConventions.Session.previousId.rawValue, value: previousId)
      }
    }

    nextProcessor.onEmit(logRecord: enhancedRecord)
  }

  /// Shuts down the processor by delegating to the next processor in the chain
  public func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return nextProcessor.shutdown(explicitTimeout: explicitTimeout)
  }

  /// Forces a flush of any pending data by delegating to the next processor in the chain
  public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return nextProcessor.forceFlush(explicitTimeout: explicitTimeout)
  }
}

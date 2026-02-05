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
    var enhancedRecord = logRecord

    // Only add session attributes if they don't already exist
    if logRecord.attributes[SemanticConventions.Session.id.rawValue] == nil || logRecord.attributes[SemanticConventions.Session.previousId.rawValue] == nil {
      let session = sessionManager.getSession()

      // Add session.id if not already present
      if logRecord.attributes[SemanticConventions.Session.id.rawValue] == nil {
        enhancedRecord.setAttribute(key: SemanticConventions.Session.id.rawValue, value: session.id)
      }

      // Add session.previous_id if not already present and session has a previous ID
      if logRecord.attributes[SemanticConventions.Session.previousId.rawValue] == nil, let previousId = session.previousId {
        enhancedRecord.setAttribute(key: SemanticConventions.Session.previousId.rawValue, value: previousId)
      }
    }

    nextProcessor.onEmit(logRecord: enhancedRecord)
  }

  /// Shuts down the processor - no cleanup needed
  public func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  /// Forces a flush of any pending data - no action needed
  public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}

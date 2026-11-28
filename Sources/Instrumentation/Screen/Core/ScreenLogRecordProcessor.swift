/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// Adds `app.screen.name` to every log record, then forwards it.
///
/// Wrap the processor that exports, the way `SessionLogRecordProcessor` is wrapped, so the
/// attribute is attached before batching. A record that already carries `app.screen.name` is
/// left alone: a crash report replayed from the previous run names the screen that crashed, not
/// the one visible now.
public class ScreenLogRecordProcessor: LogRecordProcessor {
  private let injectedTracker: ScreenTracker?
  private let nextProcessor: LogRecordProcessor

  private var screenTracker: ScreenTracker {
    injectedTracker ?? ScreenTrackerProvider.getInstance()
  }

  /// - Parameters:
  ///   - nextProcessor: The processor to forward to.
  ///   - screenTracker: The tracker to read. Defaults to the shared one, read at each emit.
  public init(nextProcessor: LogRecordProcessor, screenTracker: ScreenTracker? = nil) {
    self.nextProcessor = nextProcessor
    injectedTracker = screenTracker
  }

  public func onEmit(logRecord: ReadableLogRecord) {
    let key = SemanticConventions.App.screenName.rawValue
    guard let screen = screenTracker.currentScreen,
          logRecord.attributes[key] == nil else {
      nextProcessor.onEmit(logRecord: logRecord)
      return
    }

    var enhancedRecord = logRecord
    enhancedRecord.setAttribute(key: key, value: screen)
    nextProcessor.onEmit(logRecord: enhancedRecord)
  }

  public func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    nextProcessor.shutdown(explicitTimeout: explicitTimeout)
  }

  public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    nextProcessor.forceFlush(explicitTimeout: explicitTimeout)
  }
}

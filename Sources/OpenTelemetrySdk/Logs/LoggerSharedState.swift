//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

class LoggerSharedState {
  var resource: Resource
  var logLimits: LogLimits
  var activeLogRecordProcessor: LogRecordProcessor
  var clock: Clock
  var hasBeenShutdown = false
  var registeredLogRecordProcessors = [LogRecordProcessor]()

  init(resource: Resource, logLimits: LogLimits, processors: [LogRecordProcessor], clock: Clock) {
    self.resource = resource
    self.logLimits = logLimits
    self.clock = clock
    if processors.count > 1 {
      activeLogRecordProcessor = MultiLogRecordProcessor(logRecordProcessors: processors)
      registeredLogRecordProcessors = processors
    } else if processors.count == 1 {
      activeLogRecordProcessor = processors[0]
      registeredLogRecordProcessors = processors
    } else {
      activeLogRecordProcessor = NoopLogRecordProcessor()
    }
  }

  func addLogRecordProcessor(_ logRecordProcessor: LogRecordProcessor) {
    registeredLogRecordProcessors.append(logRecordProcessor)
    if registeredLogRecordProcessors.count > 1 {
      activeLogRecordProcessor = MultiLogRecordProcessor(logRecordProcessors: registeredLogRecordProcessors)
    } else {
      activeLogRecordProcessor = registeredLogRecordProcessors[0]
    }
  }

  func stop() {
    if hasBeenShutdown {
      return
    }
    _ = activeLogRecordProcessor.shutdown()
    hasBeenShutdown = true
  }

  func setLogLimits(limits: LogLimits) {
    logLimits = limits
  }
}

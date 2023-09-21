//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

class LoggerSharedState {
  var resource : Resource
  var logLimits : LogLimits
  var activeLogRecordProcessor : LogRecordProcessor
  var clock : Clock
  var hasBeenShutdown = false
  var registeredLogRecordProcessors = [LogRecordProcessor]()
  
  init(resource: Resource, logLimits: LogLimits, processors: [LogRecordProcessor], clock: Clock) {
    self.resource = resource
    self.logLimits = logLimits
    self.clock = clock
    if processors.count > 1 {
      self.activeLogRecordProcessor = MultiLogRecordProcessor(logRecordProcessors: processors)
      self.registeredLogRecordProcessors = processors
    } else if processors.count == 1 {
      self.activeLogRecordProcessor = processors[0]
      self.registeredLogRecordProcessors = processors
    } else {
      self.activeLogRecordProcessor = NoopLogRecordProcessor()
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
    self.logLimits = limits
  }
}

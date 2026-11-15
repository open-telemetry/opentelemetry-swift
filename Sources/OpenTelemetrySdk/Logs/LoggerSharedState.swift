//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

/// Represents the shared state/config between all Loggers created by the same LoggerProvider.
///
/// All mutable state is protected by a read-write lock: configuration is written rarely
/// (setup, registration) but read on every emitted log record, so concurrent readers must
/// never observe a partially applied update such as a mid-replacement
/// `activeLogRecordProcessor`.
class LoggerSharedState: @unchecked Sendable {
  private let lock = ReadWriteLock()

  private var _resource: Resource
  private var _logLimits: LogLimits
  private var _activeLogRecordProcessor: LogRecordProcessor
  private var _clock: Clock
  private var _hasBeenShutdown = false
  private var _registeredLogRecordProcessors = [LogRecordProcessor]()

  var resource: Resource {
    get { lock.withReaderLock { _resource } }
    set { lock.withWriterLock { _resource = newValue } }
  }

  var logLimits: LogLimits {
    lock.withReaderLock { _logLimits }
  }

  var activeLogRecordProcessor: LogRecordProcessor {
    lock.withReaderLock { _activeLogRecordProcessor }
  }

  var clock: Clock {
    get { lock.withReaderLock { _clock } }
    set { lock.withWriterLock { _clock = newValue } }
  }

  var hasBeenShutdown: Bool {
    lock.withReaderLock { _hasBeenShutdown }
  }

  var registeredLogRecordProcessors: [LogRecordProcessor] {
    lock.withReaderLock { _registeredLogRecordProcessors }
  }

  init(resource: Resource, logLimits: LogLimits, processors: [LogRecordProcessor], clock: Clock) {
    _resource = resource
    _logLimits = logLimits
    _clock = clock
    if processors.count > 1 {
      _activeLogRecordProcessor = MultiLogRecordProcessor(logRecordProcessors: processors)
      _registeredLogRecordProcessors = processors
    } else if processors.count == 1 {
      _activeLogRecordProcessor = processors[0]
      _registeredLogRecordProcessors = processors
    } else {
      _activeLogRecordProcessor = NoopLogRecordProcessor()
    }
  }

  func addLogRecordProcessor(_ logRecordProcessor: LogRecordProcessor) {
    lock.withWriterLock {
      _registeredLogRecordProcessors.append(logRecordProcessor)
      if _registeredLogRecordProcessors.count > 1 {
        _activeLogRecordProcessor = MultiLogRecordProcessor(logRecordProcessors: _registeredLogRecordProcessors)
      } else {
        _activeLogRecordProcessor = _registeredLogRecordProcessors[0]
      }
    }
  }

  func stop() {
    // Claim shutdown under the lock, but call the processor outside it:
    // shutdown() can block on export and must not stall readers.
    let processor: LogRecordProcessor? = lock.withWriterLock {
      if _hasBeenShutdown {
        return nil
      }
      _hasBeenShutdown = true
      return _activeLogRecordProcessor
    }
    _ = processor?.shutdown()
  }

  func setLogLimits(limits: LogLimits) {
    lock.withWriterLock { _logLimits = limits }
  }
}

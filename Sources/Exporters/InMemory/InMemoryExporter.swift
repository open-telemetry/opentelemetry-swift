/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

public final class InMemoryExporter: SpanExporter, @unchecked Sendable {
  private let lock = NSLock()
  private var finishedSpanItems: [SpanData] = []
  private var isRunning: Bool = true

  public init() {}

  public func getFinishedSpanItems() -> [SpanData] {
    return lock.withLock { finishedSpanItems }
  }

  public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
    return lock.withLock {
      guard isRunning else {
        return .failure
      }
      finishedSpanItems.append(contentsOf: spans)
      return .success
    }
  }

  public func flush(explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
    return lock.withLock {
      guard isRunning else {
        return .failure
      }
      return .success
    }
  }

  public func reset() {
    lock.withLock { finishedSpanItems.removeAll() }
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) {
    lock.withLock {
      finishedSpanItems.removeAll()
      isRunning = false
    }
  }
}

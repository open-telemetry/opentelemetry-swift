/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public class SpanContextShimTable {
  private let lock = ReadWriteLock()
  private var shimsMap = [SpanContext: SpanContextShim]()

  public func setBaggageItem(spanShim: SpanShim, key: String, value: String) {
    lock.withWriterLockVoid {
      var contextShim = shimsMap[spanShim.span.context]
      if contextShim == nil {
        contextShim = SpanContextShim(spanShim: spanShim)
      }

      contextShim = contextShim?.newWith(key: key, value: value)
      shimsMap[spanShim.span.context] = contextShim
    }
  }

  public func getBaggageItem(spanShim: SpanShim, key: String) -> String? {
    lock.withReaderLock {
      let contextShim = shimsMap[spanShim.span.context]
      return contextShim?.getBaggageItem(key: key)
    }
  }

  public func get(spanShim: SpanShim) -> SpanContextShim? {
    lock.withReaderLock {
      shimsMap[spanShim.span.context]
    }
  }

  public func create(spanShim: SpanShim) -> SpanContextShim {
    return create(spanShim: spanShim, distContext: spanShim.telemetryInfo.emptyBaggage)
  }

  @discardableResult public func create(spanShim: SpanShim, distContext: Baggage?) -> SpanContextShim {
    lock.withWriterLock {
      var contextShim = shimsMap[spanShim.span.context]
      if contextShim != nil {
        return contextShim!
      }

      contextShim = SpanContextShim(telemetryInfo: spanShim.telemetryInfo, context: spanShim.span.context, baggage: distContext)
      shimsMap[spanShim.span.context] = contextShim
      return contextShim!
    }
  }
}

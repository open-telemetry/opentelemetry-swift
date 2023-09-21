/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// Implementation of the SpanProcessor that simply forwards all received events to a list of
/// SpanProcessors.
public struct MultiSpanProcessor: SpanProcessor {
  var spanProcessorsStart = [SpanProcessor]()
  var spanProcessorsEnd = [SpanProcessor]()
  var spanProcessorsAll = [SpanProcessor]()
  
  public init(spanProcessors: [SpanProcessor]) {
    spanProcessorsAll = spanProcessors
    spanProcessorsAll.forEach {
      if $0.isStartRequired {
        spanProcessorsStart.append($0)
      }
      if $0.isEndRequired {
        spanProcessorsEnd.append($0)
      }
    }
  }
  
  public var isStartRequired: Bool {
    return spanProcessorsStart.count > 0
  }
  
  public var isEndRequired: Bool {
    return spanProcessorsEnd.count > 0
  }
  
  public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    spanProcessorsStart.forEach {
      $0.onStart(parentContext: parentContext, span: span)
    }
  }
  
  public func onEnd(span: ReadableSpan) {
    for var processor in spanProcessorsEnd {
      processor.onEnd(span: span)
    }
  }
  
  public func shutdown(explicitTimeout:TimeInterval? = nil) {
    for var processor in spanProcessorsAll {
      processor.shutdown(explicitTimeout: explicitTimeout)
    }
  }
  
  public func forceFlush(timeout: TimeInterval? = nil) {
    spanProcessorsAll.forEach {
      $0.forceFlush(timeout: timeout)
    }
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk
import OpenTelemetryApi

class SpanProcessorMock: SpanProcessor {
  var onStartCalledTimes = 0
  lazy var onStartCalled: Bool = self.onStartCalledTimes > 0
  var onStartCalledSpan: ReadableSpan?
  var onEndCalledTimes = 0
  lazy var onEndCalled: Bool = self.onEndCalledTimes > 0
  var onEndCalledSpan: ReadableSpan?
  var shutdownCalledTimes = 0
  lazy var shutdownCalled: Bool = self.shutdownCalledTimes > 0
  var forceFlushCalledTimes = 0
  lazy var forceFlushCalled: Bool = self.forceFlushCalledTimes > 0

  var isStartRequired = true
  var isEndRequired = true

  func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    onStartCalledTimes += 1
    onStartCalledSpan = span
  }

  func onEnd(span: ReadableSpan) {
    onEndCalledTimes += 1
    onEndCalledSpan = span
  }

  func shutdown(explicitTimeout: TimeInterval?) {
    shutdownCalledTimes += 1
  }

  func forceFlush(timeout: TimeInterval? = nil) {
    forceFlushCalledTimes += 1
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LogRecordBuilder {
  /// set the timestamp on which the event occurred
  ///
  /// - Parameter timestamp: the Date object
  /// - Returns: self
  func setTimestamp(_ timestamp: Date) -> Self

  /// set the timestamp that the log was observed
  ///
  /// - Parameter observed: the Date object
  /// - Returns: self
  func setObservedTimestamp(_ observed: Date) -> Self

  /// set the span context associated with the log.
  ///
  /// - Parameter context: the associated span context
  /// - Returns: self
  func setSpanContext(_ context: SpanContext) -> Self

  /// set the severity of the log.
  ///
  /// - Parameter severity: the severity level
  /// - Returns: self
  func setSeverity(_ severity: Severity) -> Self

  /// set the body string.
  ///
  /// - Parameter body: string value of the log
  /// - Returns: self
  func setBody(_ body: AttributeValue) -> Self

  /// set attributes associated with the log.
  ///
  /// - Parameter attributes: Array of [String: AttributeValue]
  /// - Returns:
  func setAttributes(_ attributes: [String: AttributeValue]) -> Self

  /// set the event name for the log record.
  ///
  /// - Parameter eventName: the name of the event
  /// - Returns: self
  func setEventName(_ eventName: String) -> Self

  /// emits the log record.
  func emit()
}

public extension LogRecordBuilder {
  func setTimestamp(_ timestamp: Date) -> Self {
    return self
  }

  func setObservedTimestamp(_ observed: Date) -> Self {
    return self
  }

  func setSpanContext(_ context: SpanContext) -> Self {
    return self
  }

  func setSeverity(_ severity: Severity) -> Self {
    return self
  }

  func setBody(_ body: AttributeValue) -> Self {
    return self
  }

  func setAttributes(_ attributes: [String: AttributeValue]) -> Self {
    return self
  }

  func setEventName(_ eventName: String) -> Self {
    return self
  }

  func emit() {}
}

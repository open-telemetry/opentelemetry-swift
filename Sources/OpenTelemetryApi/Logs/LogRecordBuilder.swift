/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LogRecordBuilder {
    /// set the timestamp on which the event ocurred
    ///
    /// - Parameter timestamp: the Date object
    /// - Returns: self
    func setTimestamp(_ timestamp: Date) -> Self

    /// set the timestamp that the log was observed
    ///
    /// - Parameter observed: the Date object
    /// - Returns: self
    func setObservedTimestamp (_ observed: Date) -> Self

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

    /// set attributes assoicated with the log.
    ///
    /// - Parameter attributes: Array of [String: AttributeValue]
    /// - Returns:
    func setAttributes(_ attributes: [String: AttributeValue]) -> Self

    /// emits the log record.
    func emit()
}



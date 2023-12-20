/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class DefaultLogger: Logger {

  private static let instanceWithDomain = DefaultLogger(true)
  private static let instanceNoDomain = DefaultLogger(false)
  private static let noopLogRecordBuilder = NoopLogRecordBuilder()

  private var hasDomain: Bool

  private init(_ hasDomain: Bool) {
    self.hasDomain = hasDomain
  }

  static func getInstance(_ hasDomain: Bool) -> Logger {
    if hasDomain {
      return Self.instanceWithDomain
    } else {
      return Self.instanceNoDomain
    }
  }

  public func eventBuilder(name: String) -> EventBuilder {
    if !hasDomain {
      /// log error
    }
    return Self.noopLogRecordBuilder
  }

  public func logRecordBuilder() -> LogRecordBuilder {
    return Self.noopLogRecordBuilder
  }

  private class NoopLogRecordBuilder: EventBuilder {
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

    func setData(_ attributes: [String: AttributeValue]) -> Self {
      return self
    }

    func emit() {

    }

  }

}

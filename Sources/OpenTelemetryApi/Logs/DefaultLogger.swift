/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public final class DefaultLogger: Logger, Sendable {
  private static let instanceWithDomain = DefaultLogger(true)
  private static let instanceNoDomain = DefaultLogger(false)
  private static let noopLogRecordBuilder = NoopLogRecordBuilder()

  private let hasDomain: Bool

  private init(_ hasDomain: Bool) {
    self.hasDomain = hasDomain
  }

  static func getInstance(_ hasDomain: Bool) -> Logger {
    if hasDomain {
      return instanceWithDomain
    } else {
      return instanceNoDomain
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

  private final class NoopLogRecordBuilder: EventBuilder, Sendable {}
}

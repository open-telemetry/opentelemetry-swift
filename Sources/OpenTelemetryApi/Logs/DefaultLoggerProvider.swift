/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class DefaultLoggerProvider: LoggerProvider {
  public static let instance: LoggerProvider = DefaultLoggerProvider()
  fileprivate static let noopBuilderWithDomain = NoopLoggerBuilder(true)
  fileprivate static let noopBuilderNoDomain = NoopLoggerBuilder(false)

  public func get(instrumentationScopeName: String) -> Logger {
    return loggerBuilder(instrumentationScopeName: instrumentationScopeName).build()
  }

  public func loggerBuilder(instrumentationScopeName: String) -> LoggerBuilder {
    return Self.noopBuilderNoDomain
  }
}

private class NoopLoggerBuilder: LoggerBuilder {
  private let hasDomain: Bool

  fileprivate init(_ hasDomain: Bool) {
    self.hasDomain = hasDomain
  }

  // swiftlint:disable force_cast
  public func setEventDomain(_ eventDomain: String) -> Self {
    if eventDomain.isEmpty {
      return DefaultLoggerProvider.noopBuilderNoDomain as! Self
    }
    return DefaultLoggerProvider.noopBuilderWithDomain as! Self
  }

  // swiftlint:enable force_cast

  public func setSchemaUrl(_ schemaUrl: String) -> Self {
    return self
  }

  public func setInstrumentationVersion(_ instrumentationVersion: String) -> Self {
    return self
  }

  public func setIncludeTraceContext(_ includeTraceContext: Bool) -> Self {
    return self
  }

  public func setAttributes(_ attributes: [String: AttributeValue]) -> Self {
    return self
  }

  public func build() -> Logger {
    return DefaultLogger.getInstance(hasDomain)
  }
}

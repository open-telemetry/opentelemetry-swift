//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class LoggerBuilderSdk: LoggerBuilder {
  private var registry: ComponentRegistry<LoggerSdk>
  private var instrumentationScopeName: String
  private var eventDomain: String?
  private var schemaUrl: String?
  private var instrumentationScopeVersion: String?
  private var includeTraceContext = true

  init(registry: ComponentRegistry<LoggerSdk>, instrumentationScopeName: String) {
    self.registry = registry
    self.instrumentationScopeName = instrumentationScopeName
  }

  public func setEventDomain(_ eventDomain: String) -> Self {
    self.eventDomain = eventDomain
    return self
  }

  public func setSchemaUrl(_ schemaUrl: String) -> Self {
    self.schemaUrl = schemaUrl
    return self
  }

  public func setInstrumentationVersion(_ instrumentationVersion: String) -> Self {
    self.instrumentationScopeVersion = instrumentationVersion
    return self
  }

  public func setIncludeTraceContext(_ includeTraceContext: Bool) -> Self {
    self.includeTraceContext = includeTraceContext
    return self
  }

  public func setAttributes(_ attributes: [String: OpenTelemetryApi.AttributeValue]) -> Self {
    return self
  }

  public func build() -> OpenTelemetryApi.Logger {
    var logger = registry.get(name: instrumentationScopeName, version: instrumentationScopeVersion, schemaUrl: schemaUrl)
    if let eventDomain = eventDomain {
      logger = logger.withEventDomain(domain: eventDomain)
    }

    if !includeTraceContext {
      logger = logger.withoutTraceContext()
    }

    return logger
  }
}

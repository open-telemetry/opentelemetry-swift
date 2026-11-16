//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public final class LoggerProviderSdk: LoggerProvider, @unchecked Sendable {
  private let sharedState: LoggerSharedState
  private let loggerRegistry: ComponentRegistry<LoggerSdk>
  public init(clock: Clock = MillisClock(),
              resource: Resource = EnvVarResource.get(),
              logLimits: LogLimits = LogLimits(),
              logRecordProcessors: [LogRecordProcessor] = []) {
    sharedState = LoggerSharedState(resource: resource,
                                    logLimits: logLimits,
                                    processors: logRecordProcessors,
                                    clock: clock)

    loggerRegistry = ComponentRegistry<LoggerSdk> { [sharedState] scope in
      return LoggerSdk(sharedState: sharedState, instrumentationScope: scope, eventDomain: nil)
    }
  }

  public func get(instrumentationScopeName: String) -> OpenTelemetryApi.Logger {
    return loggerRegistry.get(name: instrumentationScopeName, version: nil, schemaUrl: nil)
  }

  public func loggerBuilder(instrumentationScopeName: String) -> OpenTelemetryApi.LoggerBuilder {
    return LoggerBuilderSdk(registry: loggerRegistry, instrumentationScopeName: instrumentationScopeName)
  }
}

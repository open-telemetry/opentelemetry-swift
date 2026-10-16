/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

open class Instrumentation {
  private let scope: String
  
  public init(scope: String) {
    self.scope = scope
  }
  
  public var logger: Logger {
    OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: scope)
  }
  
  public var tracer: Tracer {
    OpenTelemetry.instance.tracerProvider.get(instrumentationName: scope)
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class LoggingTracerProvider: TracerProvider {
  func get(instrumentationName: String, instrumentationVersion: String?) -> Tracer {
    Logger.log("TracerFactory.get(\(instrumentationName), \(instrumentationVersion ?? ""))")
    var labels = [String: String]()
    labels["instrumentationName"] = instrumentationName
    labels["instrumentationVersion"] = instrumentationVersion
    return LoggingTracer()
  }
}

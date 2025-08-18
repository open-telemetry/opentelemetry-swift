/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class LoggingTracerProvider: TracerProvider {
  func get(instrumentationName: String, instrumentationVersion: String?,
           schemaUrl: String? = nil,
           attributes: [String: AttributeValue]? = nil) -> any Tracer {
    Logger
      .log(
        "TracerFactory.get(\(instrumentationName), \(instrumentationVersion ?? ""), \(schemaUrl ?? ""), \(attributes ?? [:])"
      )
    var labels = [String: String]()
    labels["instrumentationName"] = instrumentationName
    labels["instrumentationVersion"] = instrumentationVersion
    labels["schemaUrl"] = schemaUrl
    labels["attributes"] = attributes?.description
    return LoggingTracer()
  }
}

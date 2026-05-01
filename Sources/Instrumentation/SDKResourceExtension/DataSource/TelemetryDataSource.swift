/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public class TelemetryDataSource: ITelemetryDataSource {
  public init() {}
  public var language: String {
    SemanticConventions.Telemetry.SdkLanguageValues.swift.description
  }

  public var name: String {
    "opentelemetry"
  }

  public var version: String? {
    Resource.OTEL_SWIFT_SDK_VERSION
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

protocol BaseShimProtocol {
  var telemetryInfo: TelemetryInfo { get }
}

extension BaseShimProtocol {
  var tracer: Tracer {
    return telemetryInfo.tracer
  }

  var spanContextTable: SpanContextShimTable {
    return telemetryInfo.spanContextTable
  }

  var baggageManager: BaggageManager {
    return telemetryInfo.baggageManager
  }

  var propagators: ContextPropagators {
    return telemetryInfo.propagators
  }
}

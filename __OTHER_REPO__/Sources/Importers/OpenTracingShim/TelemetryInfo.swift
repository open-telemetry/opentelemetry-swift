/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

struct TelemetryInfo {
  var tracer: Tracer
  var baggageManager: BaggageManager
  var propagators: ContextPropagators
  var emptyBaggage: Baggage?
  var spanContextTable: SpanContextShimTable

  init(tracer: Tracer, baggageManager: BaggageManager, propagators: ContextPropagators) {
    self.tracer = tracer
    self.baggageManager = baggageManager
    self.propagators = propagators
    emptyBaggage = baggageManager.baggageBuilder().build()
    spanContextTable = SpanContextShimTable()
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/**
 * Implementation of a EnvironmentContextPropagation propagation, using W3CTraceContextPropagator
 */

public struct EnvironmentContextPropagator: TextMapPropagator {
  static let traceParent = "TRACEPARENT"
  static let traceState = "TRACESTATE"
  let w3cPropagator = W3CTraceContextPropagator()

  public let fields: Set<String> = [traceState, traceParent]

  public init() {}

  public func inject(spanContext: SpanContext, carrier: inout [String: String], setter: some Setter) {
    var auxCarrier = [String: String]()
    w3cPropagator.inject(spanContext: spanContext, carrier: &auxCarrier, setter: setter)
    carrier[EnvironmentContextPropagator.traceParent] = auxCarrier["traceparent"]
    carrier[EnvironmentContextPropagator.traceState] = auxCarrier["tracestate"]
  }

  public func extract(carrier: [String: String], getter: some Getter) -> SpanContext? {
    var auxCarrier = [String: String]()
    auxCarrier["traceparent"] = carrier[EnvironmentContextPropagator.traceParent]
    auxCarrier["tracestate"] = carrier[EnvironmentContextPropagator.traceState]
    return w3cPropagator.extract(carrier: auxCarrier, getter: getter)
  }
}

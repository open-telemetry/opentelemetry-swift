// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import OpenTelemetryApi

/**
 * Implementation of a EnvironmentContextPropagation propagation, using W3CTraceContextPropagator
 */

public struct EnvironmentContextPropagator: TextMapPropagator {
    static let traceParent = "OTEL_TRACE_PARENT"
    static let traceState = "OTEL_TRACE_STATE"
    let w3cPropagator = W3CTraceContextPropagator()

    public let fields: Set<String> = [traceState, traceParent]

    public init() {}

    public func inject<S>(spanContext: SpanContext, carrier: inout [String: String], setter: S) where S: Setter {
        var auxCarrier = [String: String]()
        w3cPropagator.inject(spanContext: spanContext, carrier: &auxCarrier, setter: setter)
        carrier[EnvironmentContextPropagator.traceParent] = auxCarrier["traceparent"]
        carrier[EnvironmentContextPropagator.traceState] = auxCarrier["tracestate"]
    }

    public func extract<G>(carrier: [String: String], getter: G) -> SpanContext? where G: Getter {
        var auxCarrier = [String: String]()
        auxCarrier["traceparent"] = carrier[EnvironmentContextPropagator.traceParent]
        auxCarrier["tracestate"] = carrier[EnvironmentContextPropagator.traceState]
        return w3cPropagator.extract(carrier: auxCarrier, getter: getter)
    }
}

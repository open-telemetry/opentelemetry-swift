/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// TracerSdk is SDK implementation of Tracer.
public class TracerSdk: Tracer {
    public let textFormat: TextMapPropagator = W3CTraceContextPropagator()
    public let instrumentationLibraryInfo: InstrumentationLibraryInfo
    var sharedState: TracerSharedState

    init(sharedState: TracerSharedState, instrumentationLibraryInfo: InstrumentationLibraryInfo) {
        self.sharedState = sharedState
        self.instrumentationLibraryInfo = instrumentationLibraryInfo
    }

    public func spanBuilder(spanName: String) -> SpanBuilder {
        if sharedState.hasBeenShutdown {
            return DefaultTracer.instance.spanBuilder(spanName: spanName)
        }
        return SpanBuilderSdk(spanName: spanName,
                              instrumentationLibraryInfo: instrumentationLibraryInfo,
                              tracerSharedState: sharedState,
                              spanLimits: sharedState.activeSpanLimits)
    }
}

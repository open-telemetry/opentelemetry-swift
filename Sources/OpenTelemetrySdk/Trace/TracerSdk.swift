/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// TracerSdk is SDK implementation of Tracer.
public class TracerSdk: Tracer {
    public let textFormat: TextMapPropagator
    public let instrumentationLibraryInfo: InstrumentationLibraryInfo
    var sharedState: TracerSharedState

    init(sharedState: TracerSharedState, instrumentationLibraryInfo: InstrumentationLibraryInfo, textFormat: TextMapPropagator) {
        self.sharedState = sharedState
        self.instrumentationLibraryInfo = instrumentationLibraryInfo
        self.textFormat = textFormat ?? W3CTraceContextPropagator()
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

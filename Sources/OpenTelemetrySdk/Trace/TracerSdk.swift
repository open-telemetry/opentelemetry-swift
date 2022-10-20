/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// TracerSdk is SDK implementation of Tracer.
public class TracerSdk: Tracer {
    public let instrumentationScopeInfo: InstrumentationScopeInfo
    var sharedState: TracerSharedState

    init(sharedState: TracerSharedState, instrumentationScopeInfo: InstrumentationScopeInfo) {
        self.sharedState = sharedState
        self.instrumentationScopeInfo = instrumentationScopeInfo
    }

    public func spanBuilder(spanName: String) -> SpanBuilder {
        if sharedState.hasBeenShutdown {
            return DefaultTracer.instance.spanBuilder(spanName: spanName)
        }
        return SpanBuilderSdk(spanName: spanName,
                              instrumentationScopeInfo: instrumentationScopeInfo,
                              tracerSharedState: sharedState,
                              spanLimits: sharedState.activeSpanLimits)
    }
}

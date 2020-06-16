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
import OpenTelemetrySdk
import Opentracing

public class TraceShim {
    public static var instance = TraceShim()

    public private(set) var otTracer: OTTracer

    private init() {
        otTracer = TraceShim.createTracerShim()
    }

    static func createTracerShim() -> OTTracer {
        return TracerShim(telemetryInfo: TelemetryInfo(tracer: TraceShim.getTracer(tracerProvider: OpenTelemetrySDK.instance.tracerProvider),
                                                       contextManager: OpenTelemetrySDK.instance.contextManager,
                                                       propagators: OpenTelemetrySDK.instance.propagators))
    }

    static func createTracerShim(tracerProvider: TracerProvider, contextManager: CorrelationContextManager) -> OTTracer {
        return TracerShim(telemetryInfo: TelemetryInfo(tracer: TraceShim.getTracer(tracerProvider: tracerProvider),
                                                       contextManager: contextManager,
                                                       propagators: OpenTelemetrySDK.instance.propagators))
    }

    private static func getTracer(tracerProvider: TracerProvider) -> Tracer {
        tracerProvider.get(instrumentationName: "opentracingshim", instrumentationVersion: nil)
    }
}

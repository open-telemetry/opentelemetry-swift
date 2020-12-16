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

/// This class provides a static global accessor for telemetry objects Tracer, Meter
///  and CorrelationContextManager.
///  The telemetry objects are lazy-loaded singletons resolved via ServiceLoader mechanism.
public struct OpenTelemetry {
    public static var instance = OpenTelemetry()

    /// Registered tracerProvider or default via DefaultTracerProvider.instance.
    public private(set) var tracerProvider: TracerProvider

    /// Registered MeterProvider or default via DefaultMeterProvider.instance.
    public private(set) var meterProvider: MeterProvider

    /// registered manager or default via  DefaultCorrelationContextManager.instance.
    public private(set) var contextManager: CorrelationContextManager

    /// registered manager or default via  DefaultCorrelationContextManager.instance.
    public private(set) var propagators: ContextPropagators = DefaultContextPropagators(textPropagators: [W3CTraceContextPropagator()])

    private init() {
        tracerProvider = DefaultTracerProvider.instance
        meterProvider = DefaultMeterProvider.instance
        contextManager = DefaultCorrelationContextManager.instance
    }

    public static func registerTracerProvider(tracerProvider: TracerProvider) {
        instance.tracerProvider = tracerProvider
    }

    public static func registerMeterProvider(meterProvider: MeterProvider) {
        instance.meterProvider = meterProvider
    }

    public static func registerCorrelationContextManager(correlationContextManager: CorrelationContextManager) {
        instance.contextManager = correlationContextManager
    }
}

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

    /// Registered TracerFactory or default via DefaultTracerFactory.instance.
    public private(set) var tracerRegistry: TracerRegistry

//    /// Registered MeterFactory or default via DefaultMeterFactory.instance.
//    public private(set)  var meter: MeterRegistry

    /// registered manager or default via  DefaultCorrelationContextManager.instance.
    public private(set) var contextManager: CorrelationContextManager

    private init() {
        tracerRegistry = DefaultTracerRegistry.instance
//        meter = DefaultMeterFactory.instance;
        contextManager = DefaultCorrelationContextManager.instance
    }

    public static func registerTracerRegistry(tracerRegistry: TracerRegistry) {
        instance.tracerRegistry = tracerRegistry
    }

    public static func registerCorrelationContextManager(correlationContextManager: CorrelationContextManager) {
        instance.contextManager = correlationContextManager
    }
}

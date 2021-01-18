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

/// This class provides a static global accessor for SDK telemetry objects TracerSdkProvider,
/// MeterSdkFactory BaggageManagerSdk.
/// This is a convenience class getting and casting the telemetry objects from OpenTelemetry.
public struct OpenTelemetrySDK {
    public static var instance = OpenTelemetrySDK()

    public var tracerProvider: TracerSdkProvider {
        return OpenTelemetry.instance.tracerProvider as! TracerSdkProvider
    }

    public var meterProvider: MeterSdkProvider {
        return OpenTelemetry.instance.meterProvider as! MeterSdkProvider
    }

    public var baggageManager: DefaultBaggageManager {
        return OpenTelemetry.instance.baggageManager as! DefaultBaggageManager
    }

    public var propagators: ContextPropagators {
        return OpenTelemetry.instance.propagators
    }

    private init() {
        OpenTelemetry.registerTracerProvider(tracerProvider: TracerSdkProvider())
        OpenTelemetry.registerMeterProvider(meterProvider: MeterSdkProvider())
        OpenTelemetry.registerBaggageManager(baggageManager: DefaultBaggageManager.instance)
    }
}

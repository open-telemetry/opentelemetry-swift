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

/// This class provides a static global accessor for SDK telemetry objects TracerProviderSdk,
/// MeterSdkFactory BaggageManagerSdk.
/// This is a convenience class getting and casting the telemetry objects from OpenTelemetry.
public struct OpenTelemetrySDK {
    static var version = "0.6.0"
    public static var instance = OpenTelemetrySDK()

    public var tracerProvider: TracerProviderSdk {
        return OpenTelemetry.instance.tracerProvider as! TracerProviderSdk
    }

    public var meterProvider: MeterProviderSdk {
        return OpenTelemetry.instance.meterProvider as! MeterProviderSdk
    }

    public var baggageManager: DefaultBaggageManager {
        return OpenTelemetry.instance.baggageManager as! DefaultBaggageManager
    }

    public var propagators: ContextPropagators {
        return OpenTelemetry.instance.propagators
    }

    private init() {
        OpenTelemetry.registerTracerProvider(tracerProvider: TracerProviderSdk())
        OpenTelemetry.registerMeterProvider(meterProvider: MeterProviderSdk())
        OpenTelemetry.registerBaggageManager(baggageManager: DefaultBaggageManager.instance)
    }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

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

    public var contextProvider: OpenTelemetryContextProvider {
        return OpenTelemetry.instance.contextProvider
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

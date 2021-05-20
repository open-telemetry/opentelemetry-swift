/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class DefaultMeterProvider: MeterProvider {
    public static var instance: MeterProvider = DefaultMeterProvider()

    static var proxyMeter = ProxyMeter()
    static var initialized = false

    init() {}

    public static func setDefault(meterFactory: MeterProvider) {
        guard !initialized else {
            return
        }
        instance = meterFactory
        proxyMeter.updateMeter(realMeter: meterFactory.get(instrumentationName: "", instrumentationVersion: nil))
        initialized = true
    }

    public func get(instrumentationName: String, instrumentationVersion: String? = nil) -> Meter {
        return DefaultMeterProvider.initialized ? DefaultMeterProvider.instance.get(instrumentationName: instrumentationName, instrumentationVersion: instrumentationVersion) : DefaultMeterProvider.proxyMeter
    }

    internal static func reset() {
        DefaultMeterProvider.instance = DefaultMeterProvider()
        DefaultMeterProvider.proxyMeter = ProxyMeter()
        DefaultMeterProvider.initialized = false
    }
}

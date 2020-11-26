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

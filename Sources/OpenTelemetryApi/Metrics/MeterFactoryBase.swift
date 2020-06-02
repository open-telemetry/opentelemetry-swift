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

open class MeterFactoryBase {
    static var defaultFactory = MeterFactoryBase()
    static var proxyMeter = ProxyMeter()
    static var initialized = false

    public init() {}

    static func setDefault(meterFactory: MeterFactoryBase) {
        guard !initialized else {
            return
        }
        defaultFactory = meterFactory
        proxyMeter.updateMeter(realMeter: meterFactory.getMeter(name: ""))
        initialized = true
    }

    open func getMeter(name: String, version: String? = nil) -> Meter {
        return MeterFactoryBase.initialized ? MeterFactoryBase.defaultFactory.getMeter(name: name, version: version) : MeterFactoryBase.proxyMeter
    }

    internal func reset() {
        MeterFactoryBase.defaultFactory = MeterFactoryBase()
        MeterFactoryBase.proxyMeter = ProxyMeter()
        MeterFactoryBase.initialized = false
    }
}

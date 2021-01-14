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

public class Propagation: BaseShimProtocol {
    var telemetryInfo: TelemetryInfo

    init(telemetryInfo: TelemetryInfo) {
        self.telemetryInfo = telemetryInfo
    }

    public func injectTextFormat(contextShim: SpanContextShim, carrier: NSMutableDictionary) {
        var newEntries = [String: String]()
        propagators.textMapPropagator.inject(spanContext: contextShim.context, carrier: &newEntries, setter: TextMapSetter())
        carrier.addEntries(from: newEntries)
    }

    public func extractTextFormat(carrier: [String: String]) -> SpanContextShim? {
        guard let currentBaggage = ContextUtils.getCurrentBaggage() else { return nil }
        let context = propagators.textMapPropagator.extract(carrier: carrier, getter: TextMapGetter())
        if !(context?.isValid ?? false) {
            return nil
        }
        return SpanContextShim(telemetryInfo: telemetryInfo, context: context!, baggage: currentBaggage)
    }
}

struct TextMapSetter: Setter {
    func set(carrier: inout [String: String], key: String, value: String) {
        carrier[key] = value
    }
}

struct TextMapGetter: Getter {
    func get(carrier: [String: String], key: String) -> [String]? {
        if let value = carrier[key] {
            return [value]
        }
        return nil
    }
}

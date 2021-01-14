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
import Opentracing

public class SpanContextShim: OTSpanContext, BaseShimProtocol {
    var telemetryInfo: TelemetryInfo
    public private(set) var context: SpanContext
    public private(set) var baggage: Baggage

    init(telemetryInfo: TelemetryInfo, context: SpanContext, baggage: Baggage) {
        self.telemetryInfo = telemetryInfo
        self.context = context
        self.baggage = baggage
    }

    convenience init(spanShim: SpanShim) {
        self.init(telemetryInfo: spanShim.telemetryInfo, context: spanShim.span.context, baggage: spanShim.telemetryInfo.emptyBaggage)
    }

    convenience init(telemetryInfo: TelemetryInfo, context: SpanContext) {
        self.init(telemetryInfo: telemetryInfo, context: context, baggage: telemetryInfo.emptyBaggage)
    }

    func newWith(key: String, value: String) -> SpanContextShim {
        let baggageBuilder = baggageManager.baggageBuilder().setParent(baggage)
        baggageBuilder.put(key: EntryKey(name: key)!, value: EntryValue(string: value)!, metadata: nil)

        return SpanContextShim(telemetryInfo: telemetryInfo, context: context, baggage: baggageBuilder.build())
    }

    func getBaggageItem(key: String) -> String? {
        guard let key = EntryKey(name: key) else { return nil }
        let value = baggage.getEntryValue(key: key)
        return value?.string
    }

    public func forEachBaggageItem(_ callback: @escaping (String, String) -> Bool) {
        let entries = baggage.getEntries()
        entries.forEach {
            if !callback($0.key.name, $0.value.string) {
                return
            }
        }
    }
}

extension SpanContextShim: Equatable {
    public static func == (lhs: SpanContextShim, rhs: SpanContextShim) -> Bool {
        return lhs.context == rhs.context && lhs.baggage == rhs.baggage
    }
}

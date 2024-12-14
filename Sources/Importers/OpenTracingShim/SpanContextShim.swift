/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import Opentracing

public class SpanContextShim: OTSpanContext, BaseShimProtocol {
    var telemetryInfo: TelemetryInfo
    public private(set) var context: SpanContext
    public private(set) var baggage: Baggage?

    init(telemetryInfo: TelemetryInfo, context: SpanContext, baggage: Baggage?) {
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
        let baggageBuilder = baggageManager.baggageBuilder()
        baggageBuilder.setParent(baggage)
        baggageBuilder.put(key: EntryKey(name: key)!, value: EntryValue(string: value)!, metadata: nil)

        return SpanContextShim(telemetryInfo: telemetryInfo, context: context, baggage: baggageBuilder.build())
    }

    func getBaggageItem(key: String) -> String? {
        guard let key = EntryKey(name: key) else { return nil }
        let value = baggage?.getEntryValue(key: key)
        return value?.string
    }

    public func forEachBaggageItem(_ callback: @escaping (String, String) -> Bool) {
        let entries = baggage?.getEntries()
        entries?.forEach {
            if !callback($0.key.name, $0.value.string) {
                return
            }
        }
    }
}

extension SpanContextShim: Equatable {
    public static func == (lhs: SpanContextShim, rhs: SpanContextShim) -> Bool {
        if let lbaggage = lhs.baggage, let rbaggage = rhs.baggage {
            return lbaggage == rbaggage && lhs.context == rhs.context
        } else {
            return lhs.baggage == nil && rhs.baggage == nil && lhs.context == rhs.context
        }
    }
}

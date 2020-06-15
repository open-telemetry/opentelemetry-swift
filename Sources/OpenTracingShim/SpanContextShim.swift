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
    static let defaultEntryMetadata = EntryMetadata(entryTtl: .unlimitedPropagation)

    var telemetryInfo: TelemetryInfo
    public private(set) var context: SpanContext
    public private(set) var correlationContext: CorrelationContext

    init(telemetryInfo: TelemetryInfo, context: SpanContext, correlationContext: CorrelationContext) {
        self.telemetryInfo = telemetryInfo
        self.context = context
        self.correlationContext = correlationContext
    }

    convenience init(spanShim: SpanShim) {
        self.init(telemetryInfo: spanShim.telemetryInfo, context: spanShim.span.context, correlationContext: spanShim.telemetryInfo.emptyCorrelationContext)
    }

    convenience init(telemetryInfo: TelemetryInfo, context: SpanContext) {
        self.init(telemetryInfo: telemetryInfo, context: context, correlationContext: telemetryInfo.emptyCorrelationContext)
    }

    func newWith(key: String, value: String) -> SpanContextShim {
        let contextBuilder = contextManager.contextBuilder().setParent(correlationContext)
        contextBuilder.put(key: EntryKey(name: key)!, value: EntryValue(string: value)!, metadata: SpanContextShim.defaultEntryMetadata)

        return SpanContextShim(telemetryInfo: telemetryInfo, context: context, correlationContext: contextBuilder.build())
    }

    func getBaggageItem(key: String) -> String? {
        guard let key = EntryKey(name: key) else { return nil }
        let value = correlationContext.getEntryValue(key: key)
        return value?.string
    }

    public func forEachBaggageItem(_ callback: @escaping (String, String) -> Bool) {
    }
}

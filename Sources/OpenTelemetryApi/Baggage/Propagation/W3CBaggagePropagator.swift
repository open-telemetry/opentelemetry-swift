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

public struct W3CBaggagePropagator: TextMapBaggagePropagator {
    private static let version = "00"
    private static let delimiter: Character = "-"
    private static let versionLength = 2
    private static let delimiterLength = 1
    private static let versionPrefixIdLength = versionLength + delimiterLength
    private static let traceIdLength = 2 * TraceId.size
    private static let versionAndTraceIdLength = versionLength + delimiterLength + traceIdLength + delimiterLength
    private static let spanIdLength = 2 * SpanId.size
    private static let versionAndTraceIdAndSpanIdLength = versionAndTraceIdLength + spanIdLength + delimiterLength
    private static let optionsLength = 2
    private static let traceparentLengthV0 = versionAndTraceIdAndSpanIdLength + optionsLength

    static let headerBaggage = "baggage"

    public init() {}

    public let fields: Set<String> = [headerBaggage]

    public func inject<S>(baggage: Baggage, carrier: inout [String: String], setter: S) where S: Setter {
        var headerContent = ""
        baggage.getEntries().forEach {
            headerContent += $0.key.name + "=" + $0.value.string
            if let metadata = $0.metadata {
                headerContent += ";" + metadata.metadata
            }
            headerContent += ","
        }
        if !headerContent.isEmpty {
            headerContent.removeLast()
        }

        if !headerContent.isEmpty {
            setter.set(carrier: &carrier, key: W3CBaggagePropagator.headerBaggage, value: headerContent)
        }
    }

    public func extract<G>(carrier: [String: String], getter: G) -> Baggage? where G: Getter {
        guard let baggageHeaderCollection = getter.get(carrier: carrier,
                                                       key: W3CBaggagePropagator.headerBaggage),
            let baggageHeader = baggageHeaderCollection.first else {
            return nil
        }
        let builder = OpenTelemetry.instance.baggageManager.baggageBuilder()

        baggageHeader.split(separator: ",").forEach {
            var entry = ""
            var metadata = ""
            if let separator = $0.firstIndex(of: ";") {
                entry = String($0.prefix(upTo: separator))
                metadata = String($0.suffix(from: separator).dropFirst())
            } else {
                entry = String($0)
            }

            let keyValue = entry.split(separator: "=")
            if keyValue.count != 2 {
                return
            }
            if let key = EntryKey(name: String(keyValue[0])),
                let value = EntryValue(string: String(keyValue[1])) {
                builder.put(key: key, value: value, metadata: EntryMetadata(metadata: metadata))
            }
        }

        return builder.build()
    }
}

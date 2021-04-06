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

/**
 * Implementation of the Jaeger propagation protocol. See
 * https://www.jaegertracing.io/docs/client-libraries/#propagation-format
 */

public class JaegerBaggagePropagator: TextMapBaggagePropagator {
    public static let baggageHeader = "jaeger-baggage"
    public static let baggagePrefix = "uberctx-"

    public var fields: Set<String> = [baggageHeader]

    public init() {}

    public func inject<S>(baggage: Baggage, carrier: inout [String: String], setter: S) where S: Setter {
        baggage.getEntries().forEach {
            setter.set(carrier: &carrier, key: JaegerBaggagePropagator.baggagePrefix + $0.key.name, value: $0.value.string)
        }
    }

    public func extract<G>(carrier: [String: String], getter: G) -> Baggage? where G: Getter {
        let builder = OpenTelemetry.instance.baggageManager.baggageBuilder()

        carrier.forEach {
            if $0.key.hasPrefix(JaegerBaggagePropagator.baggagePrefix) {
                if $0.key.count == JaegerBaggagePropagator.baggagePrefix.count {
                    return
                }

                if let key = EntryKey(name: String($0.key.dropFirst(JaegerBaggagePropagator.baggagePrefix.count))),
                   let value = EntryValue(string: $0.value)
                {
                    builder.put(key: key, value: value, metadata: nil)
                }
            } else if $0.key == JaegerBaggagePropagator.baggageHeader {
                $0.value.split(separator: ",").forEach { entry in
                    let keyValue = entry.split(separator: "=")
                    if keyValue.count != 2 {
                        return
                    }
                    if let key = EntryKey(name: String(keyValue[0])),
                       let value = EntryValue(string: String(keyValue[1]))
                    {
                        builder.put(key: key, value: value, metadata: nil)
                    }
                }
            }
        }

        return builder.build()
    }
}

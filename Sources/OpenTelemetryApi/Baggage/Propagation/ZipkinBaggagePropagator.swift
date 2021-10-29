/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 * Implementation of the Zipkin propagation protocol and by default it uses `baggage-` prefix. See
 * https://github.com/openzipkin/brave/blob/master/brave/README.md#remote-baggage
 */

public class ZipkinBaggagePropagator: TextMapBaggagePropagator {
    public static let baggagePrefix = "baggage-"

    public let fields: Set<String> = []

    public init() {}

    public func inject<S>(baggage: Baggage, carrier: inout [String: String], setter: S) where S: Setter {
        baggage.getEntries().forEach {
            setter.set(carrier: &carrier, key: ZipkinBaggagePropagator.baggagePrefix + $0.key.name, value: $0.value.string)
        }
    }

    public func extract<G>(carrier: [String: String], getter: G) -> Baggage? where G: Getter {
        let builder = OpenTelemetry.instance.baggageManager.baggageBuilder()

        carrier.forEach {
            if $0.key.hasPrefix(ZipkinBaggagePropagator.baggagePrefix) {
                if $0.key.count == ZipkinBaggagePropagator.baggagePrefix.count {
                    return
                }

                if let key = EntryKey(name: String($0.key.dropFirst(ZipkinBaggagePropagator.baggagePrefix.count))),
                   let value = EntryValue(string: $0.value)
                {
                    builder.put(key: key, value: value, metadata: nil)
                }
            }
        }

        return builder.build()
    }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 * Implementation of the Jaeger propagation protocol. See
 * https://www.jaegertracing.io/docs/client-libraries/#propagation-format
 *
 * The Jaeger format defines no limits on baggage; the W3C Baggage limits are applied to the keys and values on extraction and injection.
 */

public class JaegerBaggagePropagator: TextMapBaggagePropagator {
  public static let baggageHeader = "jaeger-baggage"
  public static let baggagePrefix = "uberctx-"

  public var fields: Set<String> = [baggageHeader]

  public init() {}

  public func inject(baggage: Baggage, carrier: inout [String: String], setter: some Setter) {
    var limits = BaggagePropagationLimits()

    // Sorted so that the entries kept at capacity are the same on every peer and every run.
    baggage.getEntries().sorted().forEach {
      guard limits.accept(key: $0.key, value: $0.value) else {
        return
      }

      setter.set(carrier: &carrier, key: JaegerBaggagePropagator.baggagePrefix + $0.key.name, value: $0.value.string)
    }
  }

  public func extract(carrier: [String: String], getter: some Getter) -> Baggage? {
    let builder = OpenTelemetry.instance.baggageManager.baggageBuilder()
    var limits = BaggagePropagationLimits()

    carrier.forEach {
      if $0.key.hasPrefix(JaegerBaggagePropagator.baggagePrefix) {
        if $0.key.count == JaegerBaggagePropagator.baggagePrefix.count {
          return
        }

        if let key = EntryKey(name: String($0.key.dropFirst(JaegerBaggagePropagator.baggagePrefix.count))),
           let value = EntryValue(string: $0.value),
           limits.accept(key: key, value: value) {
          builder.put(key: key, value: value, metadata: nil)
        }
      } else if $0.key == JaegerBaggagePropagator.baggageHeader {
        $0.value.split(separator: ",").forEach { entry in
          let keyValue = entry.split(separator: "=")
          if keyValue.count != 2 {
            return
          }
          if let key = EntryKey(name: String(keyValue[0])),
             let value = EntryValue(string: String(keyValue[1])),
             limits.accept(key: key, value: value) {
            builder.put(key: key, value: value, metadata: nil)
          }
        }
      }
    }

    return builder.build()
  }
}

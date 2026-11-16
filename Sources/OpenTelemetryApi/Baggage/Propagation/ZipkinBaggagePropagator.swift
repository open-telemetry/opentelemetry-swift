/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 * Implementation of the Zipkin propagation protocol and by default it uses `baggage-` prefix. See
 * https://github.com/openzipkin/brave/blob/master/brave/README.md#remote-baggage
 *
 * The Zipkin format defines no limits on baggage; the W3C Baggage limits are applied to the keys and values on extraction and injection.
 */

public class ZipkinBaggagePropagator: TextMapBaggagePropagator {
  public static let baggagePrefix = "baggage-"

  public let fields: Set<String> = []

  public init() {}

  public func inject(baggage: Baggage, carrier: inout [String: String], setter: some Setter) {
    var limits = BaggagePropagationLimits()

    // Sorted so that the entries kept at capacity are the same on every peer and every run.
    baggage.getEntries().sorted().forEach {
      guard limits.accept(key: $0.key, value: $0.value) else {
        return
      }

      setter.set(carrier: &carrier, key: ZipkinBaggagePropagator.baggagePrefix + $0.key.name, value: $0.value.string)
    }
  }

  public func extract(carrier: [String: String], getter: some Getter) -> Baggage? {
    let builder = OpenTelemetry.instance.baggageManager.baggageBuilder()
    var limits = BaggagePropagationLimits()

    carrier.forEach {
      if $0.key.hasPrefix(ZipkinBaggagePropagator.baggagePrefix) {
        if $0.key.count == ZipkinBaggagePropagator.baggagePrefix.count {
          return
        }

        if let key = EntryKey(name: String($0.key.dropFirst(ZipkinBaggagePropagator.baggagePrefix.count))),
           let value = EntryValue(string: $0.value),
           limits.accept(key: key, value: value) {
          builder.put(key: key, value: value, metadata: nil)
        }
      }
    }

    return builder.build()
  }
}

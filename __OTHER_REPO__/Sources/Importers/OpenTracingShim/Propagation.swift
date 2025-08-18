/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

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
    guard let currentBaggage = OpenTelemetry.instance.contextProvider.activeBaggage else { return nil }
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

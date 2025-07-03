//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class LongUpDownCounterSdk: LongUpDownCounter, Instrument {
  public private(set) var instrumentDescriptor: InstrumentDescriptor
  var storage: WritableMetricStorage

  init(instrumentDescriptor: InstrumentDescriptor, storage: WritableMetricStorage) {
    self.instrumentDescriptor = instrumentDescriptor
    self.storage = storage
  }

  public func add(value: Int) {
    add(value: value, attributes: [String: AttributeValue]())
  }

  public func add(value: Int, attributes: [String: OpenTelemetryApi.AttributeValue]) {
    storage.recordLong(value: value, attributes: attributes)
  }
}

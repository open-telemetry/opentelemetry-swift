//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DoubleGaugeSdk: DoubleGauge, Instrument {
  public var instrumentDescriptor: InstrumentDescriptor
  private var storage: WritableMetricStorage

  init(descriptor: InstrumentDescriptor, storage: WritableMetricStorage) {
    self.storage = storage
    instrumentDescriptor = descriptor
  }

  public func record(value: Double) {
    record(value: value, attributes: [String: AttributeValue]())
  }

  public func record(value: Double, attributes: [String: OpenTelemetryApi.AttributeValue]) {
    storage.recordDouble(value: value, attributes: attributes)
  }
}

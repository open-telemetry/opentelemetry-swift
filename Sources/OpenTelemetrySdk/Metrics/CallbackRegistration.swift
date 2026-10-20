//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class CallbackRegistration {
  var observableMeasurements = [ObservableMeasurementSdk]()
  var callback: () -> Void
  var instrumentDescriptors: [InstrumentDescriptor]
  var hasStorages: Bool
  init(
    observableMeasurements: [ObservableMeasurementSdk],
    callback: @escaping () -> Void
  ) {
    self.observableMeasurements = observableMeasurements
    self.callback = callback
    instrumentDescriptors = observableMeasurements.map { measurement in
      return measurement.descriptor
    }
    hasStorages = !observableMeasurements.map { measurement in
      measurement.storages

    }.isEmpty
  }

  public func execute(reader: RegisteredReader, startEpochNanos: UInt64, epochNanos: UInt64) {
    if !hasStorages {
      return
    }
    for measurement in observableMeasurements {
      measurement.setActiveReader(reader: reader, startEpochNanos: startEpochNanos, epochNanos: epochNanos)
    }
    callback()
    for measurement in observableMeasurements {
      measurement.clearActiveReader()
    }
  }
}

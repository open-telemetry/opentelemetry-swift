//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

@available(*, deprecated, renamed: "ObservableMeasurementSdk")
public typealias StableObservableMeasurementSdk = ObservableMeasurementSdk

public class ObservableMeasurementSdk: ObservableLongMeasurement, ObservableDoubleMeasurement {
  private var instrumentScope: InstrumentationScopeInfo
  public private(set) var descriptor: InstrumentDescriptor
  public private(set) var storages: [AsynchronousMetricStorage]
  private var activeReader: RegisteredReader?

  var startEpochNanos: UInt64 = 0
  var epochNanos: UInt64 = 0

  init(insturmentScope: InstrumentationScopeInfo, descriptor: InstrumentDescriptor, storages: [AsynchronousMetricStorage]) {
    instrumentScope = insturmentScope
    self.descriptor = descriptor
    self.storages = storages
  }

  func setActiveReader(reader: RegisteredReader, startEpochNanos: UInt64, epochNanos: UInt64) {
    activeReader = reader
    self.startEpochNanos = startEpochNanos
    self.epochNanos = epochNanos
  }

  public func clearActiveReader() {
    activeReader = nil
  }

  public func record(value: Int) {
    record(value: value, attributes: [String: AttributeValue]())
  }

  public func record(value: Int, attributes: [String: OpenTelemetryApi.AttributeValue]) {
    record(value: Double(value), attributes: attributes)
  }

  public func record(value: Double) {
    record(value: value, attributes: [String: AttributeValue]())
  }

  public func record(value: Double, attributes: [String: OpenTelemetryApi.AttributeValue]) {
    doRecord(measurement: Measurement.doubleMeasurement(startEpochNano: startEpochNanos, endEpochNano: epochNanos, value: value, attributes: attributes))
  }

  private func doRecord(measurement: Measurement) {
    guard activeReader != nil else {
      // todo: error log
      return
    }
    storages.forEach { storage in
      if storage.registeredReader == activeReader {
        storage.record(measurement: measurement)
      }
    }
  }
}

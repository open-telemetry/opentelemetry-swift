//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class InstrumentBuilder {
  private var meterProviderSharedState: MeterProviderSharedState
  private var meterSharedState: MeterSharedState
  var type: InstrumentType
  var valueType: InstrumentValueType
  var description: String
  var unit: String
  var instrumentName: String
  var explicitBucketBoundariesAdvice: [Double]?

  init(meterProviderSharedState: MeterProviderSharedState, meterSharedState: MeterSharedState, type: InstrumentType, valueType: InstrumentValueType, description: String, unit: String, instrumentName: String) {
    self.meterProviderSharedState = meterProviderSharedState
    self.meterSharedState = meterSharedState
    self.type = type
    self.valueType = valueType
    self.description = description
    self.unit = unit
    self.instrumentName = instrumentName
    self.explicitBucketBoundariesAdvice = nil
  }
}

public extension InstrumentBuilder {
  func setUnit(_ units: String) -> Self {
    // todo : validate unit
    unit = units
    return self
  }

  func setDescription(_ description: String) -> Self {
    self.description = description
    return self
  }

  internal func swapBuilder<T: InstrumentBuilder>(_ builder: (MeterProviderSharedState, MeterSharedState, String, String, String) -> T) -> T {
    let newBuilder = builder(meterProviderSharedState, meterSharedState, instrumentName, description, unit)
    newBuilder.explicitBucketBoundariesAdvice = self.explicitBucketBoundariesAdvice
    return newBuilder
  }

  // todo : Is it necessary to use inout for writableMetricStorage?
  func buildSynchronousInstrument<T: Instrument>(_ instrumentFactory: (InstrumentDescriptor, WritableMetricStorage) -> T) -> T {
    let descriptor = InstrumentDescriptor(name: instrumentName, description: description, unit: unit, type: type, valueType: valueType, explicitBucketBoundariesAdvice: explicitBucketBoundariesAdvice)
    let storage = meterSharedState.registerSynchronousMetricStorage(instrument: descriptor, meterProviderSharedState: meterProviderSharedState)
    return instrumentFactory(descriptor, storage)
  }

  func registerDoubleAsynchronousInstrument(type: InstrumentType, updater: @escaping (ObservableMeasurementSdk) -> Void) -> ObservableInstrumentSdk {
    let sdkObservableMeasurement = buildObservableMeasurement(type: type)
    let callbackRegistration = CallbackRegistration(observableMeasurements: [sdkObservableMeasurement]) {
      updater(sdkObservableMeasurement)
    }
    meterSharedState.registerCallback(callback: callbackRegistration)
    return ObservableInstrumentSdk(meterSharedState: meterSharedState, callbackRegistration: callbackRegistration)
  }

  func registerLongAsynchronousInstrument(type: InstrumentType, updater: @escaping (ObservableMeasurementSdk) -> Void) -> ObservableInstrumentSdk {
    let sdkObservableMeasurement = buildObservableMeasurement(type: type)
    let callbackRegistration = CallbackRegistration(observableMeasurements: [sdkObservableMeasurement], callback: {
      updater(sdkObservableMeasurement)
    })
    meterSharedState.registerCallback(callback: callbackRegistration)
    return ObservableInstrumentSdk(meterSharedState: meterSharedState, callbackRegistration: callbackRegistration)
  }

  func buildObservableMeasurement(type: InstrumentType) -> ObservableMeasurementSdk {
    let descriptor = InstrumentDescriptor(name: instrumentName, description: description, unit: unit, type: type, valueType: valueType, explicitBucketBoundariesAdvice: explicitBucketBoundariesAdvice)
    return meterSharedState.registerObservableMeasurement(instrumentDescriptor: descriptor)
  }
}

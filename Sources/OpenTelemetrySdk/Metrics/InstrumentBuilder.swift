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
    warnIfNameIsInvalid()
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
    warnIfNameIsInvalid()
    let descriptor = InstrumentDescriptor(name: instrumentName, description: description, unit: unit, type: type, valueType: valueType, explicitBucketBoundariesAdvice: explicitBucketBoundariesAdvice)
    return meterSharedState.registerObservableMeasurement(instrumentDescriptor: descriptor)
  }
}

/// Instrument name validation.
///
/// The specification leaves this validation to implementations of the API, such as the SDK:
/// https://opentelemetry.io/docs/specs/otel/metrics/api/#instrument-name-syntax
extension InstrumentBuilder {
  /// The maximum number of characters allowed in an instrument name.
  static let maximumNameLength = 255

  /// Returns whether `name` conforms to the instrument name syntax.
  ///
  /// A conforming name is not empty, is at most ``maximumNameLength`` characters long, begins with
  /// an ASCII alphabetic character, and otherwise contains only ASCII alphanumeric characters,
  /// `_`, `.`, `-`, or `/`.
  static func isValidName(_ name: String) -> Bool {
    guard !name.isEmpty, name.count <= maximumNameLength else { return false }

    var isFirstCharacter = true
    for scalar in name.unicodeScalars {
      if isFirstCharacter {
        guard isAlphabetic(scalar) else { return false }
        isFirstCharacter = false
      } else if !isAlphabetic(scalar),
                !isDigit(scalar),
                scalar != "_", scalar != ".", scalar != "-", scalar != "/" {
        return false
      }
    }
    return true
  }

  /// Emits a message through the feedback handler when the instrument name does not conform to the
  /// specification. The instrument is still built.
  func warnIfNameIsInvalid() {
    guard !InstrumentBuilder.isValidName(instrumentName) else { return }
    OpenTelemetry.instance.feedbackHandler?(
      "Instrument name \"\(instrumentName)\" does not conform to the OpenTelemetry specification. Names must be non-empty, at most \(InstrumentBuilder.maximumNameLength) characters, start with an alphabetic character, and otherwise contain only alphanumeric characters, '_', '.', '-', or '/'. The instrument was still created, but the resulting metric may be rejected by the backend. See https://opentelemetry.io/docs/specs/otel/metrics/api/#instrument-name-syntax"
    )
  }

  private static func isAlphabetic(_ scalar: Unicode.Scalar) -> Bool {
    (scalar >= "a" && scalar <= "z") || (scalar >= "A" && scalar <= "Z")
  }

  private static func isDigit(_ scalar: Unicode.Scalar) -> Bool {
    scalar >= "0" && scalar <= "9"
  }
}

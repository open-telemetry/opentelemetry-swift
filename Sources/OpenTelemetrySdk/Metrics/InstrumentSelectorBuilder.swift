//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class InstrumentSelectorBuilder {
  var instrumentType: InstrumentType?
  var instrumentName: String = ".*"
  var meterName: String?
  var meterVersion: String?
  var meterSchemaUrl: String?

  public init() {}

  public func setInstrument(type: InstrumentType) -> Self {
    instrumentType = type
    return self
  }

  public func setInstrument(name: String) -> Self {
    instrumentName = name
    return self
  }

  public func setMeter(name: String) -> Self {
    meterName = name
    return self
  }

  public func setMeter(version: String) -> Self {
    meterVersion = version
    return self
  }

  public func setMeter(schemaUrl: String) -> Self {
    meterSchemaUrl = schemaUrl
    return self
  }

  public func build() -> InstrumentSelector {
    // todo: assert at least 1 attribute is set
    return InstrumentSelector(instrumentType: instrumentType, instrumentName: instrumentName, meterName: meterName, meterVersion: meterVersion, meterSchemaUrl: meterSchemaUrl)
  }
}

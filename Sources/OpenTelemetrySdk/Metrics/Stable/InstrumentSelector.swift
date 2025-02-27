//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class InstrumentSelector {
  let instrumentType: InstrumentType?
  let instrumentName: String?
  let meterName: String?
  let meterVersion: String?
  let meterSchemaUrl: String?

  public static func builder() -> InstrumentSelectorBuilder {
    return InstrumentSelectorBuilder()
  }

  init(instrumentType: InstrumentType?, instrumentName: String?, meterName: String?, meterVersion: String?, meterSchemaUrl: String?) {
    self.instrumentType = instrumentType
    self.instrumentName = instrumentName
    self.meterName = meterName
    self.meterVersion = meterVersion
    self.meterSchemaUrl = meterSchemaUrl
  }
}

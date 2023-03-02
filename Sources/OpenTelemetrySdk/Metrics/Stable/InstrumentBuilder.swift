//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi


protocol InstrumentBuilder {
    var meterProviderSharedState : MeterProviderSharedState { get }
    var meterSharedState : MeterSharedState { get }
    var type : InstrumentType { get }
    var valueType : InstrumentValueType { get }
    var description : String { get set }
    var unit : String { get set }
    var instrumentName : String { get }
}
extension InstrumentBuilder {
    mutating func setUnit(_ units: String) -> Self {
        // todo : validate unit 
        self.unit = unit
        return self
    }
    
    mutating func setDescription(_ description: String) -> Self {
        self.description = description
        return self
    }
}

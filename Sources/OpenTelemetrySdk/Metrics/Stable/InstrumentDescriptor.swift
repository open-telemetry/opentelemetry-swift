//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation


public struct InstrumentDescriptor : Equatable {
    public let name : String
    public let description : String
    public let unit : String
    public let type : InstrumentType
    public let valueType : InstrumentValueType
    
    public init(name: String, description: String, unit: String, type: InstrumentType, valueType: InstrumentValueType) {
        self.name = name
        self.description = description
        self.unit = unit
        self.type = type
        self.valueType = valueType
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.unit == rhs.unit &&
        lhs.valueType == rhs.valueType &&
        lhs.type == rhs.type
    }
}

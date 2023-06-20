//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation


public protocol Instrument : Equatable {
    var instrumentDescriptor : InstrumentDescriptor { get }    
}

extension Instrument {
     public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.instrumentDescriptor == rhs.instrumentDescriptor
    }
}


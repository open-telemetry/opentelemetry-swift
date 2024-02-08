//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation

public struct LogLimits {
    static public let defaultMaxAttributeCount = 128
    static public let defaultMaxAttributeLength = Int.max
    public let maxAttributeCount : Int
    public let maxAttributeLength : Int
    
    public init(maxAttributeCount: Int = Self.defaultMaxAttributeCount , maxAttributeLength: Int = Self.defaultMaxAttributeLength) {
        self.maxAttributeCount = maxAttributeCount
        self.maxAttributeLength = maxAttributeLength
    }
}

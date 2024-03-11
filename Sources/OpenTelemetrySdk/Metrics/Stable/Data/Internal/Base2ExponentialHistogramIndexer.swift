//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class Base2ExponentialHistogramIndexer {
    private static var cache = [Int: Base2ExponentialHistogramIndexer]()
    private static var cacheLock = Lock()
    private static let LOG_BASE2_E = 1.0 / log(2)
    private static let EXPONENT_BIT_MASK : Int = 0x7FF0_0000_0000_0000
    private static let SIGNIFICAND_BIT_MASK : Int = 0xF_FFFF_FFFF_FFFF
    private static let EXPONENT_BIAS : Int = 1023
    private static let SIGNIFICAND_WIDTH : Int  = 52
    private static let EXPONENT_WIDTH : Int = 11

    private let scale : Int
    private let scaleFactor : Double

    init(scale: Int) {
        self.scale = scale
        self.scaleFactor = Self.computeScaleFactor(scale: scale)
    }

    func get(_ scale: Int) -> Base2ExponentialHistogramIndexer {
        Self.cacheLock.lock()
        defer {
            Self.cacheLock.unlock()
        }
        if let indexer = Self.cache[scale] {
            return indexer
        } else {
            let indexer = Base2ExponentialHistogramIndexer(scale: scale)
            Self.cache[scale] = indexer
            return indexer
        }
    }

    func computeIndex(_ value: Double) -> Int {
        let absValue = abs(value)
        if scale > 0 {
            return indexByLogarithm(absValue)
        }
        if scale == 0 {
            return mapToIndexScaleZero(absValue)
        }
        return mapToIndexScaleZero(absValue) >> -scale
    }

    func indexByLogarithm(_ value : Double) -> Int {
        Int(ceil(log(value) * scaleFactor) - 1)
    }

    func mapToIndexScaleZero(_ value : Double) -> Int {
        let raw = value.bitPattern
        var rawExponent = (Int(raw) & Self.EXPONENT_BIT_MASK) >> Self.SIGNIFICAND_WIDTH   // does  `value.exponentBitPattern` work here?
        let rawSignificand = Int(raw) & Self.SIGNIFICAND_BIT_MASK // does  `value.significandBitPattern` work here?
        if rawExponent == 0 {
            rawExponent -= (rawSignificand - 1).leadingZeroBitCount - Self.EXPONENT_WIDTH - 1
        }
        let ieeeExponent = rawExponent - Self.EXPONENT_BIAS
        if rawSignificand == 0 {
            return ieeeExponent - 1
        }
        return ieeeExponent
    }

    static func computeScaleFactor(scale: Int) -> Double {
        Self.LOG_BASE2_E * pow(2.0, Double(scale))
    }
}


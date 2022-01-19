/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Measure instrument.
public protocol StableCounterMeter {
    associatedtype T : Numeric
    ///
    /// - Parameters:
    ///   - value: value by which the counter should be incremented (monotonic)
    ///   - attributes: array of key-value pair (optional)
    func add(_ value: T, attributes: [String: AttributeValue]?)
}



public struct NoopCounterMeter<T: Numeric> : StableCounterMeter {
    init() {}
    public func add(_ value: T, attributes: [String: AttributeValue]?) {}
}

typealias NoopIntCounter = NoopCounterMeter<UInt>
typealias NoopDoubleCounter = NoopCounterMeter<Double>
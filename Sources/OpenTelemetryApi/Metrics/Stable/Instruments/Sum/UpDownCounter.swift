/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

protocol UpDownCounter {
    associatedtype T
    ///
    /// - Parameters:
    ///   - value: the value by which the counter should be incremented (non-monotonic)
    ///   - attributes:array of key-value pairs (optional)
    func add(_ value: T, attributes: [String: AttributeValue]?)
}

public struct NoopUpDownCounter<T> : UpDownCounter {
    init() {}

    func add(_ value: T, attributes: [String: AttributeValue]?) {

    }
}
typealias NoopIntUpDownCounter = NoopUpDownCounter<Int>
typealias NoopDoubleUpDownCounter = NoopUpDownCounter<Double>
/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Measure instrument.
public protocol Counter {
    associatedtype T
    ///
    /// - Parameters:
    ///   - value: value by which the counter should be incremented
    ///   - attributes: array of key-value pair
    func add(_ value: T, attributes: [String: AttributeValue]?)
}



public struct NoopCounter<T> : Counter {
    init() {}
    public func add(_ value: T, attributes: [String: AttributeValue]?) {}
}
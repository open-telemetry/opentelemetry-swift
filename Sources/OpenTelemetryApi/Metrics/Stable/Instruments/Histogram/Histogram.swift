/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol Histogram {
    associatedtype T
/// - Parameters:
///   - value: value that should be recorded (positive values)
///   - attributes: array of key-value pair
    func record(_ value: T, attributes: [String: AttributeValue]?)
}

public struct NoopHistogram<T> : Histogram {
    init() {}
    public func record(_ value: T, attributes: [String: AttributeValue]?) {}
}

typealias NoopIntHistogram = NoopHistogram<UInt>
typealias NoopDoubleHistogram = NoopHistogram<Double>
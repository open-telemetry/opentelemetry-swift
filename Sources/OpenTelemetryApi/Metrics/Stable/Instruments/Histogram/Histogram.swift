//
// Created by Bryce Buchanan on 1/19/22.
//

import Foundation

public protocol Histogram {
    associatedtype T
/// - Parameters:
///   - value: value that should be recorded
///   - attributes: array of key-value pair
    func record(_ value: T, attributes: [String: AttributeValue]?))
}

public struct NoopHistogram<T> : Histogram {
    init() {}

    public func record(_ value: T, attributes: [String: AttributeValue]?) {}
}
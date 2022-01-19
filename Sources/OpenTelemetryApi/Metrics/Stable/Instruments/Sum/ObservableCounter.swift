//
// Created by Bryce Buchanan on 1/19/22.
//

import Foundation

public protocol ObservableCounter {
    associatedtype T
    ///
    /// - Parameters:
    ///   - value: value by which the counter should be incremented
    ///   - attributes: array of key-value pair
    func observe(_ value: T, attributes: [String: AttributeValue]?)
}

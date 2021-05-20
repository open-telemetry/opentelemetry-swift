/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol TextMapPropagator {
    /// Gets the list of headers used by propagator.
    var fields: Set<String> { get }

    /// Injects textual representation of span context to transmit over the wire.
    /// - Parameters:
    ///   - spanContext: Span context to transmit over the wire.
    ///   - carrier: Object to set context on. Instance of this object will be passed to setter.
    ///   - setter: Action that will set name and value pair on the object.
    func inject<S: Setter>(spanContext: SpanContext, carrier: inout [String: String], setter: S)

    /// Extracts span context from textual representation.
    /// - Parameters:
    ///   - carrier: Object to extract context from. Instance of this object will be passed to the getter.
    ///   - getter: Function that will return string value of a key with the specified name.
    @discardableResult func extract<G: Getter>(carrier: [String: String], getter: G) -> SpanContext?
}

public protocol Setter {
    /// - Parameters:
    ///   - carrier:  Object to set context on.
    ///   - key: Name of the value to set.
    ///   - value: Value to set.
    func set(carrier: inout [String: String], key: String, value: String)
}

public protocol Getter {
    /// - Parameters:
    ///   - carrier: Object to extract context from.
    ///   - key: Name of the value to extract.
    func get(carrier: [String: String], key: String) -> [String]?
}

// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

public protocol TextFormattable {
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
    func extract<G: Getter>(carrier: [String: String], getter: G) -> SpanContext
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

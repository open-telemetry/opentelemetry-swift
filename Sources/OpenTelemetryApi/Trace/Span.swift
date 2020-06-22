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

/// An interface that represents a span. It has an associated SpanContext.
/// Spans are created by the SpanBuilder.startSpan method.
/// Span must be ended by calling end().
public protocol Span: AnyObject, CustomStringConvertible {
    /// Type of span.
    /// Can be used to specify additional relationships between spans in addition to a parent/child relationship.
    var kind: SpanKind { get }

    /// The span context associated with this Span
    var context: SpanContext { get }

    /// Indicates whether this span will be recorded.
    var isRecordingEvents: Bool { get }

    /// The status of the span execution.
    var status: Status? { get set }

    /// The name of the Span.
    /// If changed, this will override the name provided via StartSpan method overload.
    /// Upon this update, any sampling behavior based on Span name will depend on the
    /// implementation.
    var name: String { get set }

    /// Puts a new attribute to the span.
    /// - Parameters:
    ///   - key: Key of the attribute.
    ///   - value: Attribute value.
    func setAttribute(key: String, value: AttributeValue?)

    /// Adds an event to the Span
    /// - Parameter name: the name of the event.
    func addEvent(name: String)

    /// Adds an event to the Span
    /// Use this method to specify an explicit event timestamp. If not called, the implementation
    /// will use the current timestamp value, which should be the default case.
    /// - Parameters:
    ///   - name: the name of the even
    ///   - timestamp: the explicit event timestamp in nanos since epoch
    func addEvent(name: String, timestamp: UInt64)

    /// Adds a single Event with the attributes to the Span.
    /// - Parameters:
    ///   - name: Event name.
    ///   - attributes: Dictionary of attributes name/value pairs associated with the Event
    func addEvent(name: String, attributes: [String: AttributeValue])

    /// Adds an event to the Span
    /// Use this method to specify an explicit event timestamp. If not called, the implementation
    /// will use the current timestamp value, which should be the default case.
    /// - Parameters:
    ///   - name: the name of the even
    ///   - attributes: Dictionary of attributes name/value pairs associated with the Event
    ///   - timestamp: the explicit event timestamp in nanos since epoch
    func addEvent(name: String, attributes: [String: AttributeValue], timestamp: UInt64)

    ///  Adds an Event object to the Span.
    /// - Parameter event: Event to add to the span.
    func addEvent<E: Event>(event: E)

    /// Adds an event to the Span
    /// Use this method to specify an explicit event timestamp. If not called, the implementation
    /// will use the current timestamp value, which should be the default case.
    /// - Parameters:
    ///   event: Event to add to the span.
    ///   - timestamp: the explicit event timestamp in nanos since epoch
    func addEvent<E: Event>(event: E, timestamp: UInt64)

    /// End the span.
    func end()

    /// End the span.
    /// - Parameter endOptions: The explicit EndSpanOptions for this span
    func end(endOptions: EndSpanOptions)
}

extension Span {
    public func end() {
        context.scope?.close()
    }

    public func end(endOptions: EndSpanOptions) {
        end()
    }
}

extension Span {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(context.spanId)
    }

    public static func == (lhs: Span, rhs: Span) -> Bool {
        return lhs.context.spanId == rhs.context.spanId
    }
}

extension Span {
    public func setAttribute(key: String, value: String) {
        return setAttribute(key: key, value: AttributeValue.string(value))
    }

    public func setAttribute(key: String, value: Int) {
        return setAttribute(key: key, value: AttributeValue.int(value))
    }

    public func setAttribute(key: String, value: Double) {
        return setAttribute(key: key, value: AttributeValue.double(value))
    }

    public func setAttribute(key: String, value: Bool) {
        return setAttribute(key: key, value: AttributeValue.bool(value))
    }

    public func setAttribute(key: SemanticAttributes, value: String) {
        return setAttribute(key: key.rawValue, value: AttributeValue.string(value))
    }

    public func setAttribute(key: SemanticAttributes, value: Int) {
        return setAttribute(key: key.rawValue, value: AttributeValue.int(value))
    }

    public func setAttribute(key: SemanticAttributes, value: Double) {
        return setAttribute(key: key.rawValue, value: AttributeValue.double(value))
    }

    public func setAttribute(key: SemanticAttributes, value: Bool) {
        return setAttribute(key: key.rawValue, value: AttributeValue.bool(value))
    }
}

extension Span {
    /// Helper method that populates span properties from host and port
    /// - Parameters:
    ///   - hostName: Hostr name.
    ///   - port: Port number.
    public func putHttpHostAttribute(string hostName: String, int port: Int) {
        if port == 80 || port == 443 {
            setAttribute(key: .httpHost, value: hostName)
        } else {
            setAttribute(key: .httpHost, value: "\(hostName):\(port)")
        }
    }

    /// Helper method that populates span properties from http status code
    /// - Parameters:
    ///   - statusCode: Http status code.
    ///   - reasonPhrase: Http reason phrase.
    public func putHttpStatusCode(statusCode: Int, reasonPhrase: String) {
        setAttribute(key: .httpStatusCode, value: statusCode)
        var newStatus: Status = .ok
        switch statusCode {
        case 200 ..< 400:
            newStatus = .ok
        case 400:
            newStatus = .invalid_argument
        case 403:
            newStatus = .permission_denied
        case 404:
            newStatus = .not_found
        case 429:
            newStatus = .resource_exhausted
        case 501:
            newStatus = .unimplemented
        case 503:
            newStatus = .unavailable
        case 504:
            newStatus = .deadline_exceeded
        default:
            newStatus = .unknown
        }
        status = newStatus.withDescription(description: reasonPhrase)
    }
}

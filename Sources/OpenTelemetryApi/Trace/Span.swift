/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// A base protocol for `Span` which encapsulates all of the functionality that is correct in both the imperative and structured APIs. Functionality which is only guarenteed to work as intended in the imperative APIs exists on `Span`.
///
/// If an API only provides a `SpanBase`, the span will be ended automatically at the end of the scope the span was provided. It is generally acceptable to end the span early anyway by casting to `Span`, however the span may still be active until the end of the scope the span was provided in depending on which context manager is in use.
///
/// - Warning: It is never correct to only implement `SpanBase`, `Span` should always be implemented for any span type as well.
public protocol SpanBase: AnyObject, CustomStringConvertible {
    /// Type of span.
    /// Can be used to specify additional relationships between spans in addition to a parent/child relationship.
    var kind: SpanKind { get }

    /// The span context associated with this Span
    var context: SpanContext { get }

    /// Indicates whether this span will be recorded.
    var isRecording: Bool { get }

    /// The status of the span execution.
    var status: Status { get set }

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
    func addEvent(name: String, timestamp: Date)

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
    func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date)
}

/// An interface that represents a span. It has an associated SpanContext.
/// Spans are created by the SpanBuilder.startSpan method.
/// Span must be ended by calling end().
public protocol Span: SpanBase {
    /// End the span.
    func end()

    /// End the span.
    /// - Parameter endOptions: The explicit EndSpanOptions for this span
    func end(time: Date)
}

public extension SpanBase {
    func hash(into hasher: inout Hasher) {
        hasher.combine(context.spanId)
    }

    static func == (lhs: SpanBase, rhs: SpanBase) -> Bool {
        return lhs.context.spanId == rhs.context.spanId
    }
}

public extension SpanBase {
    func setAttribute(key: String, value: String) {
        return setAttribute(key: key, value: AttributeValue.string(value))
    }

    func setAttribute(key: String, value: Int) {
        return setAttribute(key: key, value: AttributeValue.int(value))
    }

    func setAttribute(key: String, value: Double) {
        return setAttribute(key: key, value: AttributeValue.double(value))
    }

    func setAttribute(key: String, value: Bool) {
        return setAttribute(key: key, value: AttributeValue.bool(value))
    }

    func setAttribute(key: SemanticAttributes, value: String) {
        return setAttribute(key: key.rawValue, value: AttributeValue.string(value))
    }

    func setAttribute(key: SemanticAttributes, value: Int) {
        return setAttribute(key: key.rawValue, value: AttributeValue.int(value))
    }

    func setAttribute(key: SemanticAttributes, value: Double) {
        return setAttribute(key: key.rawValue, value: AttributeValue.double(value))
    }

    func setAttribute(key: SemanticAttributes, value: Bool) {
        return setAttribute(key: key.rawValue, value: AttributeValue.bool(value))
    }
}

public extension Span {
    /// Helper method that populates span properties from host and port
    /// - Parameters:
    ///   - hostName: Hostr name.
    ///   - port: Port number.
    func putHttpHostAttribute(string hostName: String, int port: Int) {
        setAttribute(key: .netHostName, value: hostName)
        setAttribute(key: .netHostPort, value: port)
    }

    /// Helper method that populates span properties from http status code
    /// - Parameters:
    ///   - statusCode: Http status code.
    ///   - reasonPhrase: Http reason phrase.
    func putHttpStatusCode(statusCode: Int, reasonPhrase: String) {
        setAttribute(key: .httpStatusCode, value: statusCode)
        var newStatus: Status
        switch statusCode {
        case 200 ..< 400:
            newStatus = .ok
        case 400 ..< 600:
            newStatus = .error(description: reasonPhrase)
        default:
            newStatus = .unset
        }
        status = newStatus
    }
}

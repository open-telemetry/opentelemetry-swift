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
  ///   - name: the name of the event.
  ///   - timestamp: the explicit event timestamp in nanos since epoch.
  func addEvent(name: String, timestamp: Date)

  /// Adds a single Event with the attributes to the Span.
  /// - Parameters:
  ///   - name: the name of the event.
  ///   - attributes: Dictionary of attributes name/value pairs associated with the event.
  func addEvent(name: String, attributes: [String: AttributeValue])

  /// Adds an event to the Span
  /// Use this method to specify an explicit event timestamp. If not called, the implementation
  /// will use the current timestamp value, which should be the default case.
  /// - Parameters:
  ///   - name: the name of the event.
  ///   - attributes: Dictionary of attributes name/value pairs associated with the event
  ///   - timestamp: the explicit event timestamp in nanos since epoch.
  func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date)
}

public protocol SpanExceptionRecorder {
  /// Adds an exception event to the Span.
  /// - Parameters:
  ///   - exception: the exception to be recorded.
  func recordException(_ exception: SpanException)

  /// Adds an exception event to the Span.
  /// Use this method to specify an explicit event timestamp. If not called, the implementation
  /// will use the current timestamp value, which should be the default case.
  /// - Parameters:
  ///   - exception: the exception to be recorded.
  ///   - timestamp: the explicit event timestamp in nanos since epoch.
  func recordException(_ exception: SpanException, timestamp: Date)

  /// Adds an exception event to the Span, with additional attributes to go alongside the
  /// default attribuites derived from the exception itself.
  /// - Parameters:
  ///   - exception: the exception to be recorded.
  ///   - attributes: Dictionary of attributes name/value pairs associated with the event.
  func recordException(_ exception: SpanException, attributes: [String: AttributeValue])

  /// Adds an exception event to the Span, with additional attributes to go alongside the
  /// default attribuites derived from the exception itself.
  /// Use this method to specify an explicit event timestamp. If not called, the implementation
  /// will use the current timestamp value, which should be the default case.
  /// - Parameters:
  ///   - exception: the exception to be recorded.
  ///   - attributes: Dictionary of attributes name/value pairs associated with the event.
  ///   - timestamp: the explicit event timestamp in nanos since epoch.
  func recordException(_ exception: SpanException, attributes: [String: AttributeValue], timestamp: Date)
}

/// An interface that represents a span. It has an associated SpanContext.
/// Spans are created by the SpanBuilder.startSpan method.
/// Span must be ended by calling end().
public protocol Span: SpanBase, SpanExceptionRecorder {
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

  static func == (lhs: Self, rhs: Self) -> Bool {
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

public extension SpanExceptionRecorder {
  /// Adds any Error as an exception event to the Span, with optional additional attributes
  /// and timestamp.
  /// If additonal attributes are specified, they are merged with the default attributes
  /// derived from the error itself.
  /// If an explicit timestamp is not provided, the implementation will use the current
  /// timestamp value, which should be the default case.
  /// - Parameters:
  ///   - exception: the exception to be recorded.
  ///   - attributes: Dictionary of attributes name/value pairs associated with the event.
  ///   - timestamp: the explicit event timestamp in nanos since epoch.
  func recordException(_ exception: Error, attributes: [String: AttributeValue]? = nil, timestamp: Date? = nil) {
    let exception = exception as NSError

    switch (attributes, timestamp) {
    case (.none, .none): recordException(exception)
    case let (.some(attributes), .none): recordException(exception, attributes: attributes)
    case let (.none, .some(timestamp)): recordException(exception, timestamp: timestamp)
    case let (.some(attributes), .some(timestamp)): recordException(exception, attributes: attributes, timestamp: timestamp)
    }
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
    var newStatus: Status = switch statusCode {
    case 200 ..< 400:
      .ok
    case 400 ..< 600:
      .error(description: reasonPhrase)
    default:
      .unset
    }
    status = newStatus
  }
}

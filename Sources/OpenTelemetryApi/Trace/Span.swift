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
    func setAttribute(key: String, value: String?)

    /// Puts a new attribute to the span.
    /// - Parameters:
    ///   - key: Key of the attribute.
    ///   - value: Attribute value.
    func setAttribute(key: String, value: Int)

    /// Puts a new attribute to the span.
    /// - Parameters:
    ///   - key: Key of the attribute.
    ///   - value: Attribute value.
    func setAttribute(key: String, value: Double)

    /// Puts a new attribute to the span.
    /// - Parameters:
    ///   - key: Key of the attribute.
    ///   - value: Attribute value.
    func setAttribute(key: String, value: Bool)

    /// Puts a new attribute to the span.
    /// - Parameters:
    ///   - key: Key of the attribute.
    ///   - value: Attribute value.
    func setAttribute(key: String, value: AttributeValue)

    /// Adds an event to the Span
    /// - Parameter name: the name of the event.
    func addEvent(name: String)

    /// Adds an event to the Span
    /// Use this method to specify an explicit event timestamp. If not called, the implementation
    /// will use the current timestamp value, which should be the default case.
    /// - Parameters:
    ///   - name: the name of the even
    ///   - timestamp: the explicit event timestamp in nanos since epoch
    func addEvent(name: String, timestamp: Int)

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
    func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Int)

    ///  Adds an Event object to the Span.
    /// - Parameter event: Event to add to the span.
    func addEvent<E: Event>(event: E)

    /// Adds an event to the Span
    /// Use this method to specify an explicit event timestamp. If not called, the implementation
    /// will use the current timestamp value, which should be the default case.
    /// - Parameters:
    ///   event: Event to add to the span.
    ///   - timestamp: the explicit event timestamp in nanos since epoch
    func addEvent<E: Event>(event: E, timestamp: Int)

    /// End the span.
    func end()

    /// End the span.
    /// - Parameter endOptions: The explicit EndSpanOptions for this span
    func end(endOptions: EndSpanOptions)
}

public enum SpanAttributeConstants: String {
    case httpMethodKey = "http.method"
    case httpStatusCodeKey = "http.status_code"
    case httpUserAgentKey = "http.user_agent"
    case httpPathKey = "http.path"
    case httpHostKey = "http.host"
    case httpUrlKey = "http.url"
    case httpRequestSizeKey = "http.request.size"
    case httpResponseSizeKey = "http.response.size"
    case httpRouteKey = "http.route"
}

extension Span {
    public func setAttribute(key: String, value: String?) {
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
}

extension Span {
    /// Helper methods according to https://github.com/open-telemetry/OpenTelemetry-specs/blob/4954074adf815f437534457331178194f6847ff9/trace/HTTP.md.

    /// Helper method that populates span properties from http method
    /// - Parameter method: Http method.
    public func putHttpMethodAttribute(method: String) {
        setAttribute(key: SpanAttributeConstants.httpMethodKey.rawValue, value: method)
    }

    /// Helper method that populates span properties from http status code
    /// - Parameter statusCode: Http status code.
    public func putHttpStatusCodeAttribute(statusCode: Int) {
        setAttribute(key: SpanAttributeConstants.httpStatusCodeKey.rawValue, value: statusCode)
    }

    /// Helper method that populates span properties from http user agent
    /// - Parameter userAgent: Http user agent.
    public func putHttpUserAgentAttribute(userAgent: String) {
        if userAgent != " " {
            setAttribute(key: SpanAttributeConstants.httpUserAgentKey.rawValue, value: userAgent)
        }
    }

    /// Helper method that populates span properties from host and port
    /// - Parameters:
    ///   - hostName: Hostr name.
    ///   - port: Port number.
    public func putHttpHostAttribute(string hostName: String, int port: Int) {
        if port == 80 || port == 443 {
            setAttribute(key: SpanAttributeConstants.httpHostKey.rawValue, value: hostName)
        } else {
            setAttribute(key: SpanAttributeConstants.httpHostKey.rawValue, value: "\(hostName):\(port)")
        }
    }

    /// Helper method that populates span properties from route
    /// - Parameter route: Route used to resolve url to controller.
    public func putHttpRouteAttribute(route: String) {
        if !route.isEmpty {
            setAttribute(key: SpanAttributeConstants.httpRouteKey.rawValue, value: route)
        }
    }

    /// Helper method that populates span properties from url
    /// - Parameter rawUrl: string representing the URL
    public func putHttpRawUrlAttribute(rawUrl: String) {
        if !rawUrl.isEmpty {
            setAttribute(key: SpanAttributeConstants.httpUrlKey.rawValue, value: rawUrl)
        }
    }

    /// Helper method that populates span properties from url path according
    /// - Parameter path: Url path.
    public func putHttpPathAttribute(path: String) {
        setAttribute(key: SpanAttributeConstants.httpPathKey.rawValue, value: path)
    }

    /// Helper method that populates span properties from size
    /// - Parameter size: Response size.
    public func putHttpResponseSizeAttribute(size: Int) {
        setAttribute(key: SpanAttributeConstants.httpResponseSizeKey.rawValue, value: size)
    }

    /// Helper method that populates span properties from request size
    /// - Parameter size: Request size.
    public func putHttpRequestSizeAttribute(size: Int) {
        setAttribute(key: SpanAttributeConstants.httpRequestSizeKey.rawValue, value: size)
    }

    /// Helper method that populates span properties from http status code
    /// - Parameters:
    ///   - statusCode: Http status code.
    ///   - reasonPhrase: Http reason phrase.
    public func putHttpStatusCode(statusCode: Int, reasonPhrase: String) {
        putHttpStatusCodeAttribute(statusCode: statusCode)
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

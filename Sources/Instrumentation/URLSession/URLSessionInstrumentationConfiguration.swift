/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public typealias DataOrFile = Any
public typealias SessionTaskId = String
public typealias HTTPStatus = Int

public struct URLSessionInstrumentationConfiguration {
    public init(shouldRecordPayload: ((URLSession) -> (Bool)?)? = nil,
                shouldInstrument: ((URLRequest) -> (Bool)?)? = nil,
                nameSpan: ((URLRequest) -> (String)?)? = nil,
                spanCustomization: ((URLRequest, SpanBuilder) -> Void)? = nil,
                shouldInjectTracingHeaders: ((URLRequest) -> (Bool)?)? = nil,
                injectCustomHeaders: ((inout URLRequest, Span?) -> Void)? = nil,
                createdRequest: ((URLRequest, Span) -> Void)? = nil,
                receivedResponse: ((URLResponse, DataOrFile?, Span) -> Void)? = nil,
                receivedError: ((Error, DataOrFile?, HTTPStatus, Span) -> Void)? = nil,
                delegateClassesToInstrument: [AnyClass]? = nil)
    {
        self.shouldRecordPayload = shouldRecordPayload
        self.shouldInstrument = shouldInstrument
        self.shouldInjectTracingHeaders = shouldInjectTracingHeaders
        self.injectCustomHeaders = injectCustomHeaders
        self.nameSpan = nameSpan
        self.spanCustomization = spanCustomization
        self.createdRequest = createdRequest
        self.receivedResponse = receivedResponse
        self.receivedError = receivedError
        self.delegateClassesToInstrument = delegateClassesToInstrument
    }

    // Instrumentation Callbacks

    /// Implement this callback to filter which requests you want to instrument, all by default
    public var shouldInstrument: ((URLRequest) -> (Bool)?)?

    /// Implement this callback if you want the session to record payload data, false by default.
    /// This callback is only necessary when using session delegate
    public var shouldRecordPayload: ((URLSession) -> (Bool)?)?

    /// Implement this callback to filter which requests you want to inject headers to follow the trace,
    /// also must implement it if you want to inject custom headers
    /// Instruments all requests by default
    public var shouldInjectTracingHeaders: ((URLRequest) -> (Bool)?)?

    /// Implement this callback to inject custom headers or modify the request in any other way
    public var injectCustomHeaders: ((inout URLRequest, Span?) -> Void)?

    /// Implement this callback to override the default span name for a given request, return nil to use default.
    /// default name: `HTTP {method}` e.g. `HTTP PUT`
    public var nameSpan: ((URLRequest) -> (String)?)?

    /// Implement this callback to customize the span, such as by adding a parent, a link, attributes, etc
    public var spanCustomization: ((URLRequest, SpanBuilder) -> Void)?

    ///  Called before the span is created, it allows to add extra information to the Span
    public var createdRequest: ((URLRequest, Span) -> Void)?

    ///  Called before the span is ended, it allows to add extra information to the Span
    public var receivedResponse: ((URLResponse, DataOrFile?, Span) -> Void)?

    ///  Called before the span is ended, it allows to add extra information to the Span
    public var receivedError: ((Error, DataOrFile?, HTTPStatus, Span) -> Void)?
    
    ///  The array of URLSession delegate classes that will be instrumented by the library, will autodetect if nil is passed.
    public var delegateClassesToInstrument: [AnyClass]?
}

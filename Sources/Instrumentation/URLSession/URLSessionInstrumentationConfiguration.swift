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
                shouldInjectTracingHeaders: ((inout URLRequest) -> (Bool)?)? = nil,
                createdRequest: ((URLRequest, Span) -> Void)? = nil,
                receivedResponse: ((URLResponse, DataOrFile?, Span) -> Void)? = nil,
                receivedError: ((Error, DataOrFile?, HTTPStatus, Span) -> Void)? = nil)
    {
        self.shouldRecordPayload = shouldRecordPayload
        self.shouldInstrument = shouldInstrument
        self.shouldInjectTracingHeaders = shouldInjectTracingHeaders
        self.nameSpan = nameSpan
        self.createdRequest = createdRequest
        self.receivedResponse = receivedResponse
        self.receivedError = receivedError
    }

    // Instrumentation Callbacks

    /// Implement this callback to filter which requests you want to instrument, all by default
    public var shouldInstrument: ((URLRequest) -> (Bool)?)?

    /// Implement this callback if you want the session to record payload data, false by default.
    /// This callback is only necessary when using session delegate
    public var shouldRecordPayload: ((URLSession) -> (Bool)?)?

    /// Implement this callback to filter which requests you want to inject headers to follow the trace,
    /// you can also modify the request or add other headers in this method.
    /// Instruments all requests by default
    public var shouldInjectTracingHeaders: ((inout URLRequest) -> (Bool)?)?

    /// Implement this callback to override the default span name for a given request, return nil to use default.
    /// default name: `HTTP {method}` e.g. `HTTP PUT`
    public var nameSpan: ((URLRequest) -> (String)?)?

    ///  Called before the span is created, it allows to add extra information to the Span
    public var createdRequest: ((URLRequest, Span) -> Void)?

    ///  Called before the span is ended, it allows to add extra information to the Span
    public var receivedResponse: ((URLResponse, DataOrFile?, Span) -> Void)?

    ///  Called before the span is ended, it allows to add extra information to the Span
    public var receivedError: ((Error, DataOrFile?, HTTPStatus, Span) -> Void)?
}

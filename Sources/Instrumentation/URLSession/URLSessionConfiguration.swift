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
import OpenTelemetryApi
import OpenTelemetrySdk

public typealias DataOrFile = Any
public typealias SessionTaskId = String
public typealias HTTPStatus = Int

public struct URLSessionConfiguration {
    public init(shouldRecordPayload: ((URLSession) -> (Bool)?)? = nil,
                shouldInstrument: ((URLRequest) -> (Bool)?)? = nil,
                shouldInjectTracingHeaders: ((inout URLRequest) -> (Bool)?)? = nil,
                createdRequest: ((URLRequest, SpanBuilder) -> ())? = nil,
                receivedResponse: ((URLResponse, DataOrFile?, Span) -> ())? = nil,
                receivedError: ((Error, DataOrFile?, HTTPStatus, Span) -> ())? = nil)
    {
        self.shouldRecordPayload = shouldRecordPayload
        self.shouldInstrument = shouldInstrument
        self.shouldInjectTracingHeaders = shouldInjectTracingHeaders
        self.createdRequest = createdRequest
        self.receivedResponse = receivedResponse
        self.receivedError = receivedError
    }

    // Instrumentation Callbacks

    /// Implement this callback to filter wich requests you want to instrument, all by default
    public var shouldInstrument: ((URLRequest) -> (Bool)?)?

    /// Implement this callback if you want the session to record payload data, false by default
    public var shouldRecordPayload: ((URLSession) -> (Bool)?)?

    /// Implement this callback to filter wich requests you want to inject headers to follow the trace,
    /// you can also modify the request or add other headers in this method.
    /// Instruments all requests by default
    public var shouldInjectTracingHeaders: ((inout URLRequest) -> (Bool)?)?

    ///  Called before the span is created, it allows to add extra information to the Span through the builder
    public var createdRequest: ((URLRequest, SpanBuilder) -> ())?


    ///  Called before the span is ended, it allows to add extra information to the Span
    public var receivedResponse: ((URLResponse, DataOrFile?, Span) -> ())?

    ///  Called before the span is ended, it allows to add extra information to the Span
    public var receivedError: ((Error, DataOrFile?, HTTPStatus, Span) -> ())?
}

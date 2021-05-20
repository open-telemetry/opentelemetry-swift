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
import os
import OpenTelemetryApi
import OpenTelemetrySdk

/// A span processor that decorates spans with the origin attribute
@available(macOS 10.14, *)
public class SignPostIntegration: SpanProcessor {
    public let isStartRequired = true
    public let isEndRequired = true
    public let osLog = OSLog(subsystem: "OpenTelemetry", category: .pointsOfInterest)

    public init() {}

    public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        let signpostID = OSSignpostID(log: osLog, object: self)
        os_signpost(.begin, log: osLog, name: "Span", signpostID: signpostID, "%{public}@", span.name)
    }

    public func onEnd(span: ReadableSpan) {
        let signpostID = OSSignpostID(log: osLog, object: self)
        os_signpost(.end, log: osLog, name: "Span", signpostID: signpostID)
    }

    public func shutdown() {}
    public func forceFlush() {}
}

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

/// Implementation of the SpanProcessor that simply forwards all received events to a list of
/// SpanProcessors.
public struct MultiSpanProcessor: SpanProcessor {
    var spanProcessorsStart = [SpanProcessor]()
    var spanProcessorsEnd = [SpanProcessor]()
    var spanProcessorsAll = [SpanProcessor]()

    public init(spanProcessors: [SpanProcessor]) {
        spanProcessorsAll = spanProcessors
        spanProcessorsAll.forEach {
            if $0.isStartRequired {
                spanProcessorsStart.append($0)
            }
            if $0.isEndRequired {
                spanProcessorsEnd.append($0)
            }
        }
    }

    public var isStartRequired: Bool {
        return spanProcessorsStart.count > 0
    }

    public var isEndRequired: Bool {
        return spanProcessorsEnd.count > 0
    }

    public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        spanProcessorsStart.forEach {
            $0.onStart(parentContext: parentContext, span: span)
        }
    }

    public func onEnd(span: ReadableSpan) {
        for var processor in spanProcessorsEnd {
            processor.onEnd(span: span)
        }
    }

    public func shutdown() {
        for var processor in spanProcessorsAll {
            processor.shutdown()
        }
    }

    public func forceFlush() {
        spanProcessorsAll.forEach {
            $0.forceFlush()
        }
    }
}

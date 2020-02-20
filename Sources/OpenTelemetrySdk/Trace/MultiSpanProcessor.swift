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

/// Implementation of the SpanProcessor that simply forwards all received events to a list of
/// SpanProcessors.
public struct MultiSpanProcessor: SpanProcessor {
    var spanProcessors = [SpanProcessor]()

    public init(spanProcessors: [SpanProcessor]) {
        self.spanProcessors = spanProcessors
    }

    public func onStart(span: ReadableSpan) {
        for processor in spanProcessors {
            processor.onStart(span: span)
        }
    }

    public func onEnd(span: ReadableSpan) {
        for var processor in spanProcessors {
            processor.onEnd(span: span)
        }
    }

    public func shutdown() {
        for var processor in spanProcessors {
            processor.shutdown()
        }
    }
}

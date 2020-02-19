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

/// Sampler is used to make decisions on Span sampling.
public protocol Sampler: AnyObject, CustomStringConvertible {
    /// Called during Span creation to make a sampling decision.
    /// - Parameters:
    ///   - parentContext: the parent span's SpanContext. nil if this is a root span
    ///   - traceId: the TraceId for the new Span. This will be identical to that in
    ///     the parentContext, unless this is a root span.
    ///   - spanId: the SpanId for the new Span.
    ///   - name: he name of the new Span.
    ///   - parentLinks: the parentLinks associated with the new Span.
    func shouldSample(parentContext: SpanContext?,
                      traceId: TraceId,
                      spanId: SpanId,
                      name: String,
                      parentLinks: [Link]) -> Decision
}

/// Sampling decision returned by Sampler.shouldSample(SpanContext, TraceId, SpanId, String, Array).
public protocol Decision {
    /// The sampling decision whether span should be sampled or not.
    var isSampled: Bool { get }

    /// Return tags which will be attached to the span.
    /// These attributes should be added to the span only for root span or when sampling decision
    /// changes from false to true.
    var attributes: [String: AttributeValue] { get }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// Sampler is used to make decisions on Span sampling.
public protocol Sampler: AnyObject, CustomStringConvertible {
  /// Called during Span creation to make a sampling decision.
  /// - Parameters:
  ///   - parentContext: the parent span's SpanContext. nil if this is a root span
  ///   - traceId: the TraceId for the new Span. This will be identical to that in
  ///     the parentContext, unless this is a root span.
  ///   - name: he name of the new Span.
  ///   - parentLinks: the parentLinks associated with the new Span.
  func shouldSample(parentContext: SpanContext?,
                    traceId: TraceId,
                    name: String,
                    kind: SpanKind,
                    attributes: [String: AttributeValue],
                    parentLinks: [SpanData.Link]) -> Decision
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

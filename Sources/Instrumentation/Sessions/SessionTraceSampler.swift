/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import OpenTelemetrySdk

/// Samples spans using the session decision and a trace sampler.
/// The default delegate preserves unsampled parents. A sampled parent does not override an
/// unsampled session. Attribution and sampling use the same session snapshot.
/// Use this instead of SessionSpanProcessor, which would look up the session again.
public final class SessionTraceSampler: Sampler {
  private let sessionManager: SessionManager
  private let delegate: Sampler

  public init(sessionManager: SessionManager,
              delegate: Sampler = Samplers.parentBased(root: Samplers.alwaysOn)) {
    self.sessionManager = sessionManager
    self.delegate = delegate
  }

  public func shouldSample(parentContext: SpanContext?, traceId: TraceId, name: String,
                           kind: SpanKind, attributes: [String: AttributeValue],
                           parentLinks: [SpanData.Link]) -> Decision {
    guard let session = sessionManager.sessionForSignalAttribution(), session.samplingDecision.isSampled else {
      return SessionTraceDecision(isSampled: false, attributes: [:])
    }
    let decision = delegate.shouldSample(parentContext: parentContext, traceId: traceId, name: name,
                                         kind: kind, attributes: attributes, parentLinks: parentLinks)
    return SessionTraceDecision(
      isSampled: decision.isSampled,
      attributes: decision.attributes.merging(session.samplingAttributes) { _, sessionValue in sessionValue }
    )
  }

  public var description: String {
    "SessionTraceSampler{\(delegate)}"
  }
}

private struct SessionTraceDecision: Decision {
  let isSampled: Bool
  let attributes: [String: AttributeValue]
}

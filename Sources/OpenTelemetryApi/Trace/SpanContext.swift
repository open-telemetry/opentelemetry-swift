/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// A class that represents a span context. A span context contains the state that must propagate to
/// child Spans and across process boundaries. It contains the identifiers race_id and span_id
/// associated with the Span and a set of options.
public struct SpanContext: Equatable, CustomStringConvertible, Hashable, Codable, Sendable {
  /// The trace identifier associated with this SpanContext
  public private(set) var traceId: TraceId

  /// The span identifier associated with this  SpanContext
  public private(set) var spanId: SpanId

  /// The traceFlags associated with this SpanContext
  public private(set) var traceFlags: TraceFlags

  /// The traceState associated with this SpanContext
  public let traceState: TraceState

  /// The traceState associated with this SpanContext
  public let isRemote: Bool

  private init(traceId: TraceId, spanId: SpanId, traceFlags: TraceFlags, traceState: TraceState, isRemote: Bool) {
    self.traceId = traceId
    self.spanId = spanId
    self.traceFlags = traceFlags
    self.traceState = traceState
    self.isRemote = isRemote
  }

  /// Creates a new SpanContext with the given identifiers and options.
  /// - Parameters:
  ///   - traceId: the trace identifier of the span context.
  ///   - spanId: the span identifier of the span context.
  ///   - traceFlags: he trace options for the span context.
  ///   - traceState: the trace state for the span context.
  public static func create(traceId: TraceId,
                            spanId: SpanId,
                            traceFlags: TraceFlags,
                            traceState: TraceState) -> SpanContext {
    return SpanContext(traceId: traceId,
                       spanId: spanId,
                       traceFlags: traceFlags,
                       traceState: traceState,
                       isRemote: false)
  }

  /// Creates a new SpanContext that was propagated from a remote parent, with the given
  /// identifiers and options.
  /// - Parameters:
  ///   - traceId: the trace identifier of the span context.
  ///   - spanId: the span identifier of the span context.
  ///   - traceFlags: he trace options for the span context.
  ///   - traceState: the trace state for the span context.
  public static func createFromRemoteParent(traceId: TraceId,
                                            spanId: SpanId,
                                            traceFlags: TraceFlags,
                                            traceState: TraceState) -> SpanContext {
    return SpanContext(traceId: traceId,
                       spanId: spanId,
                       traceFlags: traceFlags,
                       traceState: traceState,
                       isRemote: true)
  }

  /// Returns true if this SpanContext is valid.
  public var isValid: Bool {
    return traceId.isValid && spanId.isValid
  }

  public var isSampled: Bool {
    return traceFlags.sampled
  }

  public static func == (lhs: SpanContext, rhs: SpanContext) -> Bool {
    return lhs.traceId == rhs.traceId && lhs.spanId == rhs.spanId &&
      lhs.traceFlags == rhs.traceFlags && lhs.isRemote == rhs.isRemote
  }

  public var description: String {
    return "SpanContext{traceId=\(traceId), spanId=\(spanId), traceFlags=\(traceFlags)}, isRemote=\(isRemote)"
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(spanId)
  }
}

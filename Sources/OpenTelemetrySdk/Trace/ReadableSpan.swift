/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// The extend Span interface used by the SDK.
public protocol ReadableSpan: Span {
  /// The name of the Span.
  /// The name can be changed during the lifetime of the Span so this value cannot be cached.
  var name: String { get set }

  /// The instrumentation scope specified when creating the tracer which produced this span.
  var instrumentationScopeInfo: InstrumentationScopeInfo { get }

  /// This converts this instance into an immutable SpanData instance, for use in export.
  func toSpanData() -> SpanData

  /// Returns whether this Span has already been ended.
  var hasEnded: Bool { get }

  /// Returns the latecy of the  Span. If still active then returns now() - start time.
  var latency: TimeInterval { get }

  /// get attributes
  func getAttributes() -> [String: AttributeValue]
}

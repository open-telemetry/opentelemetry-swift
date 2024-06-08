/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Tracer is a simple, protocol for Span creation and in-process context interaction.
/// Users may choose to use manual or automatic Context propagation. Because of that this class
/// offers APIs to facilitate both usages.
/// The automatic context propagation is done using os.activity
public protocol Tracer: AnyObject {
    /// Returns a SpanBuilder to create and start a new Span
    /// - Parameter spanName: The name of the returned Span.
    func spanBuilder(spanName: String) -> SpanBuilder
}

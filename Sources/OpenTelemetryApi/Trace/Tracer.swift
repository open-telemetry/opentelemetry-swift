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

/// Tracer is a simple, protocol for Span creation and in-process context interaction.
/// Users may choose to use manual or automatic Context propagation. Because of that this class
/// offers APIs to facilitate both usages.
/// The automatic context propagation is done using os.activity
public protocol Tracer: AnyObject {
    /// Gets the current Span from the current Context.
    var currentSpan: Span? { get }

    /// Gets the BinaryFormat for this implementation.
    var binaryFormat: BinaryFormattable { get }

    /// Gets the ITextFormat for this implementation.
    var textFormat: TextFormattable { get }

    /// Returns a SpanBuilder to create and start a new Span
    /// - Parameter spanName: The name of the returned Span.
    func spanBuilder(spanName: String) -> SpanBuilder

    /// Associates the span with the current context.
    /// - Parameter span: Span to associate with the current context.
    func withSpan(_ span: Span) -> Scope
}

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

/// The extend Span interface used by the SDK.
public protocol ReadableSpan: Span {
    /// The name of the Span.
    /// The name can be changed during the lifetime of the Span so this value cannot be cached.
    var name: String { get set }

    /// The instrumentation library specified when creating the tracer which produced this span.
    var instrumentationLibraryInfo: InstrumentationLibraryInfo { get }

    /// This converts this instance into an immutable SpanData instance, for use in export.
    func toSpanData() -> SpanData

    /// Returns whether this Span has already been ended.
    var hasEnded: Bool { get }

    /// Returns the latecy of the {@code Span} in nanos. If still active then returns now() - start time.
    var latencyNanos: Int { get }
}

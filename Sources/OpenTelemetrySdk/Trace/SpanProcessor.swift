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

/// SpanProcessor is the interface TracerSdk uses to allow synchronous hooks for when a Span
/// is started or when a Span is ended.
public protocol SpanProcessor {
    /// Called when a Span is started, if the Span.isRecording is true.
    /// This method is called synchronously on the execution thread, should not throw or block the
    /// execution thread.
    /// - Parameter span: the ReadableSpan that just started
    func onStart(span: ReadableSpan)

    /// Called when a Span is ended, if the Span.isRecording() is true.
    /// This method is called synchronously on the execution thread, should not throw or block the
    /// execution thread.
    /// - Parameter span: the ReadableSpan that just ended.
    mutating func onEnd(span: ReadableSpan)

    /// Called when TracerSdk.shutdown() is called.
    mutating func shutdown()
}

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
@testable import OpenTelemetrySdk

class SpanProcessorMock: SpanProcessor {
    var onStartCalledTimes = 0
    lazy var onStartCalled: Bool = { self.onStartCalledTimes > 0 }()
    var onStartCalledSpan: ReadableSpan?
    var onEndCalledTimes = 0
    lazy var onEndCalled: Bool = { self.onEndCalledTimes > 0 }()
    var onEndCalledSpan: ReadableSpan?
    var shutdownCalledTimes = 0
    lazy var shutdownCalled: Bool = { self.shutdownCalledTimes > 0 }()

    func onStart(span: ReadableSpan) {
        onStartCalledTimes += 1
        onStartCalledSpan = span
    }

    func onEnd(span: ReadableSpan) {
        onEndCalledTimes += 1
        onEndCalledSpan = span
    }

    func shutdown() {
        shutdownCalledTimes += 1
    }
}

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

public class SpanContextShimTable {
    private let lock = ReadWriteLock()
    private var shimsMap = [SpanContext: SpanContextShim]()

    public func setBaggageItem(spanShim: SpanShim, key: String, value: String) {
        lock.withWriterLockVoid {
            var contextShim = shimsMap[spanShim.span.context]
            if contextShim == nil {
                contextShim = SpanContextShim(spanShim: spanShim)
            }

            contextShim = contextShim?.newWith(key: key, value: value)
            shimsMap[spanShim.span.context] = contextShim
        }
    }

    public func getBaggageItem(spanShim: SpanShim, key: String) -> String? {
        lock.withReaderLock {
            let contextShim = shimsMap[spanShim.span.context]
            return contextShim?.getBaggageItem(key: key)
        }
    }

    public func get(spanShim: SpanShim) -> SpanContextShim? {
        lock.withReaderLock {
            shimsMap[spanShim.span.context]
        }
    }

    public func create(spanShim: SpanShim) -> SpanContextShim {
        return create(spanShim: spanShim, distContext: spanShim.telemetryInfo.emptyBaggage)
    }

    @discardableResult public func create(spanShim: SpanShim, distContext: Baggage) -> SpanContextShim {
        lock.withWriterLock {
            var contextShim = shimsMap[spanShim.span.context]
            if contextShim != nil {
                return contextShim!
            }

            contextShim = SpanContextShim(telemetryInfo: spanShim.telemetryInfo, context: spanShim.span.context, baggage: distContext)
            shimsMap[spanShim.span.context] = contextShim
            return contextShim!
        }
    }
}

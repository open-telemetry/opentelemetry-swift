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

/// Implementation of the SpanExporter that simply forwards all received spans to a list of
/// SpanExporter.
/// Can be used to export to multiple backends using the same SpanProcessor} like a impleSampledSpansProcessor
///  or a BatchSampledSpansProcessor.
public class MultiSpanExporter: SpanExporter {
    var spanExporters: [SpanExporter]

    public init(spanExporters: [SpanExporter]) {
        self.spanExporters = spanExporters
    }

    public func export(spans: [SpanData]) -> SpanExporterResultCode {
        var currentResultCode = SpanExporterResultCode.success
        for exporter in spanExporters {
            currentResultCode.mergeResultCode(newResultCode: exporter.export(spans: spans))
        }
        return currentResultCode
    }

    public func shutdown() {
        for exporter in spanExporters {
            exporter.shutdown()
        }
    }
}

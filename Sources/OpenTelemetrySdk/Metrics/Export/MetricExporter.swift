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

public enum MetricExporterResultCode {
    case success
    case failureNotRetryable
    case failureRetryable

    /// Merges the current result code with other result code
    /// - Parameter newResultCode: the result code to merge with
    mutating func mergeResultCode(newResultCode: MetricExporterResultCode) {
        // If both results are success then return success.
        if self == .success, newResultCode == .success {
            self = .success
            return
        } else if self == .failureRetryable || self == .success,
                  newResultCode == .failureRetryable || newResultCode == .success
        {
            self = .failureRetryable
        }
        self = .failureNotRetryable
    }
}

public protocol MetricExporter {
    func export(metrics: [Metric], shouldCancel: (() -> Bool)?) -> MetricExporterResultCode
}

/// Implementation of the SpanExporter that simply forwards all received spans to a list of
/// SpanExporter.
/// Can be used to export to multiple backends using the same SpanProcessor} like a impleSampledSpansProcessor
///  or a BatchSampledSpansProcessor.
struct MultiMetricExporter: MetricExporter {

    var metricExporters: [MetricExporter]

    init(metricExporters: [MetricExporter]) {
        self.metricExporters = metricExporters
    }

    func export(metrics: [Metric], shouldCancel: (() -> Bool)?) -> MetricExporterResultCode {
        var currentResultCode = MetricExporterResultCode.success
        metricExporters.forEach {
            currentResultCode.mergeResultCode(newResultCode: $0.export(metrics: metrics, shouldCancel: shouldCancel))
        }
        return currentResultCode
    }
}

struct NoopMetricExporter: MetricExporter {
    func export(metrics: [Metric], shouldCancel: (() -> Bool)?) -> MetricExporterResultCode {
        return .success
    }
}

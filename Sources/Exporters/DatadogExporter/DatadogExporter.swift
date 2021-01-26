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
import OpenTelemetrySdk

public class DatadogExporter: SpanExporter, MetricExporter {
    let configuration: ExporterConfiguration
    var spansExporter: SpansExporter!
    var logsExporter: LogsExporter!
    var metricsExporter: MetricsExporter!

    public init(config: ExporterConfiguration) throws {
        guard config.clientToken != nil || config.apiKey != nil else {
            throw ExporterError(description: "Traces exporter needs a client token and Metrics Exporter need an api key")
        }

        self.configuration = config
        if configuration.clientToken != nil {
            spansExporter = try SpansExporter(config: configuration)
            logsExporter = try LogsExporter(config: configuration)
        }
        if configuration.apiKey != nil {
            metricsExporter = try MetricsExporter(config: configuration)
        }
    }

    public func export(spans: [SpanData]) -> SpanExporterResultCode {
        spans.forEach {
            if $0.traceFlags.sampled || configuration.exportUnsampledSpans {
                spansExporter.exportSpan(span: $0)
            }
            if $0.traceFlags.sampled || configuration.exportUnsampledLogs {
                logsExporter.exportLogs(fromSpan: $0)
            }
        }
        return .success
    }

    public func export(metrics: [Metric], shouldCancel: (() -> Bool)?) -> MetricExporterResultCode {
        metrics.forEach {
            metricsExporter.exportMetric(metric: $0)
        }
        return .success
    }

    public func flush() -> SpanExporterResultCode {
        spansExporter.tracesStorage.writer.queue.sync {}
        logsExporter.logsStorage.writer.queue.sync {}
        metricsExporter.metricsStorage.writer.queue.sync {}

        _ = logsExporter.logsUpload.uploader.flush()
        _ = spansExporter.tracesUpload.uploader.flush()
        _ = metricsExporter.metricsUpload.uploader.flush()
        return .success
    }

    public func shutdown() {
        _ = self.flush()
    }

    public func endpointURLs() -> Set<String> {
        return [configuration.endpoint.logsURL.absoluteString,
                configuration.endpoint.tracesURL.absoluteString,
                configuration.endpoint.metricsURL.absoluteString]
    }
}

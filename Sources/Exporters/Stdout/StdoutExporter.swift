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
import OpenTelemetrySdk

public class StdoutExporter: SpanExporter {
    let isDebug: Bool

    public init(isDebug: Bool = false) {
        self.isDebug = isDebug
    }

    public func export(spans: [SpanData]) -> SpanExporterResultCode {
        let jsonEncoder = JSONEncoder()
        for span in spans {
            if isDebug {
                print("__________________")
                print("Span \(span.name):")
                print("TraceId: \(span.traceId.hexString)")
                print("SpanId: \(span.spanId.hexString)")
                print("Span kind: \(span.kind.rawValue)")
                print("TraceFlags: \(span.traceFlags)")
                print("TraceState: \(span.traceState)")
                print("ParentSpanId: \(span.parentSpanId?.hexString ?? SpanId.invalid.hexString)")
                print("Start: \(span.startTime.timeIntervalSince1970.toNanoseconds)")
                print("Duration: \(span.endTime.timeIntervalSince(span.startTime).toNanoseconds) nanoseconds")
                print("Attributes: \(span.attributes)")
                print("------------------\n")
            } else {
                do {
                    let jsonData = try jsonEncoder.encode(SpanExporterData(span: span))
                    if let json = String(data: jsonData, encoding: .utf8) {
                        print(json)
                    }
                } catch {
                    return .failure
                }
            }
        }
        return .success
    }

    public func flush() -> SpanExporterResultCode {
        return .success
    }

    public func shutdown() {}
}

private struct SpanExporterData: Encodable {
    private let span: String
    private let traceId: String
    private let spanId: String
    private let spanKind: String
    private let traceFlags: TraceFlags
    private let traceState: TraceState
    private let parentSpanId: String?
    private let start: Date
    private let duration: TimeInterval
    private let attributes: [String: AttributeValue]

    init(span: SpanData) {
        self.span = span.name
        self.traceId = span.traceId.hexString
        self.spanId = span.spanId.hexString
        self.spanKind = span.kind.rawValue
        self.traceFlags = span.traceFlags
        self.traceState = span.traceState
        self.parentSpanId = span.parentSpanId?.hexString ?? SpanId.invalid.hexString
        self.start = span.startTime
        self.duration = span.endTime.timeIntervalSince(span.startTime)
        self.attributes = span.attributes
    }
}

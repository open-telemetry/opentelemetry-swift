/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !os(watchOS)

import Foundation
import OpenTelemetrySdk
import Thrift

public class JaegerSpanExporter: SpanExporter {
    let collectorAddress: String
    let process: Process

    public init(serviceName: String, collectorAddress: String) {
        process = Process(serviceName: serviceName, tags: TList<Tag>())
        self.collectorAddress = collectorAddress
    }

    public func export(spans: [SpanData]) -> SpanExporterResultCode {
        var spanList = TList<Span>()
        spanList.append(contentsOf: Adapter.toJaeger(spans: spans))
        let batch = Batch(process: process, spans: spanList)
        let sender = Sender(host: collectorAddress)
        let success = sender.sendBatch(batch: batch)
        return success ? SpanExporterResultCode.success : SpanExporterResultCode.failure
    }

    public func flush() -> SpanExporterResultCode {
        return .success
    }

    public func shutdown() {
    }
}

#endif

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

/// Implementation of the SpanProcessor that batches spans exported by the SDK then pushes
/// to the exporter pipeline.
/// All spans reported by the SDK implementation are first added to a synchronized queue (with a
/// maxQueueSize maximum size, after the size is reached spans are dropped) and exported
/// every scheduleDelayMillis to the exporter pipeline in batches of maxExportBatchSize.
/// If the queue gets half full a preemptive notification is sent to the worker thread that
/// exports the spans to wake up and start a new export cycle.
/// This batchSpanProcessor can cause high contention in a very high traffic service.
public struct BatchSpanProcessor: SpanProcessor {
    var sampled: Bool
    fileprivate var worker: BatchWorker

    init(spanExporter: SpanExporter, sampled: Bool = true, scheduleDelay: TimeInterval = 5, maxQueueSize: Int = 2048, maxExportBatchSize: Int = 512) {
        worker = BatchWorker(spanExporter: spanExporter,
                             scheduleDelay: scheduleDelay,
                             maxQueueSize: maxQueueSize,
                             maxExportBatchSize: maxExportBatchSize)
        worker.start()
        self.sampled = sampled
    }

    public func onStart(span: ReadableSpan) {
    }

    public func onEnd(span: ReadableSpan) {
        if sampled && !span.context.traceFlags.sampled {
            return
        }
        worker.addSpan(span: span)
    }

    public func shutdown() {
        worker.cancel()
        worker.flush()
    }
}

/// BatchWorker is a thread that batches multiple spans and calls the registered SpanExporter to export
/// the data.
/// The list of batched data is protected by a NSCondition which ensures full concurrency.
private class BatchWorker: Thread {
    let spanExporter: SpanExporter
    let scheduleDelay: TimeInterval
    let maxQueueSize: Int
    let maxExportBatchSize: Int
    let halfMaxQueueSize: Int
    private let cond = NSCondition()
    var spanList = [ReadableSpan]()

    init(spanExporter: SpanExporter, scheduleDelay: TimeInterval, maxQueueSize: Int, maxExportBatchSize: Int) {
        self.spanExporter = spanExporter
        self.scheduleDelay = scheduleDelay
        self.maxQueueSize = maxQueueSize
        halfMaxQueueSize = maxQueueSize >> 1
        self.maxExportBatchSize = maxExportBatchSize
    }

    func addSpan(span: ReadableSpan) {
        cond.lock()
        defer { cond.unlock() }

        if spanList.count == maxQueueSize {
            // TODO: Record a counter for dropped spans.
            return
        }
        // TODO: Record a gauge for referenced spans.
        spanList.append(span)
        // Notify the worker thread that at half of the queue is available. It will take
        // time anyway for the thread to wake up.
        if spanList.count >= halfMaxQueueSize {
            cond.broadcast()
        }
    }

    override func main() {
        repeat {
            var spansCopy: [ReadableSpan]
            cond.lock()
            if spanList.count < maxExportBatchSize {
                repeat {
                    cond.wait(until: Date().addingTimeInterval(scheduleDelay))
                } while spanList.isEmpty
            }
            spansCopy = spanList
            spanList.removeAll()
            cond.unlock()
            exportBatches(spanList: spansCopy)
        } while true
    }

    func flush() {
        var spansCopy: [ReadableSpan]
        cond.lock()
        spansCopy = spanList
        spanList.removeAll()
        cond.unlock()
        // Execute the batch export outside the synchronized to not block all producers.
        exportBatches(spanList: spansCopy)
    }

    private func exportBatches(spanList: [ReadableSpan]) {
        stride(from: 0, to: spanList.endIndex, by: maxExportBatchSize).forEach {
            spanExporter.export(spans: spanList[$0 ..< min($0 + maxExportBatchSize, spanList.count)].map { $0.toSpanData() })
        }
    }
}

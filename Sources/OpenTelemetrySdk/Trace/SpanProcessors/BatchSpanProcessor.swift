/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// Implementation of the SpanProcessor that batches spans exported by the SDK then pushes
/// to the exporter pipeline.
/// All spans reported by the SDK implementation are first added to a synchronized queue (with a
/// maxQueueSize maximum size, after the size is reached spans are dropped) and exported
/// every scheduleDelayMillis to the exporter pipeline in batches of maxExportBatchSize.
/// If the queue gets half full a preemptive notification is sent to the worker thread that
/// exports the spans to wake up and start a new export cycle.
/// This batchSpanProcessor can cause high contention in a very high traffic service.
public struct BatchSpanProcessor: SpanProcessor {
  
  
  fileprivate var worker: BatchWorker
  
  public init(spanExporter: SpanExporter, scheduleDelay: TimeInterval = 5, exportTimeout: TimeInterval = 30,
              maxQueueSize: Int = 2048, maxExportBatchSize: Int = 512, willExportCallback: ((inout [SpanData]) -> Void)? = nil)
  {
    worker = BatchWorker(spanExporter: spanExporter,
                         scheduleDelay: scheduleDelay,
                         exportTimeout: exportTimeout,
                         maxQueueSize: maxQueueSize,
                         maxExportBatchSize: maxExportBatchSize,
                         willExportCallback: willExportCallback)
    worker.start()
  }
  
  public let isStartRequired = false
  public let isEndRequired = true
  
  public func onStart(parentContext: SpanContext?, span: ReadableSpan) {}
  
  public func onEnd(span: ReadableSpan) {
    if !span.context.traceFlags.sampled {
      return
    }
    worker.addSpan(span: span)
  }
  
  public func shutdown(explicitTimeout: TimeInterval? = nil) {
    worker.cancel()
    worker.shutdown()
  }
  
  public func forceFlush(timeout: TimeInterval? = nil) {
    worker.forceFlush(explicitTimeout: timeout)
  }
}

/// BatchWorker is a thread that batches multiple spans and calls the registered SpanExporter to export
/// the data.
/// The list of batched data is protected by a NSCondition which ensures full concurrency.
private class BatchWorker: Thread {
  let spanExporter: SpanExporter
  let scheduleDelay: TimeInterval
  let maxQueueSize: Int
  let exportTimeout: TimeInterval
  let maxExportBatchSize: Int
  let willExportCallback: ((inout [SpanData]) -> Void)?
  let halfMaxQueueSize: Int
  private let cond = NSCondition()
  var spanList = [ReadableSpan]()
  var queue: OperationQueue
  
  init(spanExporter: SpanExporter, scheduleDelay: TimeInterval, exportTimeout: TimeInterval, maxQueueSize: Int, maxExportBatchSize: Int, willExportCallback: ((inout [SpanData]) -> Void)?) {
    self.spanExporter = spanExporter
    self.scheduleDelay = scheduleDelay
    self.exportTimeout = exportTimeout
    self.maxQueueSize = maxQueueSize
    halfMaxQueueSize = maxQueueSize >> 1
    self.maxExportBatchSize = maxExportBatchSize
    self.willExportCallback = willExportCallback
    queue = OperationQueue()
    queue.name = "BatchWorker Queue"
    queue.maxConcurrentOperationCount = 1
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
      autoreleasepool {
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
        self.exportBatch(spanList: spansCopy, explicitTimeout: self.exportTimeout)
      }
    } while true
  }
  
  func shutdown() {
    forceFlush(explicitTimeout: self.exportTimeout)
    spanExporter.shutdown()
  }
  
  public func forceFlush(explicitTimeout: TimeInterval? = nil) {
    var spansCopy: [ReadableSpan]
    cond.lock()
    spansCopy = spanList
    spanList.removeAll()
    cond.unlock()
    // Execute the batch export outside the synchronized to not block all producers.
    exportBatch(spanList: spansCopy, explicitTimeout: explicitTimeout)
  }
  
  private func exportBatch(spanList: [ReadableSpan], explicitTimeout: TimeInterval? = nil) {
    let maxTimeOut = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, exportTimeout)
    let exportOperation = BlockOperation { [weak self] in
      self?.exportAction(spanList: spanList, explicitTimeout: maxTimeOut)
    }
    let timeoutTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
    timeoutTimer.setEventHandler {
      exportOperation.cancel()
    }
    
    timeoutTimer.schedule(deadline: .now() + .milliseconds(Int(maxTimeOut.toMilliseconds)), leeway: .milliseconds(1))
    timeoutTimer.activate()
    queue.addOperation(exportOperation)
    queue.waitUntilAllOperationsAreFinished()
    timeoutTimer.cancel()
  }
  
  private func exportAction(spanList: [ReadableSpan], explicitTimeout: TimeInterval? = nil) {
    stride(from: 0, to: spanList.endIndex, by: maxExportBatchSize).forEach {
      var spansToExport = spanList[$0 ..< min($0 + maxExportBatchSize, spanList.count)].map { $0.toSpanData() }
      willExportCallback?(&spansToExport)
      spanExporter.export(spans: spansToExport, explicitTimeout: explicitTimeout)
    }
  }
}

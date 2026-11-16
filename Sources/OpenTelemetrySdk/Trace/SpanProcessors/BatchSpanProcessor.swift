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
  fileprivate static let SPAN_PROCESSOR_TYPE_LABEL: String = "processorType"
  fileprivate static let SPAN_PROCESSOR_DROPPED_LABEL: String = "dropped"
  fileprivate static let SPAN_PROCESSOR_TYPE_VALUE: String = BatchSpanProcessor.name

  fileprivate var worker: BatchWorker

  public static var name: String {
    String(describing: Self.self)
  }

  let safeScheduleDelay: TimeInterval
  let safeExportTimeout: TimeInterval
  let safeMaxQueueSize: Int
  let safeMaxExportBatchSize: Int

  public init(spanExporter: SpanExporter,
              meterProvider: (any MeterProvider)? = nil,
              scheduleDelay: TimeInterval = 5,
              exportTimeout: TimeInterval = 30,
              maxQueueSize: Int = 2048,
              maxExportBatchSize: Int = 512,
              willExportCallback: ((inout [SpanData]) -> Void)? = nil) {
    if scheduleDelay >= 0 {
      safeScheduleDelay = scheduleDelay
    } else {
      print("scheduleDelay (\(scheduleDelay)) < 0, fallback to default 5.")
      safeScheduleDelay = 5
    }
    if exportTimeout >= 0 {
      safeExportTimeout = exportTimeout
    } else {
      print("exportTimeout (\(exportTimeout)) < 0, fallback to default 30.")
      safeExportTimeout = 30
    }
    if maxQueueSize > 0 {
      safeMaxQueueSize = maxQueueSize
    } else {
      print("maxQueueSize (\(maxQueueSize)) <= 0, fallback to default 2048.")
      safeMaxQueueSize = 2048
    }
    if maxExportBatchSize > 0 {
      safeMaxExportBatchSize = maxExportBatchSize
    } else {
      print("maxExportBatchSize (\(maxExportBatchSize)) <= 0, fallback to default 512.")
      safeMaxExportBatchSize = 512
    }

    worker = BatchWorker(spanExporter: spanExporter,
                         meterProvider: meterProvider,
                         scheduleDelay: safeScheduleDelay,
                         exportTimeout: safeExportTimeout,
                         maxQueueSize: safeMaxQueueSize,
                         maxExportBatchSize: safeMaxExportBatchSize,
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
private class BatchWorker: WorkerThread, @unchecked Sendable {
  let spanExporter: SpanExporter
  let meterProvider: (any MeterProvider)?
  let scheduleDelay: TimeInterval
  let maxQueueSize: Int
  let exportTimeout: TimeInterval
  let maxExportBatchSize: Int
  let willExportCallback: ((inout [SpanData]) -> Void)?
  let halfMaxQueueSize: Int
  private let cond = NSCondition()
  var spanList = [ReadableSpan]()
  var queue: OperationQueue

  private var queueSizeGauge: ObservableLongGauge?
  private var spanGaugeObserver: ObservableLongGauge?
  private var processedSpansCounter: LongCounter?

  init(spanExporter: SpanExporter,
       meterProvider: (any MeterProvider)? = nil,
       scheduleDelay: TimeInterval,
       exportTimeout: TimeInterval,
       maxQueueSize: Int,
       maxExportBatchSize: Int,
       willExportCallback: ((inout [SpanData]) -> Void)?) {
    self.spanExporter = spanExporter
    self.meterProvider = meterProvider
    self.scheduleDelay = scheduleDelay
    self.exportTimeout = exportTimeout
    self.maxQueueSize = maxQueueSize
    halfMaxQueueSize = maxQueueSize >> 1
    self.maxExportBatchSize = maxExportBatchSize
    self.willExportCallback = willExportCallback
    queue = OperationQueue()
    queue.name = "BatchWorker Queue"
    queue.maxConcurrentOperationCount = 1

    if let meter = meterProvider?.meterBuilder(name: "io.opentelemetry.sdk.trace").build() {
      var longGaugeSdk = meter.gaugeBuilder(name: "queueSize").ofLongs() as? LongGaugeBuilderSdk
      longGaugeSdk = longGaugeSdk?.setDescription("The number of items queued")
      longGaugeSdk = longGaugeSdk?.setUnit("1")
      queueSizeGauge = longGaugeSdk?.buildWithCallback { result in
        result.record(value: maxQueueSize,
                      attributes: [
                        BatchSpanProcessor.SPAN_PROCESSOR_TYPE_LABEL: .string(BatchSpanProcessor.SPAN_PROCESSOR_TYPE_VALUE)
                      ])
      }

      var longCounterSdk = meter.counterBuilder(name: "processedSpans") as? LongCounterMeterBuilderSdk
      longCounterSdk = longCounterSdk?.setUnit("1")
      longCounterSdk = longCounterSdk?.setDescription("The number of spans processed by the BatchSpanProcessor. [dropped=true if they were dropped due to high throughput]")
      processedSpansCounter = longCounterSdk?.build()

      // Subscribe to new gauge observer
      spanGaugeObserver = meter.gaugeBuilder(name: "spanSize")
        .ofLongs()
        .buildWithCallback { [count = spanList.count] result in
          result.record(value: count,
                        attributes: [
                          BatchSpanProcessor.SPAN_PROCESSOR_TYPE_LABEL: .string(BatchSpanProcessor.SPAN_PROCESSOR_TYPE_VALUE)
                        ])
        }
    }
  }

  deinit {
    // Cleanup all gauge observer
    self.queueSizeGauge?.close()
    self.spanGaugeObserver?.close()
  }

  func addSpan(span: ReadableSpan) {
    cond.lock()
    defer { cond.unlock() }

    if spanList.count == maxQueueSize {
      processedSpansCounter?.add(value: 1, attributes: [
        BatchSpanProcessor.SPAN_PROCESSOR_TYPE_LABEL: .string(BatchSpanProcessor.SPAN_PROCESSOR_TYPE_VALUE),
        BatchSpanProcessor.SPAN_PROCESSOR_DROPPED_LABEL: .bool(true)
      ])
      return
    }
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
            _ = cond.wait(until: Date().addingTimeInterval(scheduleDelay))
          } while spanList.isEmpty && !self.isCancelled
        }
        spansCopy = spanList
        spanList.removeAll()
        cond.unlock()
        self.exportBatch(spanList: spansCopy, explicitTimeout: self.exportTimeout)
      }
    } while !isCancelled
  }

  func shutdown() {
    forceFlush(explicitTimeout: exportTimeout)
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
    timeoutTimer.setCancelHandler {
      // Cancel handler ensures the dispatch source is properly deallocated
      // and prevents double-release of the event handler block
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
      let result = spanExporter.export(spans: spansToExport, explicitTimeout: explicitTimeout)
      if result == .success {
        cond.lock()
        processedSpansCounter?.add(value: spanList.count, attributes: [
          BatchSpanProcessor.SPAN_PROCESSOR_TYPE_LABEL: .string(BatchSpanProcessor.SPAN_PROCESSOR_TYPE_VALUE),
          BatchSpanProcessor.SPAN_PROCESSOR_DROPPED_LABEL: .bool(false)
        ])
        cond.unlock()
      }
    }
  }
}

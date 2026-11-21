/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if OTLPGRPC

import Foundation
import Synchronization

private let otlpGrpcExecutorQueueLabel = "io.opentelemetry.otlp-grpc.blocking"

/// Runs the bridged operations, the owned clients' connections and their child tasks on a dispatch
/// queue instead of Swift's cooperative thread pool. Unstructured tasks they start and `Task.sleep`
/// timers still use the pool.
///
/// The queue is serial on purpose: a serial queue gets a thread even when blocked callers occupy
/// every cooperative thread, while a concurrent queue draws on the same limited threads and
/// starves with the pool.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
final class OtlpGrpcTaskExecutor: TaskExecutor, Sendable {
  private let queue = DispatchQueue(label: otlpGrpcExecutorQueueLabel)
  private let queueKey = DispatchSpecificKey<Void>()

  init() {
    queue.setSpecific(key: queueKey, value: ())
  }

  /// Whether the caller runs on this executor's queue.
  var isCurrent: Bool {
    DispatchQueue.getSpecific(key: queueKey) != nil
  }

  func enqueue(_ job: consuming ExecutorJob) {
    let unownedJob = UnownedJob(job)
    queue.async {
      unownedJob.runSynchronously(on: self.asUnownedTaskExecutor())
    }
  }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
let otlpGrpcTaskExecutor = OtlpGrpcTaskExecutor()

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
private final class BlockingResult<T: Sendable>: Sendable {
  let value = Mutex<T?>(nil)
}

/// Runs `operation` to completion and blocks the calling thread until it finishes.
///
/// The exporter protocols are synchronous, while grpc-swift-2 is async only. `operation` runs on
/// ``otlpGrpcTaskExecutor``, so callers that block every cooperative thread, such as a processor
/// exporting inline from async code, can't starve it.
///
/// gRPC enforces deadlines with Swift concurrency timers, which those callers can starve. So once
/// `timeout` passes, this cancels `operation` and returns the result it finishes with.
///
/// Called from that executor's own queue, it couldn't wait without blocking `operation`, so it
/// returns `fallback` at once.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
func otlpGrpcBlocking<T: Sendable>(timeout: TimeInterval?,
                                   whenCalledFromExecutor fallback: T,
                                   _ operation: @escaping @Sendable () async -> T) -> T {
  guard !otlpGrpcTaskExecutor.isCurrent else {
    return fallback
  }
  let semaphore = DispatchSemaphore(value: 0)
  let result = BlockingResult<T>()
  let task = Task(executorPreference: otlpGrpcTaskExecutor) {
    let value = await operation()
    result.value.withLock { $0 = value }
    semaphore.signal()
  }
  let deadline = timeout.map { DispatchTime.now() + $0 } ?? .distantFuture
  if semaphore.wait(timeout: deadline) == .timedOut {
    task.cancel()
    semaphore.wait()
  }
  return result.value.withLock { $0! }
}

#endif

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if OTLPGRPC

import Foundation
import Synchronization

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
private final class BlockingResult<T: Sendable>: Sendable {
  let value = Mutex<T?>(nil)
}

/// Runs `operation` to completion and blocks the calling thread until it finishes.
///
/// The exporter protocols are synchronous, while grpc-swift 2 is async only.
/// This must not be called from Swift concurrency: it blocks its thread, and doing that
/// on the cooperative pool can starve the task that would unblock it.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
func otlpGrpcBlocking<T: Sendable>(_ operation: @escaping @Sendable () async -> T) -> T {
  let semaphore = DispatchSemaphore(value: 0)
  let result = BlockingResult<T>()
  Task {
    let value = await operation()
    result.value.withLock { $0 = value }
    semaphore.signal()
  }
  semaphore.wait()
  return result.value.withLock { $0! }
}

#endif

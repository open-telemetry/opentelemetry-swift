//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

struct OtlpHttpExportTimeoutError: Error {}

func sendWithTimeout(httpClient: HTTPClient,
                     timeout: TimeInterval,
                     request: URLRequest) async -> Result<HTTPURLResponse, Error> {
  if timeout == .greatestFiniteMagnitude {
    do {
      return .success(try await httpClient.send(request: request))
    } catch {
      return .failure(error)
    }
  }

  return await withCheckedContinuation { continuation in
    let gate = SendResultGate()
    let clientBox = HTTPClientBox(httpClient)
    let sendTask = Task {
      do {
        let response = try await clientBox.client.send(request: request)
        gate.complete(with: .success(response), continuation: continuation)
      } catch {
        gate.complete(with: .failure(error), continuation: continuation)
      }
    }
    Task {
      do {
        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
      } catch {
        return
      }
      sendTask.cancel()
      gate.complete(with: .failure(OtlpHttpExportTimeoutError()), continuation: continuation)
    }
  }
}

private final class HTTPClientBox: @unchecked Sendable {
  let client: HTTPClient
  init(_ client: HTTPClient) { self.client = client }
}

private final class SendResultGate: @unchecked Sendable {
  private let lock = Lock()
  private var completed = false

  func complete(with result: Result<HTTPURLResponse, Error>,
                continuation: CheckedContinuation<Result<HTTPURLResponse, Error>, Never>) {
    lock.withLockVoid {
      guard !completed else { return }
      completed = true
      continuation.resume(returning: result)
    }
  }
}

func waitSynchronously<R>(timeout: TimeInterval,
                          operation: @Sendable @escaping () async -> R) -> R? {
  let semaphore = DispatchSemaphore(value: 0)
  let resultBox = WaitResultBox<R>()
  Task.detached {
    resultBox.value = await operation()
    semaphore.signal()
  }
  let waitResult = semaphore.wait(timeout: .now() + timeout)
  if waitResult == .timedOut {
    return nil
  }
  return resultBox.value
}

private final class WaitResultBox<R>: @unchecked Sendable {
  var value: R?
}

final class PendingQueue<Item>: @unchecked Sendable {
  private var items: [Item] = []
  private let lock = Lock()

  func enqueueAndTakeAll(_ incoming: [Item]) -> [Item] {
    lock.withLock {
      items.append(contentsOf: incoming)
      let batch = items
      items = []
      return batch
    }
  }

  func requeue(_ batch: [Item]) {
    lock.withLockVoid {
      items.append(contentsOf: batch)
    }
  }

  func snapshot() -> [Item] {
    lock.withLock {
      items
    }
  }

  func dropPrefix(_ count: Int) {
    lock.withLockVoid {
      let n = min(count, items.count)
      items.removeFirst(n)
    }
  }
}

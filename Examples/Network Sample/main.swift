/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import StdoutExporter
import URLSessionInstrumentation

func simpleNetworkCall() {
  let url = URL(string: "http://httpbin.org/get")!
  let request = URLRequest(url: url)
  let semaphore = DispatchSemaphore(value: 0)

  let task = URLSession.shared.dataTask(with: request) { data, _, _ in
    if let data {
      let string = String(bytes: data, encoding: .utf8)
      print(string as Any)
    }
    semaphore.signal()
  }
  task.resume()

  semaphore.wait()
}

class SessionDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
  let semaphore = DispatchSemaphore(value: 0)
  var callCount = 0

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    semaphore.signal()
  }

  func urlSession(_ session: URLSession,
                  task: URLSessionTask,
                  didFinishCollecting metrics: URLSessionTaskMetrics) {
    semaphore.signal()
    callCount += 1
    print("delegate called")
  }
}

let delegate = SessionDelegate()

enum TimeoutError: Error {
  case timeout
}

func waitForSemaphore(withTimeoutSecs: Int) async {
  do {
    _ = try await withThrowingTaskGroup(of: Bool.self) { group in
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(withTimeoutSecs) * NSEC_PER_SEC)
        throw TimeoutError.timeout
      }
      group.addTask {
        let semaphoreTask = Task {
          DispatchQueue.global().async {
            delegate.semaphore.wait()
          }
        }
        await semaphoreTask.value
        try Task.checkCancellation()
        return true
      }

      return try await group.next()!
    }
  } catch {
    print("timed out waiting for semaphore")
  }
}

func simpleNetworkCallWithDelegate() {
  let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

  let url = URL(string: "http://httpbin.org/get")!
  let request = URLRequest(url: url)

  let task = session.dataTask(with: request)
  task.resume()

  delegate.semaphore.wait()
}

@available(macOS 10.15, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
func asyncNetworkCallWithTaskDelegate() async {
  let session = URLSession(configuration: .default)

  let url = URL(string: "http://httpbin.org/get")!
  let request = URLRequest(url: url)

  do {
    _ = try await session.data(for: request, delegate: delegate)
  } catch {
    return
  }

  await waitForSemaphore(withTimeoutSecs: 3)
}

@available(macOS 10.15, iOS 15.0, tvOS 13.0, *)
func asyncNetworkCallWithSessionDelegate() async {
  let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

  let url = URL(string: "http://httpbin.org/get")!
  let request = URLRequest(url: url)

  do {
    _ = try await session.data(for: request)
  } catch {
    return
  }

  await waitForSemaphore(withTimeoutSecs: 3)
}

let spanProcessor = SimpleSpanProcessor(spanExporter: StdoutSpanExporter(isDebug: true))
OpenTelemetry.registerTracerProvider(tracerProvider:
  TracerProviderBuilder()
    .add(spanProcessor: spanProcessor)
    .build()
)

let networkInstrumentation = URLSessionInstrumentation(configuration: URLSessionInstrumentationConfiguration())

print("making simple call")
var callCount = delegate.callCount
simpleNetworkCallWithDelegate()
assert(delegate.callCount == callCount + 1)

if #available(macOS 10.15, iOS 15.0, watchOS 8.0, tvOS 15.0, *) {
  print("making simple call with task delegate")
  callCount = delegate.callCount
  await asyncNetworkCallWithTaskDelegate()
  assert(delegate.callCount == callCount + 1, "async task delegate not called")

  print("making simple call with session delegate")
  callCount = delegate.callCount
  await asyncNetworkCallWithSessionDelegate()
  assert(delegate.callCount == callCount + 1, "async session delegate not called")
}

sleep(1)

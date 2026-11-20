/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if OTLPGRPC

import Foundation
import GRPCCore
import Synchronization

/// Resumes its continuation once, however many racing tasks call `resume()`.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
private final class PendingContinuation: Sendable {
  private let continuation: Mutex<CheckedContinuation<Void, Never>?>

  init(_ continuation: CheckedContinuation<Void, Never>) {
    self.continuation = Mutex(continuation)
  }

  func resume() {
    let pending = continuation.withLock { continuation in
      let pending = continuation
      continuation = nil
      return pending
    }
    pending?.resume()
  }
}

/// Owns the lifecycle of the gRPC client behind an exporter.
///
/// An exporter that owns its client runs the client's connections and stops it on shutdown.
/// An exporter that doesn't own its client only stops sending, so the caller keeps control of it.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
final class OtlpGrpcConnection: Sendable {
  private let shutdownState = Mutex(false)
  private let ownsClient: Bool
  private let beginGracefulShutdown: @Sendable () -> Void
  private let runTask: Task<Void, Never>?

  init<Transport: ClientTransport>(client: GRPCClient<Transport>, ownsClient: Bool) {
    self.ownsClient = ownsClient
    beginGracefulShutdown = { client.beginGracefulShutdown() }
    if ownsClient {
      runTask = Task { try? await client.runConnections() }
    } else {
      runTask = nil
    }
  }

  deinit {
    if ownsClient {
      beginGracefulShutdown()
    }
  }

  var isShutdown: Bool {
    shutdownState.withLock { $0 }
  }

  func shutdown() {
    let wasShutdown = shutdownState.withLock { isShutdown in
      let previous = isShutdown
      isShutdown = true
      return previous
    }
    if !wasShutdown, ownsClient {
      beginGracefulShutdown()
    }
  }

  /// Shuts down, then waits for an owned client to stop its connections.
  ///
  /// If the client is still running after `timeout`, its connections are cancelled.
  /// A `nil`, non-finite or very large timeout waits for in-flight calls to finish.
  func shutdown(timeout: TimeInterval?) async {
    shutdown()
    guard let runTask else { return }
    guard let timeout, timeout.isFinite, timeout < maximumDeadlineSeconds else {
      await runTask.value
      return
    }

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      let pending = PendingContinuation(continuation)
      let resume: @Sendable () -> Void = { pending.resume() }
      let timer = Task {
        do {
          try await Task.sleep(for: .seconds(timeout))
        } catch {
          return
        }
        runTask.cancel()
        resume()
      }
      Task {
        await runTask.value
        timer.cancel()
        resume()
      }
    }
  }
}

#endif

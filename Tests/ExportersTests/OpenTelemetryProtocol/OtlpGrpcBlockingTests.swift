/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if OTLPGRPC

import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetryProtocolExporterGrpc
@testable import OpenTelemetrySdk
import Synchronization
import XCTest

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
private let serverExecutor = DispatchQueueTaskExecutor(label: "io.opentelemetry.otlp-grpc.blocking-tests.server")

/// A serial queue, because a concurrent one draws on the same limited threads as the cooperative
/// pool and starves with it.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
private final class DispatchQueueTaskExecutor: TaskExecutor, Sendable {
  private let queue: DispatchQueue

  init(label: String) {
    queue = DispatchQueue(label: label)
  }

  func enqueue(_ job: consuming ExecutorJob) {
    let unownedJob = UnownedJob(job)
    queue.async {
      unownedJob.runSynchronously(on: self.asUnownedTaskExecutor())
    }
  }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
final class OtlpGrpcBlockingTests: XCTestCase {
  /// The test thread blocks on expectations instead of awaiting, and the collector runs off the
  /// cooperative pool. Both keep a deadlocked pool from also hanging the setup, the teardown and
  /// the collector, so a failing test returns instead of hanging the suite.
  func testSyncExportFromCooperativePoolDoesNotDeadlock() throws {
    let fakeCollector = FakeTraceCollector()
    let server = try XCTUnwrap(runBlockingTestStep {
      try await OtlpGrpcTestServer(service: fakeCollector, executorPreference: serverExecutor)
    })
    let exporter = try OtlpTraceExporter(transport: server.makeClientTransport(), envVarHeaders: nil)
    let concurrentExports = max(4, ProcessInfo.processInfo.activeProcessorCount * 2)
    let results = Mutex([SpanExporterResultCode]())
    let allFinished = expectation(description: "Every sync export from a cooperative thread returned")
    allFinished.expectedFulfillmentCount = concurrentExports

    for _ in 0 ..< concurrentExports {
      let span = makeSpan()
      Task { @Sendable in
        let result = exportBlocking(exporter, span)
        results.withLock { $0.append(result) }
        allFinished.fulfill()
      }
    }

    let waitResult = XCTWaiter().wait(for: [allFinished], timeout: 20)

    XCTAssertEqual(waitResult, .completed)
    XCTAssertEqual(results.withLock { $0 }, Array(repeating: .success, count: concurrentExports))
    XCTAssertEqual(fakeCollector.requestCount, concurrentExports)
    if waitResult == .completed {
      exporter.shutdown()
      runBlockingTestStep { await server.stop() }
    }
  }

  /// Like the test above, but every export starts only once all cooperative threads are blocked,
  /// so the pool can't pass by running the exports one after another.
  func testSyncExportFromSaturatedCooperativePoolDoesNotDeadlock() throws {
    let fakeCollector = FakeTraceCollector()
    let server = try XCTUnwrap(runBlockingTestStep {
      try await OtlpGrpcTestServer(service: fakeCollector, executorPreference: serverExecutor)
    })
    let exporter = try OtlpTraceExporter(transport: server.makeClientTransport(), envVarHeaders: nil)
    let concurrentExports = saturatingTaskCount
    let results = Mutex([SpanExporterResultCode]())
    let allFinished = expectation(description: "Every sync export from a saturated pool returned")
    allFinished.expectedFulfillmentCount = concurrentExports

    let blockedThreads = runOnSaturatedCooperativePool(taskCount: concurrentExports) { [span = makeSpan()] in
      let result = exportBlocking(exporter, span)
      results.withLock { $0.append(result) }
      allFinished.fulfill()
    }

    let waitResult = XCTWaiter().wait(for: [allFinished], timeout: 20)

    XCTAssertGreaterThan(blockedThreads, 0)
    XCTAssertLessThan(blockedThreads, concurrentExports, "The pool was never saturated")
    XCTAssertEqual(waitResult, .completed)
    XCTAssertEqual(results.withLock { $0 }, Array(repeating: .success, count: concurrentExports))
    XCTAssertEqual(fakeCollector.requestCount, concurrentExports)
    if waitResult == .completed {
      exporter.shutdown()
      runBlockingTestStep { await server.stop() }
    }
  }

  /// An owned client's connections are driven by a task the exporter starts. That task must not
  /// need a cooperative thread either. The exporter is created at the saturated tasks' priority,
  /// because a task started at another priority could still get a thread.
  func testSyncExportThroughExporterCreatedOnSaturatedCooperativePoolDoesNotDeadlock() throws {
    let fakeCollector = FakeTraceCollector()
    let server = try XCTUnwrap(runBlockingTestStep {
      try await OtlpGrpcTestServer(service: fakeCollector, executorPreference: serverExecutor)
    })
    let transport = try server.makeClientTransport()
    let exporter = Mutex<OtlpTraceExporter?>(nil)
    let concurrentExports = saturatingTaskCount
    let results = Mutex([SpanExporterResultCode]())
    let allFinished = expectation(description: "Every sync export through the new exporter returned")
    allFinished.expectedFulfillmentCount = concurrentExports

    let blockedThreads = runOnSaturatedCooperativePool(taskCount: concurrentExports, whileSaturated: {
      runOnDefaultQoSThread {
        exporter.withLock { $0 = OtlpTraceExporter(transport: transport, envVarHeaders: nil) }
      }
    }, body: { [span = makeSpan()] in
      let result = exportBlocking(exporter.withLock { $0! }, span)
      results.withLock { $0.append(result) }
      allFinished.fulfill()
    })

    let waitResult = XCTWaiter().wait(for: [allFinished], timeout: 20)

    XCTAssertGreaterThan(blockedThreads, 0)
    XCTAssertLessThan(blockedThreads, concurrentExports, "The pool was never saturated")
    XCTAssertEqual(waitResult, .completed)
    XCTAssertEqual(results.withLock { $0 }, Array(repeating: .success, count: concurrentExports))
    XCTAssertEqual(fakeCollector.requestCount, concurrentExports)
    if waitResult == .completed {
      exporter.withLock { $0?.shutdown() }
      runBlockingTestStep { await server.stop() }
    }
  }

  /// gRPC enforces its deadline with a Swift concurrency timer, which can't fire while every
  /// cooperative thread at the callers' priority is blocked, so the sync export must enforce its
  /// timeout itself. The short timeout keeps the test quick when the pool has a single thread and
  /// the exports run one after another.
  func testSyncExportFromSaturatedCooperativePoolTimesOutAgainstHungCollector() throws {
    let hungCollector = HungTraceCollector()
    let server = try XCTUnwrap(runBlockingTestStep {
      try await OtlpGrpcTestServer(service: hungCollector, executorPreference: serverExecutor)
    })
    let exporter = try OtlpTraceExporter(transport: server.makeClientTransport(),
                                         config: OtlpConfiguration(timeout: 0.1),
                                         envVarHeaders: nil)
    let concurrentExports = saturatingTaskCount
    let results = Mutex([SpanExporterResultCode]())
    let allFinished = expectation(description: "Every sync export against a hung collector timed out")
    allFinished.expectedFulfillmentCount = concurrentExports

    let blockedThreads = runOnSaturatedCooperativePool(taskCount: concurrentExports) { [span = makeSpan()] in
      let result = exportBlocking(exporter, span)
      results.withLock { $0.append(result) }
      allFinished.fulfill()
    }

    let waitResult = XCTWaiter().wait(for: [allFinished], timeout: 20)

    XCTAssertGreaterThan(blockedThreads, 0)
    XCTAssertLessThan(blockedThreads, concurrentExports, "The pool was never saturated")
    XCTAssertEqual(waitResult, .completed)
    XCTAssertEqual(results.withLock { $0 }, Array(repeating: .failure, count: concurrentExports))
    hungCollector.release()
    if waitResult == .completed {
      exporter.shutdown()
      runBlockingTestStep { await server.stop() }
    }
  }

  /// A sync export called from a job on the exporters' own executor can't wait for an operation that
  /// needs that same executor, so it must fail at once instead of hanging.
  func testSyncExportFromExporterExecutorFailsInsteadOfHanging() throws {
    let fakeCollector = FakeTraceCollector()
    let server = try XCTUnwrap(runBlockingTestStep {
      try await OtlpGrpcTestServer(service: fakeCollector, executorPreference: serverExecutor)
    })
    let exporter = try OtlpTraceExporter(transport: server.makeClientTransport(),
                                         config: OtlpConfiguration(timeout: 0.1),
                                         envVarHeaders: nil)
    let result = Mutex<SpanExporterResultCode?>(nil)
    let finished = expectation(description: "The sync export on the exporters' executor returned")

    Task(executorPreference: otlpGrpcTaskExecutor) { [span = makeSpan()] in
      let exportResult = exportBlocking(exporter, span)
      result.withLock { $0 = exportResult }
      finished.fulfill()
    }

    let waitResult = XCTWaiter().wait(for: [finished], timeout: 20)

    XCTAssertEqual(waitResult, .completed)
    XCTAssertEqual(result.withLock { $0 }, .failure)
    XCTAssertEqual(fakeCollector.requestCount, 0)
    if waitResult == .completed {
      exporter.shutdown()
      runBlockingTestStep { await server.stop() }
    }
  }

  /// Every exporter's sync exports share one serial executor. A headers provider that blocks must
  /// only hold up its own caller, so it has to run before the export enters that executor.
  func testBlockingHeadersProviderDoesNotHoldUpOtherExportersSyncExports() throws {
    let fakeCollector = FakeTraceCollector()
    let server = try XCTUnwrap(runBlockingTestStep {
      try await OtlpGrpcTestServer(service: fakeCollector, executorPreference: serverExecutor)
    })
    let providerEntered = DispatchSemaphore(value: 0)
    let providerGate = DispatchSemaphore(value: 0)
    let blockingConfig = OtlpConfiguration(headersProvider: {
      providerEntered.signal()
      providerGate.wait()
      return nil
    })
    let blockedExporter = try OtlpTraceExporter(transport: server.makeClientTransport(),
                                                config: blockingConfig,
                                                envVarHeaders: nil)
    let otherExporter = try OtlpTraceExporter(transport: server.makeClientTransport(), envVarHeaders: nil)
    let blockedResult = Mutex<SpanExporterResultCode?>(nil)
    let otherResult = Mutex<SpanExporterResultCode?>(nil)
    let blockedFinished = DispatchSemaphore(value: 0)
    let otherFinished = DispatchSemaphore(value: 0)

    Thread { [span = makeSpan()] in
      let result = exportBlocking(blockedExporter, span)
      blockedResult.withLock { $0 = result }
      blockedFinished.signal()
    }.start()
    let providerWaitResult = providerEntered.wait(timeout: .now() + 20)
    Thread { [span = makeSpan()] in
      let result = exportBlocking(otherExporter, span)
      otherResult.withLock { $0 = result }
      otherFinished.signal()
    }.start()

    let otherWaitResult = otherFinished.wait(timeout: .now() + 5)
    providerGate.signal()
    let blockedWaitResult = blockedFinished.wait(timeout: .now() + 20)
    let lateOtherWaitResult = otherWaitResult == .success ? .success : otherFinished.wait(timeout: .now() + 20)

    XCTAssertEqual(providerWaitResult, .success)
    XCTAssertEqual(otherWaitResult, .success, "The other exporter waited for the blocking headers provider")
    XCTAssertEqual(otherResult.withLock { $0 }, .success)
    XCTAssertEqual(blockedWaitResult, .success)
    XCTAssertEqual(blockedResult.withLock { $0 }, .success)
    XCTAssertEqual(fakeCollector.requestCount, 2)
    if blockedWaitResult == .success, lateOtherWaitResult == .success {
      blockedExporter.shutdown()
      otherExporter.shutdown()
      runBlockingTestStep { await server.stop() }
    }
  }

  /// More tasks than the cooperative pool can have threads, with room to spare in case the pool is
  /// sized from a different processor count than `activeProcessorCount`.
  private var saturatingTaskCount: Int {
    max(8, 4 * ProcessInfo.processInfo.activeProcessorCount)
  }

  /// Starts `taskCount` tasks that each block a cooperative thread until no more of them can start,
  /// calls `whileSaturated` on the test thread, then runs `body` in every task, the blocked ones first.
  ///
  /// Returns how many tasks were blocked when they were released. Fewer than `taskCount` means
  /// every cooperative thread was blocked at that moment.
  ///
  /// The tasks run at medium priority, the default off the main thread. Blocking only threads of
  /// another priority can leave Swift concurrency timers free to fire, which would hide the problem.
  private func runOnSaturatedCooperativePool(taskCount: Int,
                                             whileSaturated: () -> Void = {},
                                             body: @escaping @Sendable () -> Void) -> Int {
    let barrier = Mutex((arrived: 0, released: false))
    for _ in 0 ..< taskCount {
      Task(priority: .medium) { @Sendable in
        barrier.withLock { $0.arrived += 1 }
        while !barrier.withLock({ $0.released }) {
          usleep(1000)
        }
        body()
      }
    }

    let giveUp = Date().addingTimeInterval(20)
    var lastArrived = 0
    var lastArrival = Date()
    while Date() < giveUp {
      let arrived = barrier.withLock { $0.arrived }
      if arrived == taskCount {
        break
      }
      if arrived > lastArrived {
        lastArrived = arrived
        lastArrival = Date()
      } else if arrived > 0, Date().timeIntervalSince(lastArrival) > 1 {
        break
      }
      usleep(10000)
    }
    whileSaturated()
    return barrier.withLock { barrier in
      barrier.released = true
      return barrier.arrived
    }
  }

  private func runOnDefaultQoSThread(_ body: @escaping @Sendable () -> Void) {
    let finished = DispatchSemaphore(value: 0)
    let thread = Thread {
      body()
      finished.signal()
    }
    thread.qualityOfService = .default
    thread.start()
    finished.wait()
  }

  private func runBlockingTestStep<T: Sendable>(_ step: @escaping @Sendable () async throws -> T) -> T? {
    let finished = expectation(description: "Test step finished")
    let outcome = Mutex<T?>(nil)
    Task {
      do {
        let value = try await step()
        outcome.withLock { $0 = value }
      } catch {
        XCTFail("Test step failed: \(error)")
      }
      finished.fulfill()
    }
    XCTWaiter().wait(for: [finished], timeout: 20)
    return outcome.withLock { $0 }
  }

  private func makeSpan() -> SpanData {
    let start = Date()
    var span = SpanData(traceId: TraceId(fromHexString: "00000000000000000000000000abc123"),
                        spanId: SpanId(fromHexString: "0000000000def456"),
                        name: "GET /api/endpoint",
                        kind: SpanKind.server,
                        startTime: start,
                        endTime: start.addingTimeInterval(0.9))
    span.settingHasEnded(true)
    span.settingTotalRecordedEvents(0)
    span.settingLinks([SpanData.Link]())
    span.settingTotalRecordedLinks(0)
    span.settingStatus(.ok)
    return span
  }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
private func exportBlocking(_ exporter: OtlpTraceExporter, _ span: SpanData) -> SpanExporterResultCode {
  exporter.export(spans: [span])
}

/// Accepts every export and never answers until released.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
private final class HungTraceCollector: Opentelemetry_Proto_Collector_Trace_V1_TraceService.ServiceProtocol, Sendable {
  private let gate = Mutex((released: false, waiting: [CheckedContinuation<Void, Never>]()))

  func export(
    request: ServerRequest<Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest>,
    context: ServerContext
  ) async throws -> ServerResponse<Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse> {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      let released = gate.withLock { gate in
        if !gate.released {
          gate.waiting.append(continuation)
        }
        return gate.released
      }
      if released {
        continuation.resume()
      }
    }
    return ServerResponse(message: Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse())
  }

  func release() {
    let waiting = gate.withLock { gate in
      gate.released = true
      let waiting = gate.waiting
      gate.waiting = []
      return waiting
    }
    for continuation in waiting {
      continuation.resume()
    }
  }
}

#endif

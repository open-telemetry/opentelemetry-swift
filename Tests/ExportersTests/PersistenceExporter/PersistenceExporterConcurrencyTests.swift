/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import InMemoryExporter
import OpenTelemetryApi
import OpenTelemetrySdk
@testable import PersistenceExporter
import SharedTestUtils
import XCTest

/// Stress tests for the persistence exporter and its file storage. They only
/// run under Thread Sanitizer (or with `OTEL_CONCURRENCY_TESTS=1`).
final class PersistenceExporterConcurrencyTests: XCTestCase {
  @UniqueTemporaryDirectory private var temporaryDirectory: Directory

  override func setUpWithError() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
    temporaryDirectory.create()
  }

  override func tearDown() {
    if ConcurrencyTesting.isEnabled {
      temporaryDirectory.delete()
    }
  }

  private func waitUntil(timeout: TimeInterval = 15, _ condition: () -> Bool) -> Bool {
    let deadline = Date(timeIntervalSinceNow: timeout)
    while Date() < deadline {
      if condition() { return true }
      Thread.sleep(forTimeInterval: 0.02)
    }
    return condition()
  }

  /// Files stop accepting writes well before they become readable, mirroring
  /// the production presets, so the worker never drains a file that is still
  /// being appended to.
  private static func storage(maxObjectsInFile: Int) -> StoragePerformanceMock {
    StoragePerformanceMock(maxFileSize: .max,
                           maxDirectorySize: .max,
                           maxFileAgeForWrite: 0.05,
                           minFileAgeForRead: 0.2,
                           maxFileAgeForRead: .distantFuture,
                           maxObjectsInFile: maxObjectsInFile,
                           maxObjectSize: .max)
  }

  private func drain(_ exporter: PersistenceSpanExporterDecorator, into sink: InMemoryExporter, expecting count: Int) {
    // Let the last file age past `minFileAgeForRead`, then flush and wait.
    Thread.sleep(forTimeInterval: 0.3)
    _ = exporter.flush(explicitTimeout: nil)
    let drained = waitUntil { sink.getFinishedSpanItems().count >= count }
    XCTAssertTrue(drained, "sink received \(sink.getFinishedSpanItems().count) of \(count) spans")
    XCTAssertEqual(sink.getFinishedSpanItems().count, count)
    exporter.shutdown(explicitTimeout: nil)
  }

  // MARK: - Decorator

  func testSpanExportsFromManyThreadsWhileWorkerDrainsStorage() {
    let sink = InMemoryExporter()
    let preset = PersistencePerformancePreset.mockWith(storagePerformance: Self.storage(maxObjectsInFile: .max),
                                                       synchronousWrite: false,
                                                       exportPerformance: ExportPerformanceMock.veryQuick)
    let exporter = PersistenceSpanExporterDecorator(spanExporter: sink,
                                                    storageURL: temporaryDirectory.url,
                                                    exportCondition: { true },
                                                    performancePreset: preset)
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = 50

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
      _ = exporter.export(spans: [TelemetryFixtures.spanData(name: "span-\(thread)-\(iteration)")], explicitTimeout: nil)
    }

    drain(exporter, into: sink, expecting: threads * iterations)
  }

  func testSynchronousWritesFromManyThreads() {
    let sink = InMemoryExporter()
    let preset = PersistencePerformancePreset.mockWith(storagePerformance: Self.storage(maxObjectsInFile: .max),
                                                       synchronousWrite: true,
                                                       exportPerformance: ExportPerformanceMock.veryQuick)
    let exporter = PersistenceSpanExporterDecorator(spanExporter: sink,
                                                    storageURL: temporaryDirectory.url,
                                                    exportCondition: { true },
                                                    performancePreset: preset)
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = 25

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
      _ = exporter.export(spans: [TelemetryFixtures.spanData(name: "span-\(thread)-\(iteration)")], explicitTimeout: nil)
    }

    drain(exporter, into: sink, expecting: threads * iterations)
  }

  // MARK: - Storage

  func testOrchestratorServesOneWriterAndManyReaders() throws {
    // Production has a single writer (the writer queue) racing a single
    // reader that deletes what it has read (the worker queue), plus whoever
    // lists the directory; that is the shape exercised here.
    let orchestrator = FilesOrchestrator(directory: temporaryDirectory,
                                         performance: Self.storage(maxObjectsInFile: .max),
                                         dateProvider: SystemDateProvider())
    let writeFailures = ConcurrentCounter()
    let readFailures = ConcurrentCounter()
    let readErrors = ConcurrentCollector<String>()
    let filesRead = ConcurrentCounter()
    let payload = Data(repeating: 0x41, count: 16)

    ConcurrencyTesting.stress(threads: ConcurrencyTesting.defaultThreads, iterations: 100) { thread, _ in
      if thread == 0 {
        do {
          let file = try orchestrator.getWritableFile(writeSize: UInt64(payload.count))
          try file.append(data: payload, synchronized: false)
        } catch {
          writeFailures.increment()
        }
        Thread.sleep(forTimeInterval: 0.002)
      } else if thread == 1 {
        if let readable = orchestrator.getReadableFile(excludingFilesNamed: []) {
          do {
            _ = try readable.read()
            orchestrator.delete(readableFile: readable)
            filesRead.increment()
          } catch {
            readFailures.increment()
            readErrors.append("\(readable.name): \(error)")
          }
        }
      } else {
        _ = orchestrator.getAllFiles(excludingFilesNamed: [])
        _ = orchestrator.getReadableFile(excludingFilesNamed: [])
      }
    }

    XCTAssertEqual(writeFailures.value, 0)
    XCTAssertEqual(readFailures.value, 0, readErrors.values.joined(separator: " | "))
  }

  func testFileWriterMixesAsyncAndSyncWritesFromManyThreads() throws {
    let orchestrator = FilesOrchestrator(directory: temporaryDirectory,
                                         performance: StoragePerformanceMock.writeAllObjectsToTheSameFile,
                                         dateProvider: RelativeDateProvider())
    let writer = OrchestratedFileWriter(orchestrator: orchestrator)
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = 50
    let payload = Data(repeating: 0x42, count: 8)

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
      switch thread % 3 {
      case 0: writer.write(data: payload)
      case 1: writer.writeSync(data: payload)
      default:
        writer.write(data: payload)
        if iteration.isMultiple(of: 10) { writer.flush() }
      }
    }

    writer.flush()
    let totalBytes = try temporaryDirectory.files().reduce(UInt64(0)) { try $0 + $1.size() }
    XCTAssertEqual(totalBytes, UInt64(threads * iterations * payload.count))
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import OpenTelemetrySdk
@testable import PersistenceExporter
import XCTest

final class PersistenceLogExporterDecoratorCoverageTests: XCTestCase {
  @UniqueTemporaryDirectory private var temporaryDirectory: Directory

  final class LogExporterMock: LogRecordExporter {
    let onExport: ([ReadableLogRecord]) -> ExportResult
    var shutdownCalled = false
    var flushCalled = false
    init(onExport: @escaping ([ReadableLogRecord]) -> ExportResult = { _ in .success }) {
      self.onExport = onExport
    }
    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
      onExport(logRecords)
    }
    func shutdown(explicitTimeout: TimeInterval?) { shutdownCalled = true }
    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
      flushCalled = true
      return .success
    }
  }

  override func setUp() {
    super.setUp()
    temporaryDirectory.create()
  }

  override func tearDown() {
    temporaryDirectory.delete()
    super.tearDown()
  }

  private func makeLogRecord(body: String) -> ReadableLogRecord {
    ReadableLogRecord(resource: Resource(),
                      instrumentationScopeInfo: InstrumentationScopeInfo(name: "scope"),
                      timestamp: Date(),
                      observedTimestamp: Date(),
                      spanContext: nil,
                      severity: .info,
                      body: .string(body),
                      attributes: [:])
  }

  func testExportDelegatesToPersistenceExporter() throws {
    let exportExpectation = expectation(description: "log record forwarded")
    exportExpectation.assertForOverFulfill = false

    let inner = LogExporterMock { records in
      if records.contains(where: { $0.body == .string("hello") }) {
        exportExpectation.fulfill()
      }
      return .success
    }

    let decorator = try PersistenceLogExporterDecorator(
      logRecordExporter: inner,
      storageURL: temporaryDirectory.url,
      exportCondition: { true },
      performancePreset: PersistencePerformancePreset.mockWith(
        storagePerformance: StoragePerformanceMock.writeEachObjectToNewFileAndReadAllFiles,
        synchronousWrite: true,
        exportPerformance: ExportPerformanceMock.veryQuick))

    let result = decorator.export(logRecords: [makeLogRecord(body: "hello")])
    XCTAssertEqual(result, .success)

    wait(for: [exportExpectation], timeout: 5)
  }

  func testShutdownFlushesAndCallsInner() throws {
    let inner = LogExporterMock()
    let decorator = try PersistenceLogExporterDecorator(
      logRecordExporter: inner,
      storageURL: temporaryDirectory.url)
    decorator.shutdown()
    XCTAssertTrue(inner.shutdownCalled)
  }

  func testForceFlushFlushesAndCallsInner() throws {
    let inner = LogExporterMock()
    let decorator = try PersistenceLogExporterDecorator(
      logRecordExporter: inner,
      storageURL: temporaryDirectory.url)
    let result = decorator.forceFlush()
    XCTAssertEqual(result, .success)
    XCTAssertTrue(inner.flushCalled)
  }

  func testDecoratedExporterReportsRetryOnFailure() {
    let inner = LogExporterMock { _ in .failure }
    let wrapper = PersistenceLogExporterDecorator.LogRecordDecoratedExporter(
      logRecordExporter: inner)
    let status = wrapper.export(values: [makeLogRecord(body: "fail")])
    XCTAssertTrue(status.needsRetry)
  }

  func testDecoratedExporterReportsNoRetryOnSuccess() {
    let inner = LogExporterMock { _ in .success }
    let wrapper = PersistenceLogExporterDecorator.LogRecordDecoratedExporter(
      logRecordExporter: inner)
    let status = wrapper.export(values: [makeLogRecord(body: "ok")])
    XCTAssertFalse(status.needsRetry)
  }
}

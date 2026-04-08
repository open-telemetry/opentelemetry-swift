/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import OpenTelemetrySdk
@testable import PersistenceExporter
import XCTest

class PersistenceSpanExporterDecoratorTests: XCTestCase {
  @UniqueTemporaryDirectory private var temporaryDirectory: Directory

  final class SpanExporterMock: SpanExporter, @unchecked Sendable {
    let onExport: @Sendable ([SpanData], TimeInterval?) -> SpanExporterResultCode
    let onFlush: @Sendable (TimeInterval?) -> SpanExporterResultCode
    let onShutdown: @Sendable (TimeInterval?) -> Void

    init(onExport: @escaping @Sendable ([SpanData], TimeInterval?) -> SpanExporterResultCode,
         onFlush: @escaping @Sendable (TimeInterval?) -> SpanExporterResultCode = { _ in .success },
         onShutdown: @escaping @Sendable (TimeInterval?) -> Void = { _ in }) {
      self.onExport = onExport
      self.onFlush = onFlush
      self.onShutdown = onShutdown
    }

    @discardableResult func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
      return onExport(spans, explicitTimeout)
    }

    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
      return onFlush(explicitTimeout)
    }

    func shutdown(explicitTimeout: TimeInterval?) {
      onShutdown(explicitTimeout)
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

  @MainActor
  func testWhenExportSpansIsCalled_thenSpansAreExported() throws {
    let spansExportExpectation = expectation(description: "spans exported")
    let exporterShutdownExpectation = expectation(description: "exporter shut down")

    let mockSpanExporter = SpanExporterMock(onExport: { spans, _ in
      spans.forEach { span in
        if span.name == "SimpleSpan",
           span.events.count == 1,
           span.events.first!.name == "My event" {
          spansExportExpectation.fulfill()
        }
      }

      return .success
    }, onShutdown: { _ in
      exporterShutdownExpectation.fulfill()
    })

    let persistenceSpanExporter =
      try PersistenceSpanExporterDecorator(spanExporter: mockSpanExporter,
                                           storageURL: temporaryDirectory.url,
                                           exportCondition: { true },
                                           performancePreset: PersistencePerformancePreset.mockWith(storagePerformance: StoragePerformanceMock.writeEachObjectToNewFileAndReadAllFiles,
                                                                                                    synchronousWrite: true,
                                                                                                    exportPerformance: ExportPerformanceMock.veryQuick))

    let instrumentationScopeName = "SimpleExporter"
    let instrumentationScopeVersion = "semver:0.1.0"
    let tracerProviderSDK = TracerProviderSdk()
    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProviderSDK)
    let tracer = tracerProviderSDK.get(instrumentationName: instrumentationScopeName, instrumentationVersion: instrumentationScopeVersion) as! TracerSdk

    let spanProcessor = SimpleSpanProcessor(spanExporter: persistenceSpanExporter)
    tracerProviderSDK.addSpanProcessor(spanProcessor)

    simpleSpan(tracer: tracer)
    spanProcessor.shutdown()

    waitForExpectations(timeout: 10, handler: nil)
  }

  @MainActor
  func testWhenExportFails_thenSpansAreRetried() throws {
    nonisolated(unsafe) var exportAttempts = 0
    let firstExportExpectation = expectation(description: "first export attempt")
    let secondExportExpectation = expectation(description: "second export attempt")

    let mockSpanExporter = SpanExporterMock(onExport: { spans, _ in
      exportAttempts += 1
      if exportAttempts == 1 {
        firstExportExpectation.fulfill()
        return .failure
      } else if exportAttempts == 2 {
        secondExportExpectation.fulfill()
        return .success
      }
      return .success
    })

    let persistenceSpanExporter =
      try PersistenceSpanExporterDecorator(spanExporter: mockSpanExporter,
                                           storageURL: temporaryDirectory.url,
                                           exportCondition: { true },
                                           performancePreset: PersistencePerformancePreset.mockWith(storagePerformance: StoragePerformanceMock.writeEachObjectToNewFileAndReadAllFiles,
                                                                                                    synchronousWrite: true,
                                                                                                    exportPerformance: ExportPerformanceMock.veryQuick))

    let instrumentationScopeName = "RetryExporter"
    let instrumentationScopeVersion = "semver:0.1.0"
    let tracerProviderSDK = TracerProviderSdk()
    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProviderSDK)
    let tracer = tracerProviderSDK.get(instrumentationName: instrumentationScopeName, instrumentationVersion: instrumentationScopeVersion) as! TracerSdk

    let spanProcessor = SimpleSpanProcessor(spanExporter: persistenceSpanExporter)
    tracerProviderSDK.addSpanProcessor(spanProcessor)

    simpleSpan(tracer: tracer)
    spanProcessor.shutdown()

    waitForExpectations(timeout: 10, handler: nil)
    XCTAssertEqual(exportAttempts, 2, "Expected 2 export attempts (1 failure + 1 retry)")
  }

  private func simpleSpan(tracer: TracerSdk) {
    let span = tracer.spanBuilder(spanName: "SimpleSpan").setSpanKind(spanKind: .client).startSpan()
    span.addEvent(name: "My event", timestamp: Date())
    span.end()
  }
}

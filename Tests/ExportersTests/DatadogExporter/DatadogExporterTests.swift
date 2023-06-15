/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import DatadogExporter
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class DatadogExporterTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testWhenExportSpanIsCalled_thenTraceAndLogsAreUploaded() throws {
        #if os(watchOS)
        throw XCTSkip("Test is flaky on watchOS")
        #else
        var logsSent = false
        var tracesSent = false
        let expecTrace = expectation(description: "trace received")
        expecTrace.assertForOverFulfill = false
        let expecLog = expectation(description: "logs received")
        expecLog.assertForOverFulfill = false

        let server = HttpTestServer(url: URL(string: "http://localhost:33333"),
                                    config: HttpTestServerConfig(tracesReceivedCallback: {
                                                                     tracesSent = true
                                                                     expecTrace.fulfill()
                                                                 },
                                                                 logsReceivedCallback: {
                                                                     logsSent = true
                                                                     expecLog.fulfill()
                                                                 }))

        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .default).async {
            do {
                try server.start(semaphore: sem)
            } catch {
                XCTFail()
                return
            }
        }
        sem.wait()

        let instrumentationScopeName = "SimpleExporter"
        let instrumentationScopeVersion = "semver:0.1.0"

        let tracerProvider = TracerProviderSdk()
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
        guard let tracer = tracerProvider.get(instrumentationName: instrumentationScopeName, instrumentationVersion: instrumentationScopeVersion) as? TracerSdk else {
            XCTFail()
            server.stop()
            return
        }

        let exporterConfiguration = ExporterConfiguration(serviceName: "serviceName",
                                                          resource: "resource",
                                                          applicationName: "applicationName",
                                                          applicationVersion: "applicationVersion",
                                                          environment: "environment",
                                                          apiKey: "apikey",
                                                          endpoint: Endpoint.custom(
                                                              tracesURL: URL(string: "http://localhost:33333/traces")!,
                                                              logsURL: URL(string: "http://localhost:33333/logs")!,
                                                              metricsURL: URL(string: "http://localhost:33333/metrics")!),
                                                          uploadCondition: { true })

        let datadogExporter = try! DatadogExporter(config: exporterConfiguration)

        let spanProcessor = SimpleSpanProcessor(spanExporter: datadogExporter)
        (OpenTelemetry.instance.tracerProvider as? TracerProviderSdk)?.addSpanProcessor(spanProcessor)

        simpleSpan(tracer: tracer)
        spanProcessor.shutdown()

        let result = XCTWaiter().wait(for: [expecTrace, expecLog], timeout: 20, enforceOrder: false)

        if result == .completed {
            XCTAssertTrue(logsSent)
            XCTAssertTrue(tracesSent)
        } else {
            XCTFail()
        }
        server.stop()
        #endif
    }

    private func simpleSpan(tracer: TracerSdk) {
        let span = tracer.spanBuilder(spanName: "SimpleSpan").setSpanKind(spanKind: .client).startSpan()
        span.addEvent(name: "My event", timestamp: Date())
        span.end()
    }

    func testWhenExportMetricIsCalled_thenMetricsAreUploaded() throws {
        #if os(watchOS)
        throw XCTSkip("Test is flaky on watchOS")
        #else
        var metricsSent = false
        let expecMetrics = expectation(description: "metrics received")
        expecMetrics.assertForOverFulfill = false

        let server = HttpTestServer(url: URL(string: "http://localhost:33333"),
                                    config: HttpTestServerConfig(metricsReceivedCallback: {
                                        metricsSent = true
                                        expecMetrics.fulfill()
                                    }))

        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .default).async {
            do {
                try server.start(semaphore: sem)
            } catch {
                XCTFail()
                return
            }
        }
        sem.wait()

        let exporterConfiguration = ExporterConfiguration(serviceName: "serviceName",
                                                          resource: "resource",
                                                          applicationName: "applicationName",
                                                          applicationVersion: "applicationVersion",
                                                          environment: "environment",
                                                          apiKey: "apikey",
                                                          endpoint: Endpoint.custom(
                                                              tracesURL: URL(string: "http://localhost:33333/traces")!,
                                                              logsURL: URL(string: "http://localhost:33333/logs")!,
                                                              metricsURL: URL(string: "http://localhost:33333/metrics")!),
                                                          uploadCondition: { true })

        let datadogExporter = try! DatadogExporter(config: exporterConfiguration)

        let provider = MeterProviderSdk(metricProcessor: MetricProcessorSdk(),
                                        metricExporter: datadogExporter,
                                        metricPushInterval: 0.1)

        let meter = provider.get(instrumentationName: "MyMeter")

        let testCounter = meter.createIntCounter(name: "MyCounter")

        testCounter.add(value: 100, labelset: LabelSet.empty)

        let result = XCTWaiter().wait(for: [expecMetrics], timeout: 20)

        if result == .completed {
            XCTAssertTrue(metricsSent)
        } else {
            XCTFail()
        }

        server.stop()
        #endif
    }
}

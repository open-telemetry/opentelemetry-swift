/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import GRPC
import Logging
import NIO
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetryProtocolExporterGrpc
@testable import OpenTelemetrySdk
import XCTest

class OtlpMetricExproterTests: XCTestCase {
    var fakeCollector: FakeMetricCollector!
    var server: EventLoopFuture<Server>!
    var channel: ClientConnection!

    let channelGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let serverGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    override func setUp() {
        fakeCollector = FakeMetricCollector()
        server = startServer()
        channel = startChannel()
    }

    override func tearDown() {
        try! serverGroup.syncShutdownGracefully()
        try! channelGroup.syncShutdownGracefully()
    }

    func testExport() {
        let metric = generateSumMetric()
        let exporter = OtlpMetricExporter(channel: channel)
        let result = exporter.export(metrics: [metric]) { () -> Bool in
            false
        }
        XCTAssertEqual(result, MetricExporterResultCode.success)
        XCTAssertEqual(fakeCollector.receivedMetrics, MetricsAdapter.toProtoResourceMetrics(metricDataList: [metric]))
        exporter.shutdown()
    }

    func testImplicitGrpcLoggingConfig() throws {
        let exporter = OtlpMetricExporter(channel: channel)
        guard let logger = exporter.callOptions?.logger else {
            throw "Missing logger"
        }
        XCTAssertEqual(logger.label, "io.grpc")
    }

    func testExplicitGrpcLoggingConfig() throws {
        let exporter = OtlpMetricExporter(channel: channel, logger: Logger(label: "my.grpc.logger"))
        guard let logger = exporter.callOptions?.logger else {
            throw "Missing logger"
        }
        XCTAssertEqual(logger.label, "my.grpc.logger")
    }

    func testConfigHeadersIsNil_whenDefaultInitCalled() throws {
        let exporter = OtlpMetricExporter(channel: channel)
        XCTAssertNil(exporter.config.headers)

        verifyUserAgentIsSet(exporter: exporter)
    }

    func testConfigHeadersAreSet_whenInitCalledWithCustomConfig() throws {
        let config: OtlpConfiguration = OtlpConfiguration(timeout: TimeInterval(10), headers: [("FOO", "BAR")])
        let exporter = OtlpMetricExporter(channel: channel, config: config)
        XCTAssertNotNil(exporter.config.headers)
        XCTAssertEqual(exporter.config.headers?[0].0, "FOO")
        XCTAssertEqual(exporter.config.headers?[0].1, "BAR")
        XCTAssertEqual("BAR", exporter.callOptions?.customMetadata.first(name: "FOO"))

        verifyUserAgentIsSet(exporter: exporter)
    }

    func testConfigHeadersAreSet_whenInitCalledWithExplicitHeaders() throws {
        let exporter = OtlpMetricExporter(channel: channel, envVarHeaders: [("FOO", "BAR")])
        XCTAssertNil(exporter.config.headers)
        XCTAssertEqual("BAR", exporter.callOptions?.customMetadata.first(name: "FOO"))

        verifyUserAgentIsSet(exporter: exporter)
    }

    func testGaugeExport() {
        let metric = generateGaugeMetric()
        let exporter = OtlpMetricExporter(channel: channel)

        let result = exporter.export(metrics: [metric]) { () -> Bool in
            false
        }
        XCTAssertEqual(result, MetricExporterResultCode.success)

        XCTAssertEqual(fakeCollector.receivedMetrics.count, 1)
        let otlpMetric = fakeCollector.receivedMetrics[0].scopeMetrics[0].metrics[0]
        XCTAssertEqual(metric.name, otlpMetric.name)
        XCTAssertEqual(otlpMetric.gauge.dataPoints.count, 1)
        let dataPoint = otlpMetric.gauge.dataPoints[0]
        let sum = metric.data[0] as! SumData<Int>
        XCTAssertEqual(sum.timestamp.timeIntervalSince1970.toNanoseconds, dataPoint.timeUnixNano)
        XCTAssertEqual(sum.startTimestamp.timeIntervalSince1970.toNanoseconds, dataPoint.startTimeUnixNano)
        XCTAssertEqual(sum.sum, Int(dataPoint.asInt))
    }

    func testExportMultipleMetrics() {
        var metrics = [Metric]()
        for _ in 0 ..< 10 {
            metrics.append(generateSumMetric())
        }
        let exporter = OtlpMetricExporter(channel: channel)
        let result = exporter.export(metrics: metrics) { () -> Bool in
            false
        }
        XCTAssertEqual(result, MetricExporterResultCode.success)
        XCTAssertEqual(fakeCollector.receivedMetrics, MetricsAdapter.toProtoResourceMetrics(metricDataList: metrics))
        exporter.shutdown()
    }

    func testExportAfterShutdown() {
        let metric = generateSumMetric()
        let exporter = OtlpMetricExporter(channel: channel)
        exporter.shutdown()
        let result = exporter.export(metrics: [metric]) { () -> Bool in
            false
        }
        XCTAssertEqual(result, MetricExporterResultCode.failureRetryable)
    }

    func testExportCancelled() {
        fakeCollector.returnedStatus = GRPCStatus(code: .cancelled, message: nil)
        let exporter = OtlpMetricExporter(channel: channel)
        let metric = generateSumMetric()
        let result = exporter.export(metrics: [metric]) { () -> Bool in
            false
        }
        XCTAssertEqual(result, MetricExporterResultCode.failureRetryable)
    }

    func startServer() -> EventLoopFuture<Server> {
        // Start the server and print its address once it has started.
        let server = Server.insecure(group: serverGroup)
            .withServiceProviders([fakeCollector])
            .bind(host: "localhost", port: 4317)

        server.map {
            $0.channel.localAddress
        }.whenSuccess { address in
            print("server started on port \(address!.port!)")
        }
        return server
    }

    func startChannel() -> ClientConnection {
        let channel = ClientConnection.insecure(group: channelGroup)
            .connect(host: "localhost", port: 4317)
        return channel
    }

    func generateSumMetric() -> Metric {
        let scope = InstrumentationScopeInfo(name: "lib", version: "semver:0.0.0")
        var metric = Metric(namespace: "namespace", name: "metric", desc: "description", type: .doubleSum, resource: Resource(), instrumentationScopeInfo: scope)
        let data = SumData(startTimestamp: Date(), timestamp: Date(), labels: ["hello": "world"], sum: 1)
        metric.data.append(data)
        return metric
    }

    func generateGaugeMetric() -> Metric {
        let scope = InstrumentationScopeInfo(name: "lib", version: "semver:0.0.0")
        var metric = Metric(namespace: "namespace", name: "MyGauge", desc: "description", type: .intGauge, resource: Resource(), instrumentationScopeInfo: scope)
        let data = SumData(startTimestamp: Date(), timestamp: Date(), labels: ["hello": "world"], sum: 100)
        metric.data.append(data)
        return metric
    }

    func verifyUserAgentIsSet(exporter: OtlpMetricExporter) {
        if let callOptions = exporter.callOptions {
            let customMetadata = callOptions.customMetadata
            let userAgent = Headers.getUserAgentHeader()
            if customMetadata.contains(name: Constants.HTTP.userAgent) && customMetadata.first(name: Constants.HTTP.userAgent) == userAgent {
                return
            }
        }
        XCTFail("User-Agent header was not set correctly")
    }
}

class FakeMetricCollector: Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceProvider {
    var interceptors: Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceServerInterceptorFactoryProtocol?

    var receivedMetrics = [Opentelemetry_Proto_Metrics_V1_ResourceMetrics]()
    var returnedStatus = GRPCStatus.ok
    func export(request: Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest, context: StatusOnlyCallContext) ->
        EventLoopFuture<Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse> {
        receivedMetrics.append(contentsOf: request.resourceMetrics)
        if returnedStatus != GRPCStatus.ok {
            return context.eventLoop.makeFailedFuture(returnedStatus)
        }
        return context.eventLoop.makeSucceededFuture(Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse())
    }
}


import Foundation
import GRPC
import NIO
import OpenTelemetryApi
@testable import OpenTelemetryProtocolExporter
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
        let exporter = OtelpMetricExporter(channel: channel)
        let result = exporter.export(metrics: [metric]) { () -> Bool in
            false
        }
        XCTAssertEqual(result, MetricExporterResultCode.success)
        XCTAssertEqual(fakeCollector.receivedMetrics, MetricsAdapter.toProtoResourceMetrics(metricDataList: [metric]))
        exporter.shutdown()
    }

    func testExportMultipleMetrics() {
        var metrics = [Metric]()
        for _ in 0 ..< 10 {
            metrics.append(generateSumMetric())
        }
        let exporter = OtelpMetricExporter(channel: channel)
        let result = exporter.export(metrics: metrics) { () -> Bool in
            false
        }
        XCTAssertEqual(result, MetricExporterResultCode.success)
        XCTAssertEqual(fakeCollector.receivedMetrics, MetricsAdapter.toProtoResourceMetrics(metricDataList: metrics))
        exporter.shutdown()
    }

    func testExportAfterShutdown() {
        let metric = generateSumMetric()
        let exporter = OtelpMetricExporter(channel: channel)
        exporter.shutdown()
        let result = exporter.export(metrics: [metric]) { () -> Bool in
            false
        }
        XCTAssertEqual(result, MetricExporterResultCode.failureRetryable)
    }

    func testExportCancelled() {
        fakeCollector.returnedStatus = GRPCStatus(code: .cancelled, message: nil)
        let exporter = OtelpMetricExporter(channel: channel)
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
            .bind(host: "localhost", port: 55680)

        server.map {
            $0.channel.localAddress
        }.whenSuccess { address in
            print("server started on port \(address!.port!)")
        }
        return server
    }

    func startChannel() -> ClientConnection {
        let channel = ClientConnection.insecure(group: channelGroup)
            .connect(host: "localhost", port: 55680)
        return channel
    }

    func generateSumMetric() -> Metric {
        let library = InstrumentationLibraryInfo(name: "lib", version: "semver:0.0.0")
        var metric = Metric(namespace: "namespace", name: "metric", desc: "description", type: .doubleSum, resource: Resource(), instrumentationLibraryInfo: library)
        let data = SumData(startTimestamp: Date(), timestamp: Date(), labels: ["hello": "world"], sum: 1)
        metric.data.append(data)
        return metric
    }
}

class FakeMetricCollector: Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceProvider {
    var interceptors: Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceServerInterceptorFactoryProtocol?

    var receivedMetrics = [Opentelemetry_Proto_Metrics_V1_ResourceMetrics]()
    var returnedStatus = GRPCStatus.ok
    func export(request: Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest, context: StatusOnlyCallContext) ->
        EventLoopFuture<Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse>
    {
        receivedMetrics.append(contentsOf: request.resourceMetrics)
        if returnedStatus != GRPCStatus.ok {
            return context.eventLoop.makeFailedFuture(returnedStatus)
        }
        return context.eventLoop.makeSucceededFuture(Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse())
    }
}

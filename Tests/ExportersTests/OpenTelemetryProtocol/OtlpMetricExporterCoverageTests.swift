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

final class OtlpMetricExporterCoverageTests: XCTestCase {
  private var fakeCollector: FakeMetricCollector!
  private var runningServer: Server!
  private var channel: ClientConnection!
  private let serverGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  private let channelGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

  override func setUp() {
    super.setUp()
    fakeCollector = FakeMetricCollector()
    // Bind to port 0 → kernel picks an ephemeral port. Wait synchronously so
    // the first `export()` in any test doesn't race server bind. The channel
    // also uses the assigned port rather than a hard-coded one (previously
    // `4327`), eliminating port-collision flakes under parallel CI.
    runningServer = try! Server.insecure(group: serverGroup)
      .withServiceProviders([fakeCollector])
      .bind(host: "localhost", port: 0)
      .wait()
    let assignedPort = runningServer.channel.localAddress!.port!
    channel = ClientConnection.insecure(group: channelGroup)
      .connect(host: "localhost", port: assignedPort)
  }

  override func tearDown() {
    XCTAssertNoThrow(try runningServer.close().wait())
    XCTAssertNoThrow(try serverGroup.syncShutdownGracefully())
    XCTAssertNoThrow(try channelGroup.syncShutdownGracefully())
    super.tearDown()
  }

  private func sampleMetric() -> MetricData {
    let point = LongPointData(startEpochNanos: 0, endEpochNanos: 1,
                              attributes: [:], exemplars: [], value: 1)
    return MetricData.createLongSum(
      resource: Resource(attributes: ["s": .string("v")]),
      instrumentationScopeInfo: InstrumentationScopeInfo(name: "scope"),
      name: "sum",
      description: "",
      unit: "",
      isMonotonic: true,
      data: SumData(aggregationTemporality: .cumulative, points: [point]))
  }

  func testExportSuccess() {
    let exporter = OtlpMetricExporter(channel: channel)
    XCTAssertEqual(exporter.export(metrics: [sampleMetric()]), .success)
    XCTAssertFalse(fakeCollector.receivedMetrics.isEmpty)
    _ = exporter.shutdown()
  }

  func testExportFailurePropagatesStatus() {
    fakeCollector.returnedStatus = GRPCStatus(code: .cancelled, message: nil)
    let exporter = OtlpMetricExporter(channel: channel)
    XCTAssertEqual(exporter.export(metrics: [sampleMetric()]), .failure)
    _ = exporter.shutdown()
  }

  func testExportAppliesTimeout() {
    let exporter = OtlpMetricExporter(
      channel: channel,
      config: OtlpConfiguration(timeout: 5))
    XCTAssertEqual(exporter.export(metrics: [sampleMetric()]), .success)
    _ = exporter.shutdown()
  }

  func testConfigHeadersSetOnCallOptions() {
    let exporter = OtlpMetricExporter(
      channel: channel,
      config: OtlpConfiguration(headers: [("x-k", "x-v")]),
      envVarHeaders: nil)
    XCTAssertTrue(exporter.callOptions?.customMetadata.contains(name: "x-k") ?? false)
    _ = exporter.shutdown()
  }

  func testEnvVarHeadersSetOnCallOptions() {
    let exporter = OtlpMetricExporter(
      channel: channel,
      envVarHeaders: [("x-env", "v")])
    XCTAssertTrue(exporter.callOptions?.customMetadata.contains(name: "x-env") ?? false)
    _ = exporter.shutdown()
  }

  func testGetAggregationTemporalityReturnsConfigured() {
    let exporter = OtlpMetricExporter(channel: channel)
    XCTAssertEqual(exporter.getAggregationTemporality(for: .counter), .cumulative)
    _ = exporter.shutdown()
  }

  func testFlushReturnsSuccess() {
    let exporter = OtlpMetricExporter(channel: channel)
    XCTAssertEqual(exporter.flush(), .success)
    _ = exporter.shutdown()
  }

  func testShutdownReturnsSuccess() {
    let exporter = OtlpMetricExporter(channel: channel)
    XCTAssertEqual(exporter.shutdown(), .success)
  }
}

private final class FakeMetricCollector: Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceProvider, @unchecked Sendable {
  var receivedMetrics = [Opentelemetry_Proto_Metrics_V1_ResourceMetrics]()
  var returnedStatus = GRPCStatus.ok
  var interceptors: Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceServerInterceptorFactoryProtocol?

  func export(request: Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest,
              context: StatusOnlyCallContext) -> EventLoopFuture<Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse> {
    receivedMetrics.append(contentsOf: request.resourceMetrics)
    if returnedStatus != GRPCStatus.ok {
      return context.eventLoop.makeFailedFuture(returnedStatus)
    }
    return context.eventLoop.makeSucceededFuture(Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse())
  }
}

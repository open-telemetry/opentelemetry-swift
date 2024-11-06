//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Logging
import NIO
import NIOHTTP1
import NIOTestUtils
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetryProtocolExporterHttp
@testable import OpenTelemetrySdk
import XCTest

class StableOtlpHttpMetricsExporterTest: XCTestCase {
  var testServer: NIOHTTP1TestServer!
  var group: MultiThreadedEventLoopGroup!
  
  override func setUp() {
    group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    testServer = NIOHTTP1TestServer(group: group)
  }
  
  override func tearDown() {
    XCTAssertNoThrow(try testServer.stop())
    XCTAssertNoThrow(try group.syncShutdownGracefully())
  }
  
  // The shutdown() function is a no-op, This test is just here to make codecov happy
  func testShutdown() {
    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let exporter = StableOtlpHTTPMetricExporter(endpoint: endpoint)
    XCTAssertEqual(exporter.shutdown(), .success)
  }
  
  func testExportHeader() {
    let metric = generateSumStableMetricData()
    
    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let exporter = StableOtlpHTTPMetricExporter(endpoint: endpoint, config: OtlpConfiguration(headers: [("headerName", "headerValue")]))
    let result = exporter.export(metrics: [metric])
    XCTAssertEqual(result, ExportResult.success)
    
    XCTAssertNoThrow(try testServer.receiveHeadAndVerify { head in
      XCTAssertTrue(head.headers.contains(name: "headerName"))
      XCTAssertEqual("headerValue", head.headers.first(name: "headerName"))
    })
    
    XCTAssertNotNil(try testServer.receiveBodyAndVerify())
    XCTAssertNoThrow(try testServer.receiveEnd())
  }
  
  func testExport() {
    let words = ["foo", "bar", "fizz", "buzz"]
    var metrics: [StableMetricData] = []
    var metricDescriptions: [String] = []
    for word in words {
    let metricDescription = word + String(Int.random(in: 1...100))
      metricDescriptions.append(metricDescription)
      metrics.append(generateSumStableMetricData(description: metricDescription))
    }

    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let exporter = StableOtlpHTTPMetricExporter(endpoint: endpoint, config: .init(compression: .none))
    let result = exporter.export(metrics: metrics)
    XCTAssertEqual(result, ExportResult.success)
    
    XCTAssertNoThrow(try testServer.receiveHeadAndVerify { head in
      let otelVersion = Headers.getUserAgentHeader()
      XCTAssertTrue(head.headers.contains(name: Constants.HTTP.userAgent))
      XCTAssertEqual(otelVersion, head.headers.first(name: Constants.HTTP.userAgent))
    })
    
    XCTAssertNoThrow(try testServer.receiveBodyAndVerify { body in
      var contentsBuffer = ByteBuffer(buffer: body)
      let contents = contentsBuffer.readString(length: contentsBuffer.readableBytes)!
      for metricDescription in metricDescriptions {
        XCTAssertTrue(contents.contains(metricDescription))
      }
    })
    
    XCTAssertNoThrow(try testServer.receiveEnd())
  }
  
  func testGaugeExport() {
    let words = ["foo", "bar", "fizz", "buzz"]
    var metrics: [StableMetricData] = []
    var metricDescriptions: [String] = []
    for word in words {
    let metricDescription = word + String(Int.random(in: 1...100))
      metricDescriptions.append(metricDescription)
      metrics.append(generateGaugeStableMetricData(description: metricDescription))
    }

    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let exporter = StableOtlpHTTPMetricExporter(endpoint: endpoint, config: .init(compression: .none))
    let result = exporter.export(metrics: metrics)
    XCTAssertEqual(result, ExportResult.success)
    
    XCTAssertNoThrow(try testServer.receiveHeadAndVerify { head in
      let otelVersion = Headers.getUserAgentHeader()
      XCTAssertTrue(head.headers.contains(name: Constants.HTTP.userAgent))
      XCTAssertEqual(otelVersion, head.headers.first(name: Constants.HTTP.userAgent))
    })
    
    XCTAssertNoThrow(try testServer.receiveBodyAndVerify { body in
      var contentsBuffer = ByteBuffer(buffer: body)
      let contents = contentsBuffer.readString(length: contentsBuffer.readableBytes)!
      for metricDescription in metricDescriptions {
        XCTAssertTrue(contents.contains(metricDescription))
      }
    })
    
    XCTAssertNoThrow(try testServer.receiveEnd())
  }
  
  func testFlushWithoutPendingMetrics() {
    let metric = generateSumStableMetricData()
    
    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let exporter = StableOtlpHTTPMetricExporter(endpoint: endpoint, config: OtlpConfiguration(headers: [("headerName", "headerValue")]))
    XCTAssertEqual(exporter.flush(), .success)
  }
  
  func testCustomAggregationTemporalitySelector() {
    let aggregationTemporalitySelector = AggregationTemporalitySelector() { (type) in
      switch type {
      case .counter:
        return .cumulative
      case .histogram:
        return .delta
      case .observableCounter:
        return .delta
      case .observableGauge:
        return .delta
      case .observableUpDownCounter:
        return .cumulative
      case .upDownCounter:
        return .delta
      }
    }
    
    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let exporter = StableOtlpHTTPMetricExporter(endpoint: endpoint, aggregationTemporalitySelector: aggregationTemporalitySelector)
    XCTAssertTrue(exporter.getAggregationTemporality(for: .counter) == .cumulative)
    XCTAssertTrue(exporter.getAggregationTemporality(for: .histogram) == .delta)
    XCTAssertTrue(exporter.getAggregationTemporality(for: .observableCounter) == .delta)
    XCTAssertTrue(exporter.getAggregationTemporality(for: .observableGauge) == .delta)
    XCTAssertTrue(exporter.getAggregationTemporality(for: .observableUpDownCounter) == .cumulative)
    XCTAssertTrue(exporter.getAggregationTemporality(for: .upDownCounter) == .delta)
  }
  
  func testCustomAggregation() {
    let aggregationSelector = CustomDefaultAggregationSelector()
    
    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let exporter = StableOtlpHTTPMetricExporter(endpoint: endpoint, defaultAggregationSelector: aggregationSelector)
    XCTAssertTrue(exporter.getDefaultAggregation(for: .counter) is SumAggregation)
    XCTAssertTrue(exporter.getDefaultAggregation(for: .histogram) is SumAggregation)
    XCTAssertTrue(exporter.getDefaultAggregation(for: .observableCounter) is DropAggregation)
    XCTAssertTrue(exporter.getDefaultAggregation(for: .upDownCounter) is DropAggregation)
  }
  
  
  func generateSumStableMetricData(description: String = "description") -> StableMetricData {
    let scope = InstrumentationScopeInfo(name: "lib", version: "semver:0.0.0")
    let sumPointData = DoublePointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: 1)
    let metric = StableMetricData(resource: Resource(), instrumentationScopeInfo: scope, name: "metric", description: description, unit: "", type: .DoubleSum, isMonotonic: true, data: StableMetricData.Data(aggregationTemporality: .cumulative, points: [sumPointData]))
    return metric
  }

  func generateGaugeStableMetricData(description: String = "description") -> StableMetricData {
    let scope = InstrumentationScopeInfo(name: "lib", version: "semver:0.0.0")
    let sumPointData = DoublePointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: 100)
    let metric = StableMetricData(resource: Resource(), instrumentationScopeInfo: scope, name: "MyGauge", description: description, unit: "", type: .LongGauge, isMonotonic: true, data: StableMetricData.Data(aggregationTemporality: .cumulative, points: [sumPointData]))
    return metric
  }
}

public class CustomDefaultAggregationSelector: DefaultAggregationSelector {
  public func getDefaultAggregation(for instrument: OpenTelemetrySdk.InstrumentType) -> OpenTelemetrySdk.Aggregation {
    switch instrument {
    case .counter, .histogram:
      return SumAggregation()
    default:
      return DropAggregation()
    }
  }
}

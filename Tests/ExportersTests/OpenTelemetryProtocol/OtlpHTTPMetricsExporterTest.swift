//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Logging
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetryProtocolExporterHttp
@testable import OpenTelemetrySdk
import XCTest
import SharedTestUtils

class OtlpHttpMetricsExporterTest: XCTestCase {
  var testServer: HttpTestServer!

  override func setUp() {
    testServer = HttpTestServer()
    XCTAssertNoThrow(try testServer.start())
  }

  override func tearDown() {
    XCTAssertNoThrow(try testServer.stop())
  }

  // The shutdown() function is a no-op, This test is just here to make codecov happy
  func testShutdown() {
    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let exporter = OtlpHttpMetricExporter(endpoint: endpoint)
    XCTAssertEqual(exporter.shutdown(), .success)
  }

  func testExportHeader() {
    let metric = generateSumStableMetricData()

    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let exporter = OtlpHttpMetricExporter(
      endpoint: endpoint,
      config: OtlpConfiguration(headers: [("headerName", "headerValue")])
    )
    let result = exporter.export(metrics: [metric])
    XCTAssertEqual(result, ExportResult.success)

    XCTAssertNoThrow(try testServer.receiveHeadAndVerify { head in
      XCTAssertTrue(head.headers.contains(name: "headerName"))
      XCTAssertEqual("headerValue", head.headers.first(name: "headerName"))
    })

    XCTAssertNoThrow(try testServer.receiveBodyAndVerify { _ in 
      // Body verified
    })
    XCTAssertNoThrow(try testServer.receiveEnd())
  }

  func testExport() {
    let words = ["foo", "bar", "fizz", "buzz"]
    var metrics: [MetricData] = []
    var metricDescriptions: [String] = []
    for word in words {
      let metricDescription = word + String(Int.random(in: 1 ... 100))
      metricDescriptions.append(metricDescription)
      metrics.append(generateSumStableMetricData(description: metricDescription))
    }

    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let exporter = OtlpHttpMetricExporter(
      endpoint: endpoint,
      config: .init(compression: .none)
    )
    let result = exporter.export(metrics: metrics)
    XCTAssertEqual(result, ExportResult.success)

    XCTAssertNoThrow(try testServer.receiveHeadAndVerify { head in
      let otelVersion = Headers.getUserAgentHeader()
      XCTAssertTrue(head.headers.contains(name: Constants.HTTP.userAgent))
      XCTAssertEqual(otelVersion, head.headers.first(name: Constants.HTTP.userAgent))
    })

    XCTAssertNoThrow(try testServer.receiveBodyAndVerify { body in
      let bodyString = String(decoding: body, as: UTF8.self)
      for metricDescription in metricDescriptions {
        XCTAssertTrue(bodyString.contains(metricDescription))
      }
    })

    XCTAssertNoThrow(try testServer.receiveEnd())
  }

  func testGaugeExport() {
    let words = ["foo", "bar", "fizz", "buzz"]
    var metrics: [MetricData] = []
    var metricDescriptions: [String] = []
    for word in words {
      let metricDescription = word + String(Int.random(in: 1 ... 100))
      metricDescriptions.append(metricDescription)
      metrics.append(generateGaugeStableMetricData(description: metricDescription))
    }

    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let exporter = OtlpHttpMetricExporter(
      endpoint: endpoint,
      config: .init(compression: .none)
    )
    let result = exporter.export(metrics: metrics)
    XCTAssertEqual(result, ExportResult.success)

    XCTAssertNoThrow(try testServer.receiveHeadAndVerify { head in
      let otelVersion = Headers.getUserAgentHeader()
      XCTAssertTrue(head.headers.contains(name: Constants.HTTP.userAgent))
      XCTAssertEqual(otelVersion, head.headers.first(name: Constants.HTTP.userAgent))
    })

    XCTAssertNoThrow(try testServer.receiveBodyAndVerify { body in
      let bodyString = String(decoding: body, as: UTF8.self)
      for metricDescription in metricDescriptions {
        XCTAssertTrue(bodyString.contains(metricDescription))
      }
    })

    XCTAssertNoThrow(try testServer.receiveEnd())
  }

  func testFlushWithoutPendingMetrics() {
    _ = generateSumStableMetricData()

    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let exporter = OtlpHttpMetricExporter(
      endpoint: endpoint,
      config: OtlpConfiguration(headers: [("headerName", "headerValue")])
    )
    XCTAssertEqual(exporter.flush(), .success)
  }

  func testCustomAggregationTemporalitySelector() {
    let aggregationTemporalitySelector = AggregationTemporalitySelector { type in
      switch type {
      case .counter:
        return .cumulative
      case .histogram:
        return .delta
      case .observableCounter:
        return .delta
      case .observableGauge, .gauge:
        return .delta
      case .observableUpDownCounter:
        return .cumulative
      case .upDownCounter:
        return .delta
      }
    }

    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let exporter = OtlpHttpMetricExporter(
      endpoint: endpoint,
      aggregationTemporalitySelector: aggregationTemporalitySelector
    )
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
    let exporter = OtlpHttpMetricExporter(
      endpoint: endpoint,
      defaultAggregationSelector: aggregationSelector
    )
    XCTAssertTrue(exporter.getDefaultAggregation(for: .counter) is SumAggregation)
    XCTAssertTrue(exporter.getDefaultAggregation(for: .histogram) is SumAggregation)
    XCTAssertTrue(exporter.getDefaultAggregation(for: .observableCounter) is DropAggregation)
    XCTAssertTrue(exporter.getDefaultAggregation(for: .upDownCounter) is DropAggregation)
  }

  func generateSumStableMetricData(description: String = "description") -> MetricData {
    let scope = InstrumentationScopeInfo(
      name: "lib",
      version: "semver:0.0.0",
      attributes: ["instrumentationScope": AttributeValue.string("attributes")]
    )
    let sumPointData = DoublePointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: 1)
    let metric = MetricData(
      resource: Resource(),
      instrumentationScopeInfo: scope,
      name: "metric",
      description: description,
      unit: "",
      type: .DoubleSum,
      isMonotonic: true,
      data: MetricData
        .Data(aggregationTemporality: .cumulative, points: [sumPointData])
    )
    return metric
  }

  func generateGaugeStableMetricData(description: String = "description") -> MetricData {
    let scope = InstrumentationScopeInfo(name: "lib", version: "semver:0.0.0")
    let sumPointData = DoublePointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: 100)
    let metric = MetricData(
      resource: Resource(),
      instrumentationScopeInfo: scope,
      name: "MyGauge",
      description: description,
      unit: "",
      type: .LongGauge,
      isMonotonic: true,
      data: MetricData
        .Data(aggregationTemporality: .cumulative, points: [sumPointData])
    )
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

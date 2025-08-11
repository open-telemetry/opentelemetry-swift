/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import OpenTelemetryApi
import OpenTelemetrySdk
@testable import PrometheusExporter
import XCTest

class PrometheusExporterTests: XCTestCase {
  let metricPushIntervalSec = 0.05
  let waitDuration = 0.1 + 0.1

  func testMetricsHttpServerAsync() {
    let promOptions = PrometheusExporterOptions(url: "http://localhost:9184/metrics/")
    let promExporter = PrometheusExporter(options: promOptions)
    let metricsHttpServer = PrometheusExporterHttpServer(exporter: promExporter)

    let expec = expectation(description: "Get metrics from server")

    DispatchQueue.global(qos: .default).async {
      do {
        try metricsHttpServer.start()
      } catch {
        XCTFail()
        return
      }
    }

    let retain_me = collectMetrics(exporter: promExporter)
    _ = retain_me // silence warning
    usleep(useconds_t(waitDuration * 1000000))
    let url = URL(string: "http://localhost:9184/metrics/")!
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
      if error == nil, let data, let response = response as? HTTPURLResponse {
        XCTAssert(response.statusCode == 200)
        let responseText = String(decoding: data, as: UTF8.self)
        print("Response from metric API is: \n\(responseText)")
        self.validateResponse(responseText: responseText)
        // This is your file-variable:
        // data
        expec.fulfill()
      } else {
        XCTFail()
        expec.fulfill()
        return
      }
    }
    task.resume()

    waitForExpectations(timeout: 30) { error in
      if let error {
        print("Error: \(error.localizedDescription)")
        XCTFail()
      }
    }

    metricsHttpServer.stop()
  }

  private func collectMetrics(exporter: any MetricExporter) -> MeterProviderSdk {
    let meterProvider = MeterProviderSdk.builder()
      .registerMetricReader(
        reader: PeriodicMetricReaderBuilder(
          exporter: exporter
        )
        .setInterval(timeInterval: 0.01)
        .build()
      )
      .registerView(
        selector: InstrumentSelector
          .builder()
          .setInstrument(name: "testHistogram")
          .build(),
        view: View.builder()
          .withAggregation(
            aggregation: ExplicitBucketHistogramAggregation(bucketBoundaries: [5, 10, 25])
          ).build()
      )
      .registerView(
        selector: InstrumentSelector.builder().setInstrument(name: "testCounter|testGauge").build(),
        view: View.builder().build()
      )
      .build()
    let meter = meterProvider.get(name: "scope1")

    let testCounter = meter.counterBuilder(name: "testCounter").build()
    let testGauge = meter.gaugeBuilder(name: "testGauge").build()
    let testHistogram = meter.histogramBuilder(name: "testHistogram").build()
    let labels1 = ["dim1": AttributeValue.string("value1"), "dim2": AttributeValue.string("value1")]
    let labels2 = ["dim1": AttributeValue.string("value2"), "dim2": AttributeValue.string("value2")]
    let labels3 = ["dim1": AttributeValue.string("value1")]

    for _ in 0 ..< 10 {
      testCounter.add(value: 100, attributes: labels1)
      testCounter.add(value: 10, attributes: labels1)
      testCounter.add(value: 200, attributes: labels2)
      testCounter.add(value: 10, attributes: labels2)

      testGauge.record(value: 500, attributes: labels1)

      testHistogram.record(value: 8, attributes: labels3)
      testHistogram.record(value: 20, attributes: labels3)
      testHistogram.record(value: 30, attributes: labels3)
    }
    return meterProvider
  }

  private func validateResponse(responseText: String) {
    // Validate counters.
    XCTAssert(responseText.contains("TYPE testCounter counter"))
    XCTAssert(responseText.contains("testCounter{dim1=\"value1\",dim2=\"value1\"}") || responseText.contains("testCounter{dim2=\"value1\",dim1=\"value1\"}"))
    XCTAssert(responseText.contains("testCounter{dim1=\"value2\",dim2=\"value2\"}") || responseText.contains("testCounter{dim2=\"value2\",dim1=\"value2\"}"))

    // Validate measure.
    XCTAssert(responseText.contains("# TYPE testGauge gauge"))
    XCTAssert(responseText.contains("testGauge{dim2=\"value1\",dim1=\"value1\"} 500") ||
              responseText.contains("testGauge{dim1=\"value1\",dim2=\"value1\"} 500"))

    // Validate histogram.
    XCTAssert(responseText.contains("# TYPE testHistogram histogram"))
    // sum is 58 = 8 + 20 + 30
    XCTAssert(responseText.contains("testHistogram_sum{dim1=\"value1\"} 58"))
    // count is 1 * 3
    XCTAssert(responseText.contains("testHistogram_count{dim1=\"value1\"} 3"))
    // validate le
    XCTAssert(responseText.contains("testHistogram{dim1=\"value1\",le=\"5.000000\"} 0") || responseText.contains("testHistogram{le=\"5.000000\",dim1=\"value1\"} 0"))
    XCTAssert(responseText.contains("testHistogram{dim1=\"value1\",le=\"10.000000\"} 1") || responseText.contains("testHistogram{le=\"10.000000\",dim1=\"value1\"} 1"))
    XCTAssert(responseText.contains("testHistogram{dim1=\"value1\",le=\"25.000000\"} 1") || responseText.contains("testHistogram{le=\"25.000000\",dim1=\"value1\"} 1"))
    XCTAssert(responseText.contains("testHistogram{dim1=\"value1\",le=\"+Inf\"} 1") || responseText.contains("testHistogram{le=\"+Inf\",dim1=\"value1\"} 1"))
  }
}

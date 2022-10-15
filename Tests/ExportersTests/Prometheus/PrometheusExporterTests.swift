/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk
@testable import PrometheusExporter
import XCTest

class PrometheusExporterTests: XCTestCase {
    let metricPushIntervalSec = 0.05
    let waitDuration = 0.1 + 0.1

    
    func testMetricsHttpServerAsync() {
        let promOptions = PrometheusExporterOptions(url: "http://localhost:9184/metrics/")
        let promExporter = PrometheusExporter(options: promOptions)
        let simpleProcessor = MetricProcessorSdk()
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

        let retain_me = collectMetrics(simpleProcessor: simpleProcessor, exporter: promExporter)
        usleep(useconds_t(waitDuration * 1000000))
        let url = URL(string: "http://localhost:9184/metrics/")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if error == nil, let data = data, let response = response as? HTTPURLResponse {
                XCTAssert(response.statusCode == 200)
                let responseText = String(decoding: data, as: UTF8.self)
                print("Response from metric API is: \n\(responseText)")
                self.validateResponse(responseText: responseText);
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
            if let error = error {
                print("Error: \(error.localizedDescription)")
                XCTFail()
            }
        }

        metricsHttpServer.stop()
    }

    private func collectMetrics(simpleProcessor: MetricProcessorSdk, exporter: MetricExporter) -> MeterProviderSdk {

        let meterProvider = MeterProviderSdk(metricProcessor: simpleProcessor, metricExporter: exporter, metricPushInterval: metricPushIntervalSec)
        
        let meter = meterProvider.get(instrumentationName: "scope1")

        let testCounter = meter.createIntCounter(name: "testCounter")
        let testMeasure = meter.createIntMeasure(name: "testMeasure")
        let boundaries: Array<Int> = [5, 10, 25]
        var testHistogram = meter.createIntHistogram(name: "testHistogram", explicitBoundaries: boundaries, absolute: true)
        let labels1 = ["dim1": "value1", "dim2": "value1"]
        let labels2 = ["dim1": "value2", "dim2": "value2"]
        let labels3 = ["dim1": "value1"]

        for _ in 0 ..< 10 {
            testCounter.add(value: 100, labelset: meter.getLabelSet(labels: labels1))
            testCounter.add(value: 10, labelset: meter.getLabelSet(labels: labels1))
            testCounter.add(value: 200, labelset: meter.getLabelSet(labels: labels2))
            testCounter.add(value: 10, labelset: meter.getLabelSet(labels: labels2))

            testMeasure.record(value: 10, labelset: meter.getLabelSet(labels: labels1))
            testMeasure.record(value: 100, labelset: meter.getLabelSet(labels: labels1))
            testMeasure.record(value: 5, labelset: meter.getLabelSet(labels: labels1))
            testMeasure.record(value: 500, labelset: meter.getLabelSet(labels: labels1))

            testHistogram.record(value: 8, labelset: meter.getLabelSet(labels: labels3))
            testHistogram.record(value: 20, labelset: meter.getLabelSet(labels: labels3))
            testHistogram.record(value: 30, labelset: meter.getLabelSet(labels: labels3))
        }
        return meterProvider
    }

    private func validateResponse(responseText: String) {
        // Validate counters.
        XCTAssert(responseText.contains("TYPE testCounter counter"))
        XCTAssert(responseText.contains("testCounter{dim1=\"value1\",dim2=\"value1\"}") || responseText.contains("testCounter{dim2=\"value1\",dim1=\"value1\"}") )
        XCTAssert(responseText.contains("testCounter{dim1=\"value2\",dim2=\"value2\"}") || responseText.contains("testCounter{dim2=\"value2\",dim1=\"value2\"}"))

        // Validate measure.
        XCTAssert(responseText.contains("# TYPE testMeasure summary"))
        // sum is 6150 = 10 * (10+100+5+500)
        XCTAssert(responseText.contains("testMeasure_sum{dim1=\"value1\"} 6150"))
        // count is 10 * 4
        XCTAssert(responseText.contains("testMeasure_count{dim1=\"value1\"} 40"))
        // Min is 5
        XCTAssert(responseText.contains("testMeasure{dim1=\"value1\",quantile=\"0\"} 5") || responseText.contains("testMeasure{quantile=\"0\",dim1=\"value1\"} 5"))
        // Max is 500
        XCTAssert(responseText.contains("testMeasure{dim1=\"value1\",quantile=\"1\"} 500") || responseText.contains("testMeasure{quantile=\"1\",dim1=\"value1\"} 500"))

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

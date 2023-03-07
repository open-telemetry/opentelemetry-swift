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
@testable import OpenTelemetryProtocolExporter
@testable import OpenTelemetrySdk
import XCTest

class OtlpHttpMetricsExporterTest: XCTestCase {
    var exporter: OtlpHttpMetricExporter!
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
        let exporter = OtlpHttpMetricExporter(endpoint: endpoint)
        XCTAssertNoThrow(exporter.shutdown())
    }
    
    // This test and testGaugeExport() are somewhat hacky solutions to verifying that the metrics got across correctly.  It
    // simply looks for the metric description strings (which is why I made them unique) in the body returned by
    // testServer.receiveBodyAndVerify().  It should ideally turn that body into [Metric] using protobuf and then confirm content
    func testExport() {        
        let words = ["foo", "bar", "fizz", "buzz"]
        var metrics: [Metric] = []
        var metricDescriptions: [String] = []
        for word in words {
            let metricDescription = word + String(Int.random(in: 1...100))
            metricDescriptions.append(metricDescription)
            metrics.append(generateSumMetric(description: metricDescription))
        }

        let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
        let exporter = OtlpHttpMetricExporter(endpoint: endpoint)
        let result = exporter.export(metrics: metrics) { () -> Bool in
            false
        }
        XCTAssertEqual(result, MetricExporterResultCode.success)
        
        XCTAssertNoThrow(try testServer.receiveHead())
        XCTAssertNoThrow(try testServer.receiveBodyAndVerify() { body in
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
        var metrics: [Metric] = []
        var metricDescriptions: [String] = []
        for word in words {
            let metricDescription = word + String(Int.random(in: 1...100))
            metricDescriptions.append(metricDescription)
            metrics.append(generateGaugeMetric(description: metricDescription))
        }
        
        let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
        let exporter = OtlpHttpMetricExporter(endpoint: endpoint)

        let result = exporter.export(metrics: metrics) { () -> Bool in
            false
        }
        XCTAssertEqual(result, MetricExporterResultCode.success)
        
        XCTAssertNoThrow(try testServer.receiveHead())
        XCTAssertNoThrow(try testServer.receiveBodyAndVerify() { body in
            var contentsBuffer = ByteBuffer(buffer: body)
            let contents = contentsBuffer.readString(length: contentsBuffer.readableBytes)!
            for metricDescription in metricDescriptions {
                XCTAssertTrue(contents.contains(metricDescription))
            }
        })
        XCTAssertNoThrow(try testServer.receiveEnd())
        
        // TODO: if we can turn contents back into [Metric], look at OtlpMetricExporterTests for additional checks
    }
    
    func testFlush() {
        let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
        let exporter = OtlpHttpMetricExporter(endpoint: endpoint)
        XCTAssertEqual(MetricExporterResultCode.success, exporter.flush())
    }
    
    func generateSumMetric(description: String = "description") -> Metric {
        let scope = InstrumentationScopeInfo(name: "lib", version: "semver:0.0.0")
        var metric = Metric(namespace: "namespace", name: "metric", desc: description, type: .doubleSum, resource: Resource(), instrumentationScopeInfo: scope)
        let data = SumData(startTimestamp: Date(), timestamp: Date(), labels: ["hello": "world"], sum: 1)
        metric.data.append(data)
        return metric
    }

    func generateGaugeMetric(description: String = "description") -> Metric {
        let scope = InstrumentationScopeInfo(name: "lib", version: "semver:0.0.0")
        var metric = Metric(namespace: "namespace", name: "MyGauge", desc: description, type: .intGauge, resource: Resource(), instrumentationScopeInfo: scope)
        let data = SumData(startTimestamp: Date(), timestamp: Date(), labels: ["hello": "world"], sum: 100)
        metric.data.append(data)
        return metric
    }
}

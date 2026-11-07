/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if compiler(>=6.4) && canImport(MetricKit) && !os(tvOS) && !os(watchOS) && !os(visionOS)
import Foundation
import MetricKit
@testable import MetricKitInstrumentation
import InMemoryExporter
@testable import OpenTelemetrySdk
import XCTest

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, *)
final class MetricManagerInstrumentationTests: XCTestCase {
    func testUnifiedInstrumentationSupportsLegacyRegistration() {
        let configuration = MetricKitConfiguration()
        let instrumentation = MetricKitInstrumentation(
            configuration: configuration,
            enabledStateReportingDomains: ["com.example.app.tabs"]
        )

        MXMetricManager.shared.add(instrumentation)

        XCTAssertTrue(instrumentation.configuration.tracer === configuration.tracer)
    }

    func testReportMetricsPreservesTheCompleteMetricReport() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let timeRange = DateInterval(start: start, duration: 60)
        let duration = #"{"unit":"s","value":12}"#
        let reportJSON = """
        {
          "stateEntries": {
            "com.example.app.tabs": [{
              "state": {
                "domain": "com.example.app.tabs",
                "label": "Reports",
                "duration": \(duration),
                "stableMetadata": {}
              },
              "values": []
            }]
          },
          "intervalEntries": [{
            "states": [{
              "domain": "com.example.app.tabs",
              "label": "Reports",
              "duration": \(duration),
              "stableMetadata": {}
            }],
            "duration": \(duration),
            "values": []
          }],
          "timeRange": {
            "begin": \(timeRange.start.timeIntervalSinceReferenceDate),
            "end": \(timeRange.end.timeIntervalSinceReferenceDate)
          },
          "environment": null
        }
        """
        let report = try JSONDecoder().decode(MetricReport.self, from: Data(reportJSON.utf8))

        let exporter = InMemoryExporter()
        let tracerProvider = TracerProviderSdk()
        tracerProvider.addSpanProcessor(SimpleSpanProcessor(spanExporter: exporter))
        let configuration = MetricKitConfiguration(
            tracer: tracerProvider.get(instrumentationName: "MetricManagerInstrumentationTests")
        )

        reportMetricReport(report: report, configuration: configuration)
        tracerProvider.forceFlush()

        let span = try XCTUnwrap(exporter.getFinishedSpanItems().first)
        XCTAssertEqual(span.name, "MetricReport")
        XCTAssertEqual(span.startTime, timeRange.start)
        XCTAssertEqual(span.endTime, timeRange.end)

        let serializedReport = try XCTUnwrap(
            span.attributes["metrickit.metric_report"]?.description.data(using: .utf8)
        )
        let serializedString = String(decoding: serializedReport, as: UTF8.self)
        let serializedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: serializedReport) as? [String: Any]
        )
        let serializedIntervals = try XCTUnwrap(
            serializedObject["intervalEntries"] as? [[String: Any]]
        )
        let serializedStates = try XCTUnwrap(serializedObject["stateEntries"] as? [String: Any])
        let intervalStates = try XCTUnwrap(
            serializedIntervals.first?["states"] as? [String: Any]
        )
        XCTAssertNotNil(intervalStates["com.example.app.tabs"])
        XCTAssertNotNil(serializedStates["com.example.app.tabs"])
        XCTAssertNotNil(serializedObject["timeRange"])
        XCTAssertTrue(serializedString.contains("com.example.app.tabs"))
        XCTAssertTrue(serializedString.contains("Reports"))
    }

    func testDiagnosticReportsAreEmittedAsCompleteLogPayloads() throws {
        let report = #"{"result":{"memoryException":{"callStackTree":{}}}}"#
        let timeRange = DateInterval(
            start: Date(timeIntervalSince1970: 1_800_000_000),
            duration: 60
        )
        let logExporter = InMemoryLogRecordExporter()
        let loggerProvider = LoggerProviderBuilder()
            .with(processors: [SimpleLogRecordProcessor(logRecordExporter: logExporter)])
            .build()
        let configuration = MetricKitConfiguration(
            logger: loggerProvider.get(instrumentationScopeName: "MetricManagerInstrumentationTests")
        )

        recordDiagnosticReport(
            serializedReport: report,
            timeRange: timeRange,
            configuration: configuration
        )

        let log = try XCTUnwrap(logExporter.getFinishedLogRecords().first)
        let serializedReport = try XCTUnwrap(
            log.attributes["metrickit.diagnostic_report"]?.description
        )
        XCTAssertEqual(serializedReport, report)
        XCTAssertEqual(log.timestamp, timeRange.end)
    }
}
#endif

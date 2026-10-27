/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if compiler(>=6.4) && canImport(MetricKit) && !os(tvOS) && !os(watchOS) && !os(visionOS)
import Foundation
import MetricKit
import OpenTelemetryApi

private let metricReportSpanName = "MetricReport"
private let metricReportAttributeName = "metrickit.metric_report"
private let diagnosticReportEventName = "metrickit.diagnostic_report"
private let diagnosticReportAttributeName = "metrickit.diagnostic_report"
private let reportEncodingErrorEventName = "metrickit.report_encoding_error"

// MetricKit report tasks share OTel API references that are not declared Sendable.
struct MetricKitConfigurationForReportStream: @unchecked Sendable {
    let configuration: MetricKitConfiguration
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, *)
actor MetricManagerStream {
    private let configuration: MetricKitConfiguration
    private let metricManager: MetricManager
    private var metricReportsTask: Task<Void, Never>?
    private var diagnosticReportsTask: Task<Void, Never>?

    init(
        configuration: MetricKitConfigurationForReportStream,
        enabledStateReportingDomains: Set<StateReportingDomain> = []
    ) {
        self.configuration = configuration.configuration
        self.metricManager = MetricManager(
            enabledStateReportingDomains: enabledStateReportingDomains
        )
    }

    deinit {
        metricReportsTask?.cancel()
        diagnosticReportsTask?.cancel()
    }

    func start() {
        guard metricReportsTask == nil, diagnosticReportsTask == nil else {
            return
        }

        let metricManager = self.metricManager
        metricReportsTask = Task { [weak self, metricManager] in
            for await report in metricManager.metricReports {
                guard !Task.isCancelled, let self else {
                    return
                }
                await self.receiveMetricReport(report)
            }
        }

        diagnosticReportsTask = Task { [weak self, metricManager] in
            for await report in metricManager.diagnosticReports {
                guard !Task.isCancelled, let self else {
                    return
                }
                await self.receiveDiagnosticReport(report)
            }
        }
    }

    func stop() {
        metricReportsTask?.cancel()
        metricReportsTask = nil
        diagnosticReportsTask?.cancel()
        diagnosticReportsTask = nil
    }

    private func receiveMetricReport(_ report: MetricReport) {
        reportMetricReport(report: report, configuration: configuration)
    }

    private func receiveDiagnosticReport(_ report: DiagnosticReport) {
        reportDiagnosticReport(report: report, configuration: configuration)
    }
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, *)
func reportMetricReport(report: MetricReport, configuration: MetricKitConfiguration) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.userInfo[MetricReport.encodingFormatKey] = MetricReport.EncodingFormat
        .byStateReportingDomain

    let serializedReport: String
    do {
        serializedReport = String(decoding: try encoder.encode(report), as: UTF8.self)
    } catch {
        reportEncodingError(error, configuration: configuration)
        return
    }

    let span = configuration.tracer.spanBuilder(spanName: metricReportSpanName)
        .setStartTime(time: report.timeRange.start)
        .startSpan()
    span.setAttribute(key: metricReportAttributeName, value: serializedReport)
    span.end(time: report.timeRange.end)
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, *)
func reportDiagnosticReport(report: DiagnosticReport, configuration: MetricKitConfiguration) {
    let serializedReport: String
    do {
        serializedReport = String(decoding: try JSONEncoder().encode(report), as: UTF8.self)
    } catch {
        reportEncodingError(error, configuration: configuration)
        return
    }

    recordDiagnosticReport(
        serializedReport: serializedReport,
        timeRange: report.timeRange,
        configuration: configuration
    )
}

func recordDiagnosticReport(
    serializedReport: String,
    timeRange: DateInterval,
    configuration: MetricKitConfiguration
) {
    let now = Date()
    configuration.logger.logRecordBuilder()
        .setEventName(diagnosticReportEventName)
        .setTimestamp(timeRange.end)
        .setObservedTimestamp(now)
        .setAttributes([diagnosticReportAttributeName: .string(serializedReport)])
        .emit()
}

private func reportEncodingError(_ error: Error, configuration: MetricKitConfiguration) {
    let now = Date()
    configuration.logger.logRecordBuilder()
        .setEventName(reportEncodingErrorEventName)
        .setTimestamp(now)
        .setObservedTimestamp(now)
        .setAttributes(["exception.message": .string(String(describing: error))])
        .emit()
}
#endif

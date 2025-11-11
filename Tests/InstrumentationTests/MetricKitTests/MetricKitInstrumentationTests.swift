/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
import Foundation
import MetricKit
@testable import MetricKitInstrumentation
@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
import InMemoryExporter
import XCTest

@available(iOS 13.0, macOS 10.15, macCatalyst 13.1, visionOS 1.0, *)
class MetricKitInstrumentationTests: XCTestCase {
    var spanExporter: InMemoryExporter!
    var tracerProvider: TracerProviderSdk!

    override func setUp() {
        super.setUp()

        // Set up tracer provider with in-memory exporter
        spanExporter = InMemoryExporter()
        tracerProvider = TracerProviderSdk()
        tracerProvider.addSpanProcessor(SimpleSpanProcessor(spanExporter: spanExporter))

        // Register the tracer provider
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
    }

    override func tearDown() {
        spanExporter.reset()
        super.tearDown()
    }

    func testReportMetrics_CreatesMainSpan() {
        let payload = FakeMetricPayload()

        reportMetrics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()

        // Should have the main MXMetricPayload span plus 2 signpost spans
        XCTAssertGreaterThanOrEqual(spans.count, 1, "Should have at least one span")

        let mainSpan = spans.first { $0.name == "MXMetricPayload" }
        XCTAssertNotNil(mainSpan, "Should have a MXMetricPayload span")

        // Verify timestamps
        XCTAssertEqual(mainSpan?.startTime, payload.timeStampBegin)
        XCTAssertEqual(mainSpan?.endTime, payload.timeStampEnd)
    }

    func testReportMetrics_SetsMetadataAttributes() {
        let payload = FakeMetricPayload()

        reportMetrics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()
        let mainSpan = spans.first { $0.name == "MXMetricPayload" }

        XCTAssertNotNil(mainSpan)
        let attributes = mainSpan?.attributes

        // Check top-level attributes
        XCTAssertEqual(attributes?["metrickit.latest_application_version"]?.description, "3.14.159")
        XCTAssertEqual(attributes?["metrickit.includes_multiple_application_versions"]?.description, "false")

        // Check metadata attributes
        XCTAssertEqual(attributes?["metrickit.metadata.app_build_version"]?.description, "build")
        XCTAssertEqual(attributes?["metrickit.metadata.device_type"]?.description, "device")
        XCTAssertEqual(attributes?["metrickit.metadata.os_version"]?.description, "os")
        XCTAssertEqual(attributes?["metrickit.metadata.region_format"]?.description, "format")

        if #available(iOS 14.0, *) {
            XCTAssertEqual(attributes?["metrickit.metadata.platform_arch"]?.description, "arch")
        }

        if #available(iOS 17.0, *) {
            XCTAssertEqual(attributes?["metrickit.metadata.is_test_flight_app"]?.description, "true")
            XCTAssertEqual(attributes?["metrickit.metadata.low_power_mode_enabled"]?.description, "true")
            XCTAssertEqual(attributes?["metrickit.metadata.pid"]?.description, "29")
        }
    }

    func testReportMetrics_SetsCPUAttributes() {
        let payload = FakeMetricPayload()

        reportMetrics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()
        let mainSpan = spans.first { $0.name == "MXMetricPayload" }

        XCTAssertNotNil(mainSpan)
        let attributes = mainSpan?.attributes

        // CPU metrics
        XCTAssertEqual(attributes?["metrickit.cpu.cpu_time"]?.description, "1.0")

        if #available(iOS 14.0, *) {
            XCTAssertEqual(attributes?["metrickit.cpu.instruction_count"]?.description, "2.0")
        }
    }

    func testReportMetrics_SetsMemoryAndGPUAttributes() {
        let payload = FakeMetricPayload()

        reportMetrics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()
        let mainSpan = spans.first { $0.name == "MXMetricPayload" }

        XCTAssertNotNil(mainSpan)
        let attributes = mainSpan?.attributes

        // GPU metrics
        XCTAssertEqual(attributes?["metrickit.gpu.time"]?.description, "10800.0")

        // Memory metrics
        XCTAssertEqual(attributes?["metrickit.memory.peak_memory_usage"]?.description, "25.0")
        XCTAssertEqual(attributes?["metrickit.memory.suspended_memory_average"]?.description, "26.0")
    }

    func testReportMetrics_SetsNetworkAttributes() {
        let payload = FakeMetricPayload()

        reportMetrics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()
        let mainSpan = spans.first { $0.name == "MXMetricPayload" }

        XCTAssertNotNil(mainSpan)
        let attributes = mainSpan?.attributes

        // Network transfer metrics
        XCTAssertEqual(attributes?["metrickit.network_transfer.wifi_upload"]?.description, "15.0")
        XCTAssertEqual(attributes?["metrickit.network_transfer.wifi_download"]?.description, "16000.0")
        XCTAssertEqual(attributes?["metrickit.network_transfer.cellular_upload"]?.description, "17000000.0")
        XCTAssertEqual(attributes?["metrickit.network_transfer.cellular_download"]?.description, "18000000000.0")
    }

    @available(iOS 13.0, macOS 12.0, macCatalyst 13.1, visionOS 1.0, *)
    func testReportMetrics_SetsAppLaunchAttributes() {
        let payload = FakeMetricPayload()

        reportMetrics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()
        let mainSpan = spans.first { $0.name == "MXMetricPayload" }

        XCTAssertNotNil(mainSpan)
        let attributes = mainSpan?.attributes

        // App launch metrics (histograms)
        XCTAssertEqual(attributes?["metrickit.app_launch.time_to_first_draw_average"]?.description, "1140.0")
        XCTAssertEqual(attributes?["metrickit.app_launch.app_resume_time_average"]?.description, "1200.0")

        if #available(iOS 15.2, *) {
            XCTAssertEqual(attributes?["metrickit.app_launch.optimized_time_to_first_draw_average"]?.description, "1260.0")
        }

        if #available(iOS 16.0, *) {
            XCTAssertEqual(attributes?["metrickit.app_launch.extended_launch_average"]?.description, "1320.0")
        }
    }

    func testReportMetrics_SetsAppTimeAttributes() {
        let payload = FakeMetricPayload()

        reportMetrics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()
        let mainSpan = spans.first { $0.name == "MXMetricPayload" }

        XCTAssertNotNil(mainSpan)
        let attributes = mainSpan?.attributes

        // App time metrics
        XCTAssertEqual(attributes?["metrickit.app_time.foreground_time"]?.description, "300.0")
        XCTAssertEqual(attributes?["metrickit.app_time.background_time"]?.description, "6e-06")
        XCTAssertEqual(attributes?["metrickit.app_time.background_audio_time"]?.description, "0.007")
        XCTAssertEqual(attributes?["metrickit.app_time.background_location_time"]?.description, "480.0")
    }

    func testReportMetrics_SetsLocationActivityAttributes() {
        let payload = FakeMetricPayload()

        reportMetrics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()
        let mainSpan = spans.first { $0.name == "MXMetricPayload" }

        XCTAssertNotNil(mainSpan)
        let attributes = mainSpan?.attributes

        // Location activity metrics
        XCTAssertEqual(attributes?["metrickit.location_activity.best_accuracy_time"]?.description, "9.0")
        XCTAssertEqual(attributes?["metrickit.location_activity.best_accuracy_for_nav_time"]?.description, "10.0")
        XCTAssertEqual(attributes?["metrickit.location_activity.accuracy_10m_time"]?.description, "11.0")
        XCTAssertEqual(attributes?["metrickit.location_activity.accuracy_100m_time"]?.description, "12.0")
        XCTAssertEqual(attributes?["metrickit.location_activity.accuracy_1km_time"]?.description, "13.0")
        XCTAssertEqual(attributes?["metrickit.location_activity.accuracy_3km_time"]?.description, "14.0")
    }

    @available(iOS 13.0, macOS 12.0, macCatalyst 13.1, visionOS 1.0, *)
    func testReportMetrics_SetsResponsivenessAttributes() {
        let payload = FakeMetricPayload()

        reportMetrics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()
        let mainSpan = spans.first { $0.name == "MXMetricPayload" }

        XCTAssertNotNil(mainSpan)
        let attributes = mainSpan?.attributes

        // App responsiveness metrics
        XCTAssertEqual(attributes?["metrickit.app_responsiveness.hang_time_average"]?.description, "82800.0")
    }

    func testReportMetrics_SetsDiskIOAttributes() {
        let payload = FakeMetricPayload()

        reportMetrics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()
        let mainSpan = spans.first { $0.name == "MXMetricPayload" }

        XCTAssertNotNil(mainSpan)
        let attributes = mainSpan?.attributes

        // Disk I/O metrics
        XCTAssertEqual(attributes?["metrickit.diskio.logical_write_count"]?.description, "24000000000000.0")
    }

    func testReportMetrics_SetsDisplayAttributes() {
        let payload = FakeMetricPayload()

        reportMetrics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()
        let mainSpan = spans.first { $0.name == "MXMetricPayload" }

        XCTAssertNotNil(mainSpan)
        let attributes = mainSpan?.attributes

        // Display metrics
        XCTAssertEqual(attributes?["metrickit.display.pixel_luminance_average"]?.description, "27.0")
    }

    @available(iOS 14.0, *)
    func testReportMetrics_SetsAnimationAttributes() {
        let payload = FakeMetricPayload()

        reportMetrics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()
        let mainSpan = spans.first { $0.name == "MXMetricPayload" }

        XCTAssertNotNil(mainSpan)
        let attributes = mainSpan?.attributes

        // Animation metrics
        XCTAssertEqual(attributes?["metrickit.animation.scroll_hitch_time_ratio"]?.description, "28.0")
    }

    @available(iOS 14.0, *)
    func testReportMetrics_SetsAppExitAttributes() {
        let payload = FakeMetricPayload()

        reportMetrics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()
        let mainSpan = spans.first { $0.name == "MXMetricPayload" }

        XCTAssertNotNil(mainSpan)
        let attributes = mainSpan?.attributes

        // Foreground exit metrics
        XCTAssertEqual(attributes?["metrickit.app_exit.foreground.normal_app_exit_count"]?.description, "30")
        XCTAssertEqual(attributes?["metrickit.app_exit.foreground.memory_resource_limit_exit-count"]?.description, "31")
        XCTAssertEqual(attributes?["metrickit.app_exit.foreground.bad_access_exit_count"]?.description, "32")
        XCTAssertEqual(attributes?["metrickit.app_exit.foreground.abnormal_exit_count"]?.description, "33")
        XCTAssertEqual(attributes?["metrickit.app_exit.foreground.illegal_instruction_exit_count"]?.description, "34")
        XCTAssertEqual(attributes?["metrickit.app_exit.foreground.app_watchdog_exit_count"]?.description, "35")

        // Background exit metrics
        XCTAssertEqual(attributes?["metrickit.app_exit.background.normal_app_exit_count"]?.description, "36")
        XCTAssertEqual(attributes?["metrickit.app_exit.background.memory_resource_limit_exit_count"]?.description, "37")
        XCTAssertEqual(attributes?["metrickit.app_exit.background.cpu_resource_limit_exit_count"]?.description, "38")
        XCTAssertEqual(attributes?["metrickit.app_exit.background.memory_pressure_exit_count"]?.description, "39")
        XCTAssertEqual(attributes?["metrickit.app_exit.background.bad_access-exit_count"]?.description, "40")
        XCTAssertEqual(attributes?["metrickit.app_exit.background.abnormal_exit_count"]?.description, "41")
        XCTAssertEqual(attributes?["metrickit.app_exit.background.illegal_instruction_exit_count"]?.description, "42")
        XCTAssertEqual(attributes?["metrickit.app_exit.background.app_watchdog_exit_count"]?.description, "43")
        XCTAssertEqual(attributes?["metrickit.app_exit.background.suspended_with_locked_file_exit_count"]?.description, "44")
        XCTAssertEqual(attributes?["metrickit.app_exit.background.background_task_assertion_timeout_exit_count"]?.description, "45")
    }

    func testReportMetrics_CreatesSignpostSpans() {
        let payload = FakeMetricPayload()

        reportMetrics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()

        // Find signpost spans
        let signpostSpans = spans.filter { $0.name == "MXSignpostMetric" }
        XCTAssertEqual(signpostSpans.count, 2, "Should have 2 signpost spans")

        // Verify first signpost
        let signpost1 = signpostSpans.first {
            $0.attributes["signpost.name"]?.description == "signpost1"
        }
        XCTAssertNotNil(signpost1)
        XCTAssertEqual(signpost1?.attributes["signpost.category"]?.description, "cat1")
        XCTAssertEqual(signpost1?.attributes["signpost.count"]?.description, "51")
        XCTAssertEqual(signpost1?.attributes["signpost.cpu_time"]?.description, "47.0")
        XCTAssertEqual(signpost1?.attributes["signpost.memory_average"]?.description, "48.0")
        XCTAssertEqual(signpost1?.attributes["signpost.logical_write_count"]?.description, "49.0")

        if #available(iOS 15.0, *) {
            XCTAssertEqual(signpost1?.attributes["signpost.hitch_time_ratio"]?.description, "50.0")
        }

        // Verify second signpost
        let signpost2 = signpostSpans.first {
            $0.attributes["signpost.name"]?.description == "signpost2"
        }
        XCTAssertNotNil(signpost2)
        XCTAssertEqual(signpost2?.attributes["signpost.category"]?.description, "cat2")
        XCTAssertEqual(signpost2?.attributes["signpost.count"]?.description, "52")
    }

    @available(iOS 13.0, macOS 12.0, macCatalyst 13.1, visionOS 1.0, *)
    func testReportMetrics_SetsCellularConditionAttributes() {
        let payload = FakeMetricPayload()

        reportMetrics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()
        let mainSpan = spans.first { $0.name == "MXMetricPayload" }

        XCTAssertNotNil(mainSpan)
        let attributes = mainSpan?.attributes

        // Cellular condition metrics (histogram average)
        XCTAssertEqual(attributes?["metrickit.cellular_condition.bars_average"]?.description, "4.0")
        // Note: The attribute is set twice in the code (lines 146 and 270), the second one wins
        XCTAssertEqual(attributes?["metrickit.cellular_condition.cellular_condition_time_average"]?.description, "4.0")
    }
}

// MARK: - Diagnostic Tests

@available(iOS 14.0, macOS 12.0, macCatalyst 14.0, visionOS 1.0, *)
class MetricKitDiagnosticTests: XCTestCase {
    var logExporter: InMemoryLogRecordExporter!
    var loggerProvider: LoggerProviderSdk!
    var spanExporter: InMemoryExporter!
    var tracerProvider: TracerProviderSdk!

    override func setUp() {
        super.setUp()

        // Set up logger provider with in-memory exporter
        logExporter = InMemoryLogRecordExporter()
        loggerProvider = LoggerProviderBuilder()
            .with(processors: [SimpleLogRecordProcessor(logRecordExporter: logExporter)])
            .build()

        // Set up tracer provider with in-memory exporter
        spanExporter = InMemoryExporter()
        tracerProvider = TracerProviderSdk()
        tracerProvider.addSpanProcessor(SimpleSpanProcessor(spanExporter: spanExporter))

        // Register providers
        OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
    }

    override func tearDown() {
        logExporter.shutdown()
        spanExporter.reset()
        super.tearDown()
    }

    func testReportDiagnostics_CreatesMainSpan() {
        let payload = FakeDiagnosticPayload()

        reportDiagnostics(payload: payload)

        // Force flush to ensure spans are exported
        tracerProvider.forceFlush()

        let spans = spanExporter.getFinishedSpanItems()
        let mainSpan = spans.first { $0.name == "MXDiagnosticPayload" }

        XCTAssertNotNil(mainSpan, "Should have a MXDiagnosticPayload span")
        XCTAssertEqual(mainSpan?.startTime, payload.timeStampBegin)
    }

    func testReportDiagnostics_CreatesCPUExceptionLogs() {
        let payload = FakeDiagnosticPayload()

        reportDiagnostics(payload: payload)

        let logs = logExporter.getFinishedLogRecords()

        // Find CPU exception log
        let cpuLog = logs.first {
            $0.attributes["name"]?.description == "metrickit.diagnostic.cpu_exception"
        }

        XCTAssertNotNil(cpuLog, "Should have a CPU exception log")
        XCTAssertEqual(cpuLog?.attributes["metrickit.diagnostic.cpu_exception.total_cpu_time"]?.description, "3180.0") // 53 minutes
        XCTAssertEqual(cpuLog?.attributes["metrickit.diagnostic.cpu_exception.total_sampled_time"]?.description, "194400.0") // 54 hours
    }

    func testReportDiagnostics_CreatesDiskWriteExceptionLogs() {
        let payload = FakeDiagnosticPayload()

        reportDiagnostics(payload: payload)

        let logs = logExporter.getFinishedLogRecords()

        // Find disk write exception log
        let diskLog = logs.first {
            $0.attributes["name"]?.description == "metrickit.diagnostic.disk_write_exception"
        }

        XCTAssertNotNil(diskLog, "Should have a disk write exception log")
        XCTAssertEqual(diskLog?.attributes["metrickit.diagnostic.disk_write_exception.total_writes_caused"]?.description, "55000000.0") // 55 megabytes
    }

    func testReportDiagnostics_CreatesHangDiagnosticLogs() {
        let payload = FakeDiagnosticPayload()

        reportDiagnostics(payload: payload)

        let logs = logExporter.getFinishedLogRecords()

        // Find hang diagnostic log
        let hangLog = logs.first {
            $0.attributes["name"]?.description == "metrickit.diagnostic.hang"
        }

        XCTAssertNotNil(hangLog, "Should have a hang diagnostic log")
        XCTAssertEqual(hangLog?.attributes["metrickit.diagnostic.hang.hang_duration"]?.description, "56.0") // 56 seconds

        // Verify standard OTel exception attribute (without namespace prefix)
        XCTAssertNotNil(hangLog?.attributes["exception.stacktrace"])
    }

    func testReportDiagnostics_CreatesCrashDiagnosticLogs() {
        let payload = FakeDiagnosticPayload()

        reportDiagnostics(payload: payload)

        let logs = logExporter.getFinishedLogRecords()

        // Find crash diagnostic log
        let crashLog = logs.first {
            $0.attributes["name"]?.description == "metrickit.diagnostic.crash"
        }

        XCTAssertNotNil(crashLog, "Should have a crash diagnostic log")

        // Verify exception attributes
        XCTAssertEqual(crashLog?.attributes["metrickit.diagnostic.crash.exception.code"]?.description, "58")
        XCTAssertEqual(crashLog?.attributes["metrickit.diagnostic.crash.exception.mach_exception.type"]?.description, "57")
        XCTAssertEqual(crashLog?.attributes["metrickit.diagnostic.crash.exception.mach_exception.name"]?.description, "Unknown exception type: 57")
        XCTAssertEqual(crashLog?.attributes["metrickit.diagnostic.crash.exception.signal"]?.description, "59")
        XCTAssertEqual(crashLog?.attributes["metrickit.diagnostic.crash.exception.signal.name"]?.description, "Unknown signal: 59")
        XCTAssertEqual(crashLog?.attributes["metrickit.diagnostic.crash.exception.termination_reason"]?.description, "reason")

        // Verify standard OTel exception attributes (without namespace prefix)
        XCTAssertNotNil(crashLog?.attributes["exception.stacktrace"])

        // Verify Objective-C exception attributes (iOS 17+)
        if #available(iOS 17.0, *) {
            XCTAssertEqual(crashLog?.attributes["metrickit.diagnostic.crash.exception.objc.type"]?.description, "ExceptionType")
            XCTAssertEqual(crashLog?.attributes["metrickit.diagnostic.crash.exception.objc.message"]?.description, "message: 1 2")
            XCTAssertEqual(crashLog?.attributes["metrickit.diagnostic.crash.exception.objc.classname"]?.description, "MyClass")
            XCTAssertEqual(crashLog?.attributes["metrickit.diagnostic.crash.exception.objc.name"]?.description, "MyCrash")

            // On iOS 17+, standard OTel attributes should use Objective-C exception info (highest priority)
            XCTAssertEqual(crashLog?.attributes["exception.type"]?.description, "MyCrash")
            XCTAssertEqual(crashLog?.attributes["exception.message"]?.description, "message: 1 2")
        } else {
            // On iOS 14-16, standard OTel attributes should use Mach exception info (preferred over signal)
            XCTAssertEqual(crashLog?.attributes["exception.type"]?.description, "Unknown exception type: 57")
            XCTAssertEqual(crashLog?.attributes["exception.message"]?.description, "Unknown exception type: 57")
        }
    }

    #if !os(macOS)
    @available(iOS 16.0, *)
    func testReportDiagnostics_CreatesAppLaunchDiagnosticLogs() {
        let payload = FakeDiagnosticPayload()

        reportDiagnostics(payload: payload)

        let logs = logExporter.getFinishedLogRecords()

        // Find app launch diagnostic log
        let launchLog = logs.first {
            $0.attributes["name"]?.description == "metrickit.diagnostic.app_launch"
        }

        XCTAssertNotNil(launchLog, "Should have an app launch diagnostic log")
        XCTAssertEqual(launchLog?.attributes["metrickit.diagnostic.app_launch.launch_duration"]?.description, "60.0")
    }
    #endif

    func testReportDiagnostics_VerifyLogTimestamps() {
        let payload = FakeDiagnosticPayload()

        reportDiagnostics(payload: payload)

        let logs = logExporter.getFinishedLogRecords()

        // All logs should have the payload's end timestamp
        for log in logs {
            XCTAssertEqual(log.timestamp, payload.timeStampEnd)
        }
    }

    func testReportDiagnostics_VerifyLogCount() {
        let payload = FakeDiagnosticPayload()

        reportDiagnostics(payload: payload)

        let logs = logExporter.getFinishedLogRecords()

        // Should have 4 logs on macOS (cpu_exception, disk_write_exception, hang, crash)
        // Should have 5 logs on iOS 16+ (!macOS) (cpu_exception, disk_write_exception, hang, crash, app_launch)
        #if !os(macOS)
        if #available(iOS 16.0, *) {
            XCTAssertEqual(logs.count, 5, "Should have 5 diagnostic logs on iOS 16+")
        } else {
            XCTAssertEqual(logs.count, 4, "Should have 4 diagnostic logs on iOS 14-15")
        }
        #else
        XCTAssertEqual(logs.count, 4, "Should have 4 diagnostic logs on macOS")
        #endif
    }
}
#endif

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(MetricKit) && !os(tvOS)
import Foundation
import MetricKit
@testable import MetricKitInstrumentation
@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
import InMemoryExporter
import XCTest

@available(iOS 13.0, *)
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
#endif

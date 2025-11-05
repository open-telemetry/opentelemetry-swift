#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
    import Foundation
    import MetricKit
    import OpenTelemetryApi

    private let metricKitInstrumentationName = "MetricKit"
    private let metricKitInstrumentationVersion = "0.0.1"

    @available(iOS 13.0, macOS 12.0, macCatalyst 13.1, visionOS 1.0, *)
    public class MetricKitInstrumentation: NSObject, MXMetricManagerSubscriber {
        public func didReceive(_ payloads: [MXMetricPayload]) {
            for payload in payloads {
                reportMetrics(payload: payload)
            }
        }

        @available(iOS 14.0, macOS 12.0, macCatalyst 14.0, watchOS 7.0, *)
        public func didReceive(_ payloads: [MXDiagnosticPayload]) {
            for payload in payloads {
                reportDiagnostics(payload: payload)
            }
        }
    }

    // MARK: - MetricKit helpers

    func getMetricKitTracer() -> Tracer {
        return OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: metricKitInstrumentationName,
            instrumentationVersion: metricKitInstrumentationVersion,
        )
    }

    /// Estimates the average value of the whole histogram.
    @available(iOS 13.0, macOS 12.0, macCatalyst 13.1, visionOS 1.0, *)
    func estimateHistogramAverage<UnitType>(_ histogram: MXHistogram<UnitType>) -> Measurement<
        UnitType
    >? {
        var estimatedSum: Measurement<UnitType>?
        var sampleCount = 0.0
        for bucket in histogram.bucketEnumerator {
            let bucket = bucket as! MXHistogramBucket<UnitType>
            let estimatedValue = (bucket.bucketStart + bucket.bucketEnd) / 2.0
            let count = Double(bucket.bucketCount)
            estimatedSum =
                if let previousSum = estimatedSum {
                    previousSum + estimatedValue * count
                } else {
                    estimatedValue * count
                }
            sampleCount += count
        }
        return estimatedSum.map { $0 / sampleCount }
    }

    @available(iOS 13.0, macOS 12.0, macCatalyst 13.1, visionOS 1.0, *)
    public func reportMetrics(payload: MXMetricPayload) {
        let span = getMetricKitTracer().spanBuilder(spanName: "MXMetricPayload")
            .setStartTime(time: payload.timeStampBegin)
            .startSpan()
        defer { span.end(time: payload.timeStampEnd) }

        // There are so many nested metrics we want to capture, it's worth setting up some helper
        // methods to reduce the amount of repeated code.

        var namespaceStack = ["metrickit"]

        func captureMetric(key: String, value: AttributeValueConvertable) {
            let namespace = namespaceStack.joined(separator: ".")
            span.setAttribute(key: "\(namespace).\(key)", value: value.attributeValue())
        }

        // Helper functions for sending histograms, specifically.
        func captureMetric<UnitType>(key: String, value histogram: MXHistogram<UnitType>) {
            if let average = estimateHistogramAverage(histogram) {
                captureMetric(key: key, value: average)
            }
        }

        // This helper makes it easier to process each category without typing its name repeatedly.
        func withCategory<T>(_ parent: T?, _ namespace: String, using closure: (T) -> Void) {
            namespaceStack.append(namespace)
            if let p = parent {
                closure(p)
            }
            namespaceStack.removeLast()
        }

        // These attribute names follow the guidelines at
        // https://opentelemetry.io/docs/specs/semconv/general/attribute-naming/

        captureMetric(
            key: "includes_multiple_application_versions",
            value: payload.includesMultipleApplicationVersions
        )
        captureMetric(
            key: "latest_application_version",
            value: payload.latestApplicationVersion
        )
        captureMetric(
            key: "timestamp_begin",
            value: payload.timeStampBegin.timeIntervalSince1970
        )
        captureMetric(key: "timestamp_end", value: payload.timeStampEnd.timeIntervalSince1970)

        withCategory(payload.metaData, "metadata") {
            captureMetric(key: "app_build_version", value: $0.applicationBuildVersion)
            captureMetric(key: "device_type", value: $0.deviceType)
            captureMetric(key: "os_version", value: $0.osVersion)
            captureMetric(key: "region_format", value: $0.regionFormat)
            if #available(iOS 14.0, *) {
                captureMetric(key: "platform_arch", value: $0.platformArchitecture)
            }
            if #available(iOS 17.0, macOS 14.0, *) {
                captureMetric(key: "is_test_flight_app", value: $0.isTestFlightApp)
                captureMetric(key: "low_power_mode_enabled", value: $0.lowPowerModeEnabled)
                captureMetric(key: "pid", value: Int($0.pid))
            }
        }
        withCategory(payload.applicationLaunchMetrics, "app_launch") {
            captureMetric(
                key: "time_to_first_draw_average",
                value: $0.histogrammedTimeToFirstDraw
            )
            captureMetric(
                key: "app_resume_time_average",
                value: $0.histogrammedApplicationResumeTime
            )
            if #available(iOS 15.2, macOS 12.2, *) {
                captureMetric(
                    key: "optimized_time_to_first_draw_average",
                    value: $0.histogrammedOptimizedTimeToFirstDraw
                )
            }
            if #available(iOS 16.0, macOS 13.0, *) {
                captureMetric(
                    key: "extended_launch_average",
                    value: $0.histogrammedExtendedLaunch
                )
            }
        }
        withCategory(payload.applicationResponsivenessMetrics, "app_responsiveness") {
            captureMetric(key: "hang_time_average", value: $0.histogrammedApplicationHangTime)
        }
        withCategory(payload.cellularConditionMetrics, "cellular_condition") {
            captureMetric(key: "bars_average", value: $0.histogrammedCellularConditionTime)
        }
        withCategory(payload.locationActivityMetrics, "location_activity") {
            captureMetric(key: "best_accuracy_time", value: $0.cumulativeBestAccuracyTime)
            captureMetric(
                key: "best_accuracy_for_nav_time",
                value: $0.cumulativeBestAccuracyForNavigationTime
            )
            captureMetric(
                key: "accuracy_10m_time",
                value: $0.cumulativeNearestTenMetersAccuracyTime
            )
            captureMetric(
                key: "accuracy_100m_time",
                value: $0.cumulativeHundredMetersAccuracyTime
            )
            captureMetric(key: "accuracy_1km_time", value: $0.cumulativeKilometerAccuracyTime)
            captureMetric(
                key: "accuracy_3km_time",
                value: $0.cumulativeThreeKilometersAccuracyTime
            )
        }
        withCategory(payload.networkTransferMetrics, "network_transfer") {
            captureMetric(key: "cellular_download", value: $0.cumulativeCellularDownload)
            captureMetric(key: "cellular_upload", value: $0.cumulativeCellularUpload)
            captureMetric(key: "wifi_download", value: $0.cumulativeWifiDownload)
            captureMetric(key: "wifi_upload", value: $0.cumulativeWifiUpload)
        }
        if #available(iOS 14.0, *) {
            withCategory(payload.applicationExitMetrics, "app_exit") {
                withCategory($0.foregroundExitData, "foreground") {
                    captureMetric(
                        key: "abnormal_exit_count",
                        value: $0.cumulativeAbnormalExitCount
                    )
                    captureMetric(
                        key: "app_watchdog_exit_count",
                        value: $0.cumulativeAppWatchdogExitCount
                    )
                    captureMetric(
                        key: "bad_access_exit_count",
                        value: $0.cumulativeBadAccessExitCount
                    )
                    captureMetric(
                        key: "illegal_instruction_exit_count",
                        value: $0.cumulativeIllegalInstructionExitCount
                    )
                    captureMetric(
                        key: "memory_resource_limit_exit-count",
                        value: $0.cumulativeMemoryResourceLimitExitCount
                    )
                    captureMetric(
                        key: "normal_app_exit_count",
                        value: $0.cumulativeNormalAppExitCount
                    )
                }

                withCategory($0.backgroundExitData, "background") {
                    captureMetric(
                        key: "abnormal_exit_count",
                        value: $0.cumulativeAbnormalExitCount
                    )
                    captureMetric(
                        key: "app_watchdog_exit_count",
                        value: $0.cumulativeAppWatchdogExitCount
                    )
                    captureMetric(
                        key: "bad_access-exit_count",
                        value: $0.cumulativeBadAccessExitCount
                    )
                    captureMetric(
                        key: "normal_app_exit_count",
                        value: $0.cumulativeNormalAppExitCount
                    )
                    captureMetric(
                        key: "memory_pressure_exit_count",
                        value: $0.cumulativeMemoryPressureExitCount
                    )
                    captureMetric(
                        key: "illegal_instruction_exit_count",
                        value: $0.cumulativeIllegalInstructionExitCount
                    )
                    captureMetric(
                        key: "cpu_resource_limit_exit_count",
                        value: $0.cumulativeCPUResourceLimitExitCount
                    )
                    captureMetric(
                        key: "memory_resource_limit_exit_count",
                        value: $0.cumulativeMemoryResourceLimitExitCount
                    )
                    captureMetric(
                        key: "suspended_with_locked_file_exit_count",
                        value: $0.cumulativeSuspendedWithLockedFileExitCount
                    )
                    captureMetric(
                        key: "background_task_assertion_timeout_exit_count",
                        value: $0.cumulativeBackgroundTaskAssertionTimeoutExitCount
                    )
                }
            }
        }
        if #available(iOS 14.0, *) {
            withCategory(payload.animationMetrics, "animation") {
                captureMetric(key: "scroll_hitch_time_ratio", value: $0.scrollHitchTimeRatio)
            }
        }
        withCategory(payload.applicationTimeMetrics, "app_time") {
            captureMetric(
                key: "foreground_time",
                value: $0.cumulativeForegroundTime
            )
            captureMetric(
                key: "background_time",
                value: $0.cumulativeBackgroundTime
            )
            captureMetric(
                key: "background_audio_time",
                value: $0.cumulativeBackgroundAudioTime
            )
            captureMetric(
                key: "background_location_time",
                value: $0.cumulativeBackgroundLocationTime
            )
        }
        withCategory(payload.cellularConditionMetrics, "cellular_condition") {
            captureMetric(
                key: "cellular_condition_time_average",
                value: $0.histogrammedCellularConditionTime
            )
        }
        withCategory(payload.cpuMetrics, "cpu") {
            if #available(iOS 14.0, *) {
                captureMetric(key: "instruction_count", value: $0.cumulativeCPUInstructions)
            }
            captureMetric(key: "cpu_time", value: $0.cumulativeCPUTime)
        }
        withCategory(payload.gpuMetrics, "gpu") {
            captureMetric(key: "time", value: $0.cumulativeGPUTime)
        }
        withCategory(payload.diskIOMetrics, "diskio") {
            captureMetric(key: "logical_write_count", value: $0.cumulativeLogicalWrites)
        }
        withCategory(payload.memoryMetrics, "memory") {
            captureMetric(key: "peak_memory_usage", value: $0.peakMemoryUsage)
            captureMetric(
                key: "suspended_memory_average",
                value: $0.averageSuspendedMemory.averageMeasurement
            )
        }
        // Display metrics *only* has pixel luminance, and it's an MXAverage value.
        withCategory(payload.displayMetrics, "display") {
            if let averagePixelLuminance = $0.averagePixelLuminance {
                captureMetric(
                    key: "pixel_luminance_average",
                    value: averagePixelLuminance.averageMeasurement
                )
            }
        }

        // Signpost metrics are a little different from the other metrics, since they can have arbitrary names.
        if let signpostMetrics = payload.signpostMetrics {
            for signpostMetric in signpostMetrics {
                let span = getMetricKitTracer().spanBuilder(spanName: "MXSignpostMetric")
                    .startSpan()
                span.setAttribute(key: "signpost.name", value: signpostMetric.signpostName)
                span.setAttribute(
                    key: "signpost.category",
                    value: signpostMetric.signpostCategory
                )
                span.setAttribute(key: "signpost.count", value: signpostMetric.totalCount)
                if let intervalData = signpostMetric.signpostIntervalData {
                    if let cpuTime = intervalData.cumulativeCPUTime {
                        span.setAttribute(
                            key: "signpost.cpu_time",
                            value: cpuTime.attributeValue()
                        )
                    }
                    if let memoryAverage = intervalData.averageMemory {
                        span.setAttribute(
                            key: "signpost.memory_average",
                            value: memoryAverage.averageMeasurement.attributeValue()
                        )
                    }
                    if let logicalWriteCount = intervalData.cumulativeLogicalWrites {
                        span.setAttribute(
                            key: "signpost.logical_write_count",
                            value: logicalWriteCount.attributeValue()
                        )
                    }
                    if #available(iOS 15.0, *) {
                        if let hitchTimeRatio = intervalData.cumulativeHitchTimeRatio {
                            span.setAttribute(
                                key: "signpost.hitch_time_ratio",
                                value: hitchTimeRatio.attributeValue()
                            )
                        }
                    }
                }
                span.end()
            }
        }
    }

    @available(iOS 14.0, macOS 12.0, macCatalyst 14.0, visionOS 1.0, *)
    public func reportDiagnostics(payload: MXDiagnosticPayload) {
        let span = getMetricKitTracer().spanBuilder(spanName: "MXDiagnosticPayload")
            .setStartTime(time: payload.timeStampBegin)
            .startSpan()
        defer { span.end() }

        let logger = OpenTelemetry.instance.loggerProvider.get(
            instrumentationScopeName: metricKitInstrumentationName
        )

        let now = Date()

        // A helper for looping over the items in an optional list and logging each one.
        func logForEach<T>(
            _ parent: [T]?,
            _ namespace: String,
            using closure: (T) -> ([String: AttributeValueConvertable], [String: AttributeValueConvertable])
        ) {
            if let arr = parent {
                for item in arr {
                    var attributes: [String: AttributeValue] = [
                        "name": "metrickit.diagnostic.\(namespace)".attributeValue()
                    ]
                    let (namespacedAttrs, globalAttrs) = closure(item)

                    // Add namespaced attributes with prefix
                    for (key, value) in namespacedAttrs {
                        let namespacedKey = "metrickit.diagnostic.\(namespace).\(key)"
                        attributes[namespacedKey] = value.attributeValue()
                    }

                    // Add global attributes without prefix (for standard OTel attributes)
                    for (key, value) in globalAttrs {
                        attributes[key] = value.attributeValue()
                    }

                    logger.logRecordBuilder()
                        .setTimestamp(payload.timeStampEnd)
                        .setObservedTimestamp(now)
                        .setAttributes(attributes)
                        .emit()
                }
            }
        }

        #if !os(macOS)
        if #available(iOS 16.0, *) {
            logForEach(payload.appLaunchDiagnostics, "app_launch") {
                (["launch_duration": $0.launchDuration], [:])
            }
        }
        #endif

        logForEach(payload.diskWriteExceptionDiagnostics, "disk_write_exception") {
            (["total_writes_caused": $0.totalWritesCaused], [:])
        }
        logForEach(payload.hangDiagnostics, "hang") {
            let callStackTree = $0.callStackTree
            let appleJson = callStackTree.jsonRepresentation()

            // Transform to simplified format, fall back to original if transformation fails
            let stacktraceData = transformStackTrace(appleJson) ?? appleJson
            let stacktraceJson = String(decoding: stacktraceData, as: UTF8.self)

            let namespacedAttrs: [String: AttributeValueConvertable] = [
                "hang_duration": $0.hangDuration
            ]

            let globalAttrs: [String: AttributeValueConvertable] = [
                "exception.stacktrace": stacktraceJson
            ]

            return (namespacedAttrs, globalAttrs)
        }
        logForEach(payload.cpuExceptionDiagnostics, "cpu_exception") {
            ([
                "total_cpu_time": $0.totalCPUTime,
                "total_sampled_time": $0.totalSampledTime,
            ], [:])
        }
        logForEach(payload.crashDiagnostics, "crash") {
            var namespacedAttrs: [String: AttributeValueConvertable] = [:]
            var globalAttrs: [String: AttributeValueConvertable] = [:]

            // Standard OTel exception attributes - will be populated below
            var otelType: String?
            var otelMessage: String?

            if let exceptionCode = $0.exceptionCode {
                namespacedAttrs["exception.code"] = exceptionCode.intValue
            }
            if let signal = $0.signal {
                namespacedAttrs["exception.signal"] = signal.intValue
                let signalName = signalNameMap[signal.int32Value]
                    ?? "Unknown signal: \(String(describing: signal))"
                namespacedAttrs["exception.signal.name"] = signalName
                let signalDescription = signalDescriptionMap[signal.int32Value]
                    ?? "Unknown signal: \(String(describing: signal))"
                namespacedAttrs["exception.signal.description"] = signalDescription

                // Use signal for OTel attributes if we don't have anything better
                if otelType == nil {
                    otelType = signalName
                    otelMessage = signalDescription
                }
            }
            if let exceptionType = $0.exceptionType {
                namespacedAttrs["exception.mach_exception.type"] = exceptionType.intValue
                let machExceptionName = exceptionNameMap[exceptionType.int32Value]
                    ?? "Unknown exception type: \(String(describing: exceptionType))"
                namespacedAttrs["exception.mach_exception.name"] = machExceptionName
                let machExceptionDescription = exceptionDescriptionMap[exceptionType.int32Value]
                    ?? "Unknown exception type: \(String(describing: exceptionType))"
                namespacedAttrs["exception.mach_exception.description"] = machExceptionDescription

                // Prefer Mach exception over signal for OTel attributes
                otelType = machExceptionName
                otelMessage = machExceptionDescription
            }
            if let terminationReason = $0.terminationReason {
                namespacedAttrs["exception.termination_reason"] = terminationReason
            }
            let callStackTree = $0.callStackTree
            let appleJson = callStackTree.jsonRepresentation()

            // Transform to simplified format, fall back to original if transformation fails
            let stacktraceData = transformStackTrace(appleJson) ?? appleJson
            let stacktraceJson = String(decoding: stacktraceData, as: UTF8.self)

            // Standard OTel exception attribute (without namespace prefix)
            globalAttrs["exception.stacktrace"] = stacktraceJson

            if #available(iOS 17.0, macOS 14.0, *) {
                if let exceptionReason = $0.exceptionReason {
                    namespacedAttrs["exception.objc.type"] = exceptionReason.exceptionType
                    let objcMessage = exceptionReason.composedMessage
                    namespacedAttrs["exception.objc.message"] = objcMessage
                    namespacedAttrs["exception.objc.classname"] = exceptionReason.className
                    let objcName = exceptionReason.exceptionName
                    namespacedAttrs["exception.objc.name"] = objcName

                    // Prefer Objective-C exception info for OTel attributes (most specific)
                    otelType = objcName
                    otelMessage = objcMessage
                }
            }

            // Set standard OTel exception attributes (without namespace prefix)
            if let type = otelType {
                globalAttrs["exception.type"] = type
            }
            if let message = otelMessage {
                globalAttrs["exception.message"] = message
            }

            return (namespacedAttrs, globalAttrs)
        }
    }

    // names/descriptions taken from exception_types.h
    let exceptionNameMap: [Int32: String] = [
        EXC_BAD_ACCESS: "EXC_BAD_ACCESS",
        EXC_BAD_INSTRUCTION: "EXC_BAD_INSTRUCTION",
        EXC_ARITHMETIC: "EXC_ARITHMETIC",
        EXC_EMULATION: "EXC_EMULATION",
        EXC_SOFTWARE: "EXC_SOFTWARE",
        EXC_BREAKPOINT: "EXC_BREAKPOINT",
        EXC_SYSCALL: "EXC_SYSCALL",
        EXC_MACH_SYSCALL: "EXC_MACH_SYSCALL",
        EXC_RPC_ALERT: "EXC_RPC_ALERT",
        EXC_CRASH: "EXC_CRASH",
        EXC_RESOURCE: "EXC_RESOURCE",
        EXC_GUARD: "EXC_GUARD",
        EXC_CORPSE_NOTIFY: "EXC_CORPSE_NOTIFY",
    ]
    let exceptionDescriptionMap: [Int32: String] = [
        EXC_BAD_ACCESS: "Could not access memory",
        EXC_BAD_INSTRUCTION: "Instruction failed",
        EXC_ARITHMETIC: "Arithmetic exception",
        EXC_EMULATION: "Emulation instruction",
        EXC_SOFTWARE: "Software generated exception",
        EXC_BREAKPOINT: "Trace, breakpoint, etc.",
        EXC_SYSCALL: "System calls.",
        EXC_MACH_SYSCALL: "Mach system calls.",
        EXC_RPC_ALERT: "RPC alert",
        EXC_CRASH: "Abnormal process exit",
        EXC_RESOURCE: "Hit resource consumption limit",
        EXC_GUARD: "Violated guarded resource protections",
        EXC_CORPSE_NOTIFY: "Abnormal process exited to corpse state",
    ]

    // names/descriptions taken from signal.h
    let signalNameMap: [Int32: String] = [
        SIGHUP: "SIGHUP",
        SIGINT: "SIGINT",
        SIGQUIT: "SIGQUIT",
        SIGILL: "SIGILL",
        SIGTRAP: "SIGTRAP",
        SIGABRT: "SIGABRT",
        SIGEMT: "SIGEMT",
        SIGFPE: "SIGFPE",
        SIGKILL: "SIGKILL",
        SIGBUS: "SIGBUS",
        SIGSEGV: "SIGSEGV",
        SIGSYS: "SIGSYS",
        SIGPIPE: "SIGPIPE",
        SIGALRM: "SIGALRM",
        SIGTERM: "SIGTERM",
        SIGURG: "SIGURG",
        SIGSTOP: "SIGSTOP",
        SIGTSTP: "SIGTSTP",
        SIGCONT: "SIGCONT",
        SIGCHLD: "SIGCHLD",
        SIGTTIN: "SIGTTIN",
        SIGTTOU: "SIGTTOU",
        SIGIO: "SIGIO",
        SIGXCPU: "SIGXCPU",
        SIGXFSZ: "SIGXFSZ",
        SIGVTALRM: "SIGVTALRM",
        SIGPROF: "SIGPROF",
        SIGWINCH: "SIGWINCH",
        SIGINFO: "SIGINFO",
        SIGUSR1: "SIGUSR1",
        SIGUSR2: "SIGUSR2",
    ]

    let signalDescriptionMap: [Int32: String] = [
        SIGHUP: "hangup",
        SIGINT: "interrupt",
        SIGQUIT: "quit",
        SIGILL: "illegal instruction (not reset when caught)",
        SIGTRAP: "trace trap (not reset when caught)",
        SIGABRT: "abort()",
        SIGEMT: "EMT instruction",
        SIGFPE: "floating point exception",
        SIGKILL: "kill (cannot be caught or ignored)",
        SIGBUS: "bus error",
        SIGSEGV: "segmentation violation",
        SIGSYS: "bad argument to system call",
        SIGPIPE: "write on a pipe with no one to read it",
        SIGALRM: "alarm clock",
        SIGTERM: "software termination signal from kill",
        SIGURG: "urgent condition on IO channel",
        SIGSTOP: "sendable stop signal not from tty",
        SIGTSTP: "stop signal from tty",
        SIGCONT: "continue a stopped process",
        SIGCHLD: "to parent on child stop or exit",
        SIGTTIN: "to readers pgrp upon background tty read",
        SIGTTOU: "like TTIN for output if (tp->t_local&LTOSTOP)",
        SIGIO: "input/output possible signal",
        SIGXCPU: "exceeded CPU time limit",
        SIGXFSZ: "exceeded file size limit",
        SIGVTALRM: "virtual time alarm",
        SIGPROF: "profiling time alarm",
        SIGWINCH: "window size changes",
        SIGINFO: "information request",
        SIGUSR1: "user defined signal 1",
        SIGUSR2: "user defined signal 2",
    ]
#endif

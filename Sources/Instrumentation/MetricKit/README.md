# MetricKit Instrumentation

This instrumentation adds MetricKit signals to OpenTelemetry, capturing performance metrics and diagnostic data from Apple's MetricKit framework. MetricKit provides aggregated data about your app's performance and diagnostics, reported approximately once per day with cumulative data from the previous 24-hour period.

All data is captured using the instrumentation scope `"MetricKit"` with version `"0.0.1"`.

## Usage

To use the MetricKit instrumentation, register it with MetricKit's metric manager:

```swift
import MetricKit
import OpenTelemetryApi

// Initialize OpenTelemetry providers (tracer and logger)
// ... your OpenTelemetry setup code ...

// Register the MetricKit instrumentation
// IMPORTANT: Store the instrumentation instance in a static or app-level variable.
// MXMetricManager.shared holds only a weak reference, so if the instance
// is released, it won't receive MetricKit callbacks.
if #available(iOS 13.0, *) {
    let metricKit = MetricKitInstrumentation()
    MXMetricManager.shared.add(metricKit)

    // Store instrumentation somewhere to keep it alive, e.g.:
    // AppDelegate.metricKitInstrumentation = metricKit
}
```

The instrumentation will automatically receive MetricKit payloads and convert them to OpenTelemetry spans and logs.

## Data Structure Overview

MetricKit reports data in two categories: **Metrics** and **Diagnostics**.

### Why Traces Instead of OTel Metrics?

This instrumentation represents MetricKit data as OpenTelemetry traces (spans) rather than OTel metrics for several reasons:

1. **Pre-aggregated data**: MetricKit data is already aggregated over 24 hours, not individual measurements, so OTel metric semantics (counters, gauges, histograms with live aggregation) don't map naturally
2. **Timing semantics**: The data represents activity over a 24-hour period, not point-in-time measurements. Using spans with start/end times better represents this temporal nature
3. **API simplicity**: The OpenTelemetry metrics API is complex, and spans provide a simpler way to represent this pre-aggregated, time-windowed data

## Units

All MetricKit measurements have units (e.g., "1 kb" or "3 hours"). When converted to attributes, they are normalized to base units (bytes, seconds, etc.) and represented as doubles.

## Timestamps

All data in MetricKit payloads includes two timestamps:

- **`timeStampBegin`**: The start of the 24-hour reporting period
- **`timeStampEnd`**: The end of the reporting period

For metrics spans, `timeStampBegin` is used as the span start time and `timeStampEnd` as the span end time, so spans are typically 24 hours long.

For diagnostics, both `timestamp` (set to `timeStampEnd`) and `observedTimestamp` (set to the current time when the log is emitted) are included. `timeStampEnd` is used so that diagnostic events appear as "new" data in observability systems when they arrive, even though the actual event occurred sometime during the 24-hour period.

## MXMetricPayload

Metrics are pre-aggregated measurements over the reporting period, such as "total CPU time" and "number of abnormal exits".

### Data Representation

For metrics, a single span named `"MXMetricPayload"` is reported. The span's start time is the beginning of the reporting period and the end time is the end of the period (typically 24 hours). Each metric is included as an attribute on this span, with attributes namespaced by their category in MXMetricPayload (e.g., `metrickit.app_exit.foreground.abnormal_exit_count`, `metrickit.cpu.cpu_time`).

For histogram data, only the average value is estimated and reported.

### Attribute Reference

| Attribute Name | Type | Units | Apple Documentation |
|----------------|------|-------|---------------------|
| `metrickit.includes_multiple_application_versions` | bool | - | [includesMultipleApplicationVersions](https://developer.apple.com/documentation/metrickit/mxmetricpayload/includesmultipleapplicationversions) |
| `metrickit.latest_application_version` | string | - | [latestApplicationVersion](https://developer.apple.com/documentation/metrickit/mxmetricpayload/latestapplicationversion) |
| `metrickit.timestamp_begin` | double | seconds (Unix epoch) | [timeStampBegin](https://developer.apple.com/documentation/metrickit/mxmetricpayload/timestampbegin) |
| `metrickit.timestamp_end` | double | seconds (Unix epoch) | [timeStampEnd](https://developer.apple.com/documentation/metrickit/mxmetricpayload/timestampend) |
| **CPU Metrics** | | | [MXCPUMetric](https://developer.apple.com/documentation/metrickit/mxcpumetric) |
| `metrickit.cpu.cpu_time` | double | seconds | [cumulativeCPUTime](https://developer.apple.com/documentation/metrickit/mxcpumetric/cumulativecputime) |
| `metrickit.cpu.instruction_count` | double | instructions | [cumulativeCPUInstructions](https://developer.apple.com/documentation/metrickit/mxcpumetric/cumulativecpuinstructions) (iOS 14+) |
| **GPU Metrics** | | | [MXGPUMetric](https://developer.apple.com/documentation/metrickit/mxgpumetric) |
| `metrickit.gpu.time` | double | seconds | [cumulativeGPUTime](https://developer.apple.com/documentation/metrickit/mxgpumetric/cumulativegputime) |
| **Cellular Metrics** | | | [MXCellularConditionMetric](https://developer.apple.com/documentation/metrickit/mxcellularconditionmetric) |
| `metrickit.cellular_condition.bars_average` | double | bars | [histogrammedCellularConditionTime](https://developer.apple.com/documentation/metrickit/mxcellularconditionmetric/histogrammedcellularconditiontime) |
| **App Time Metrics** | | | [MXAppRunTimeMetric](https://developer.apple.com/documentation/metrickit/mxappruntimemetric) |
| `metrickit.app_time.foreground_time` | double | seconds | [cumulativeForegroundTime](https://developer.apple.com/documentation/metrickit/mxappruntimemetric/cumulativeforegroundtime) |
| `metrickit.app_time.background_time` | double | seconds | [cumulativeBackgroundTime](https://developer.apple.com/documentation/metrickit/mxappruntimemetric/cumulativebackgroundtime) |
| `metrickit.app_time.background_audio_time` | double | seconds | [cumulativeBackgroundAudioTime](https://developer.apple.com/documentation/metrickit/mxappruntimemetric/cumulativebackgroundaudiotime) |
| `metrickit.app_time.background_location_time` | double | seconds | [cumulativeBackgroundLocationTime](https://developer.apple.com/documentation/metrickit/mxappruntimemetric/cumulativebackgroundlocationtime) |
| **Location Activity Metrics** | | | [MXLocationActivityMetric](https://developer.apple.com/documentation/metrickit/mxlocationactivitymetric) |
| `metrickit.location_activity.best_accuracy_time` | double | seconds | [cumulativeBestAccuracyTime](https://developer.apple.com/documentation/metrickit/mxlocationactivitymetric/cumulativebestaccuracytime) |
| `metrickit.location_activity.best_accuracy_for_nav_time` | double | seconds | [cumulativeBestAccuracyForNavigationTime](https://developer.apple.com/documentation/metrickit/mxlocationactivitymetric/cumulativebestaccuracyfornavigationtime) |
| `metrickit.location_activity.accuracy_10m_time` | double | seconds | [cumulativeNearestTenMetersAccuracyTime](https://developer.apple.com/documentation/metrickit/mxlocationactivitymetric/cumulativenearesttenmetersaccuracytime) |
| `metrickit.location_activity.accuracy_100m_time` | double | seconds | [cumulativeHundredMetersAccuracyTime](https://developer.apple.com/documentation/metrickit/mxlocationactivitymetric/cumulativehundredmetersaccuracytime) |
| `metrickit.location_activity.accuracy_1km_time` | double | seconds | [cumulativeKilometerAccuracyTime](https://developer.apple.com/documentation/metrickit/mxlocationactivitymetric/cumulativekilometeraccuracytime) |
| `metrickit.location_activity.accuracy_3km_time` | double | seconds | [cumulativeThreeKilometersAccuracyTime](https://developer.apple.com/documentation/metrickit/mxlocationactivitymetric/cumulativethreekilometersaccuracytime) |
| **Network Transfer Metrics** | | | [MXNetworkTransferMetric](https://developer.apple.com/documentation/metrickit/mxnetworktransfermetric) |
| `metrickit.network_transfer.wifi_upload` | double | bytes | [cumulativeWifiUpload](https://developer.apple.com/documentation/metrickit/mxnetworktransfermetric/cumulativewifiupload) |
| `metrickit.network_transfer.wifi_download` | double | bytes | [cumulativeWifiDownload](https://developer.apple.com/documentation/metrickit/mxnetworktransfermetric/cumulativewifidownload) |
| `metrickit.network_transfer.cellular_upload` | double | bytes | [cumulativeCellularUpload](https://developer.apple.com/documentation/metrickit/mxnetworktransfermetric/cumulativecellularupload) |
| `metrickit.network_transfer.cellular_download` | double | bytes | [cumulativeCellularDownload](https://developer.apple.com/documentation/metrickit/mxnetworktransfermetric/cumulativecellulardownload) |
| **App Launch Metrics** | | | [MXAppLaunchMetric](https://developer.apple.com/documentation/metrickit/mxapplaunchmetric) |
| `metrickit.app_launch.time_to_first_draw_average` | double | seconds | [histogrammedTimeToFirstDraw](https://developer.apple.com/documentation/metrickit/mxapplaunchmetric/histogrammedtimetofirstdraw) (average) |
| `metrickit.app_launch.app_resume_time_average` | double | seconds | [histogrammedApplicationResumeTime](https://developer.apple.com/documentation/metrickit/mxapplaunchmetric/histogrammedapplicationresumetime) (average) |
| `metrickit.app_launch.optimized_time_to_first_draw_average` | double | seconds | [histogrammedOptimizedTimeToFirstDraw](https://developer.apple.com/documentation/metrickit/mxapplaunchmetric/histogrammedoptimizedtimetofirstdraw) (average, iOS 15.2+) |
| `metrickit.app_launch.extended_launch_average` | double | seconds | [histogrammedExtendedLaunch](https://developer.apple.com/documentation/metrickit/mxapplaunchmetric/histogrammedextendedlaunch) (average, iOS 16+) |
| **App Responsiveness Metrics** | | | [MXAppResponsivenessMetric](https://developer.apple.com/documentation/metrickit/mxappresponsivenessmetric) |
| `metrickit.app_responsiveness.hang_time_average` | double | seconds | [histogrammedApplicationHangTime](https://developer.apple.com/documentation/metrickit/mxappresponsivenessmetric/histogrammedapplicationhangtime) (average) |
| **Disk I/O Metrics** | | | [MXDiskIOMetric](https://developer.apple.com/documentation/metrickit/mxdiskiometric) |
| `metrickit.diskio.logical_write_count` | double | bytes | [cumulativeLogicalWrites](https://developer.apple.com/documentation/metrickit/mxdiskiometric/cumulativelogicalwrites) |
| **Memory Metrics** | | | [MXMemoryMetric](https://developer.apple.com/documentation/metrickit/mxmemorymetric) |
| `metrickit.memory.peak_memory_usage` | double | bytes | [peakMemoryUsage](https://developer.apple.com/documentation/metrickit/mxmemorymetric/peakmemoryusage) |
| `metrickit.memory.suspended_memory_average` | double | bytes | [averageSuspendedMemory](https://developer.apple.com/documentation/metrickit/mxmemorymetric/averagesuspendedmemory) (average) |
| **Display Metrics** | | | [MXDisplayMetric](https://developer.apple.com/documentation/metrickit/mxdisplaymetric) |
| `metrickit.display.pixel_luminance_average` | double | APL (average pixel luminance) | [averagePixelLuminance](https://developer.apple.com/documentation/metrickit/mxdisplaymetric/averagepixelluminance) (average) |
| **Animation Metrics** | | | [MXAnimationMetric](https://developer.apple.com/documentation/metrickit/mxanimationmetric) |
| `metrickit.animation.scroll_hitch_time_ratio` | double | ratio (dimensionless) | [scrollHitchTimeRatio](https://developer.apple.com/documentation/metrickit/mxanimationmetric/scrollhitchtimeratio) (iOS 14+) |
| **Metadata** | | | [MXMetaData](https://developer.apple.com/documentation/metrickit/mxmetadata) |
| `metrickit.metadata.pid` | int | - | [pid](https://developer.apple.com/documentation/metrickit/mxmetadata/pid) (iOS 17+) |
| `metrickit.metadata.app_build_version` | string | - | [applicationBuildVersion](https://developer.apple.com/documentation/metrickit/mxmetadata/applicationbuildversion) |
| `metrickit.metadata.device_type` | string | - | [deviceType](https://developer.apple.com/documentation/metrickit/mxmetadata/devicetype) |
| `metrickit.metadata.is_test_flight_app` | bool | - | [isTestFlightApp](https://developer.apple.com/documentation/metrickit/mxmetadata/istestflightapp) (iOS 17+) |
| `metrickit.metadata.low_power_mode_enabled` | bool | - | [lowPowerModeEnabled](https://developer.apple.com/documentation/metrickit/mxmetadata/lowpowermodeenabled) (iOS 17+) |
| `metrickit.metadata.os_version` | string | - | [osVersion](https://developer.apple.com/documentation/metrickit/mxmetadata/osversion) |
| `metrickit.metadata.platform_arch` | string | - | [platformArchitecture](https://developer.apple.com/documentation/metrickit/mxmetadata/platformarchitecture) (iOS 14+) |
| `metrickit.metadata.region_format` | string | - | [regionFormat](https://developer.apple.com/documentation/metrickit/mxmetadata/regionformat) |
| **App Exit Metrics - Foreground** | | | [MXForegroundExitData](https://developer.apple.com/documentation/metrickit/mxforegroundexitdata) |
| `metrickit.app_exit.foreground.normal_app_exit_count` | int | count | [cumulativeNormalAppExitCount](https://developer.apple.com/documentation/metrickit/mxforegroundexitdata/cumulativenormalappexitcount) |
| `metrickit.app_exit.foreground.memory_resource_limit_exit-count` | int | count | [cumulativeMemoryResourceLimitExitCount](https://developer.apple.com/documentation/metrickit/mxforegroundexitdata/cumulativememoryresourcelimitexitcount) |
| `metrickit.app_exit.foreground.bad_access_exit_count` | int | count | [cumulativeBadAccessExitCount](https://developer.apple.com/documentation/metrickit/mxforegroundexitdata/cumulativebadaccessexitcount) |
| `metrickit.app_exit.foreground.abnormal_exit_count` | int | count | [cumulativeAbnormalExitCount](https://developer.apple.com/documentation/metrickit/mxforegroundexitdata/cumulativeabnormalexitcount) |
| `metrickit.app_exit.foreground.illegal_instruction_exit_count` | int | count | [cumulativeIllegalInstructionExitCount](https://developer.apple.com/documentation/metrickit/mxforegroundexitdata/cumulativeillegalinstructionexitcount) |
| `metrickit.app_exit.foreground.app_watchdog_exit_count` | int | count | [cumulativeAppWatchdogExitCount](https://developer.apple.com/documentation/metrickit/mxforegroundexitdata/cumulativeappwatchdogexitcount) |
| **App Exit Metrics - Background** | | | [MXBackgroundExitData](https://developer.apple.com/documentation/metrickit/mxbackgroundexitdata) |
| `metrickit.app_exit.background.normal_app_exit_count` | int | count | [cumulativeNormalAppExitCount](https://developer.apple.com/documentation/metrickit/mxbackgroundexitdata/cumulativenormalappexitcount) |
| `metrickit.app_exit.background.memory_resource_limit_exit_count` | int | count | [cumulativeMemoryResourceLimitExitCount](https://developer.apple.com/documentation/metrickit/mxbackgroundexitdata/cumulativememoryresourcelimitexitcount) |
| `metrickit.app_exit.background.cpu_resource_limit_exit_count` | int | count | [cumulativeCPUResourceLimitExitCount](https://developer.apple.com/documentation/metrickit/mxbackgroundexitdata/cumulativecpuresourcelimitexitcount) |
| `metrickit.app_exit.background.memory_pressure_exit_count` | int | count | [cumulativeMemoryPressureExitCount](https://developer.apple.com/documentation/metrickit/mxbackgroundexitdata/cumulativememorypressureexitcount) |
| `metrickit.app_exit.background.bad_access-exit_count` | int | count | [cumulativeBadAccessExitCount](https://developer.apple.com/documentation/metrickit/mxbackgroundexitdata/cumulativebadaccessexitcount) |
| `metrickit.app_exit.background.abnormal_exit_count` | int | count | [cumulativeAbnormalExitCount](https://developer.apple.com/documentation/metrickit/mxbackgroundexitdata/cumulativeabnormalexitcount) |
| `metrickit.app_exit.background.illegal_instruction_exit_count` | int | count | [cumulativeIllegalInstructionExitCount](https://developer.apple.com/documentation/metrickit/mxbackgroundexitdata/cumulativeillegalinstructionexitcount) |
| `metrickit.app_exit.background.app_watchdog_exit_count` | int | count | [cumulativeAppWatchdogExitCount](https://developer.apple.com/documentation/metrickit/mxbackgroundexitdata/cumulativeappwatchdogexitcount) |
| `metrickit.app_exit.background.suspended_with_locked_file_exit_count` | int | count | [cumulativeSuspendedWithLockedFileExitCount](https://developer.apple.com/documentation/metrickit/mxbackgroundexitdata/cumulativesuspendedwithlockedfileexitcount) |
| `metrickit.app_exit.background.background_task_assertion_timeout_exit_count` | int | count | [cumulativeBackgroundTaskAssertionTimeoutExitCount](https://developer.apple.com/documentation/metrickit/mxbackgroundexitdata/cumulativebackgroundtaskassertiontimeoutexitcount) |

## MXSignpostMetric

Signpost metrics are custom performance measurements you define in your app using [os_signpost](https://developer.apple.com/documentation/os/logging/recording_performance_data). Unlike the other MetricKit metrics which are aggregated into a single span, each signpost metric generates its own individual span.

### Data Representation

Each signpost metric creates a separate span named `"MXSignpostMetric"` with attributes describing the signpost's category, name, count, and performance measurements. The instrumentation scope is `"MetricKit"`.

### Attribute Reference

| Attribute Name | Type | Units | Apple Documentation |
|----------------|------|-------|---------------------|
| `signpost.name` | string | - | [signpostName](https://developer.apple.com/documentation/metrickit/mxsignpostmetric/signpostname) |
| `signpost.category` | string | - | [signpostCategory](https://developer.apple.com/documentation/metrickit/mxsignpostmetric/signpostcategory) |
| `signpost.count` | int | count | [totalCount](https://developer.apple.com/documentation/metrickit/mxsignpostmetric/totalcount) |
| `signpost.cpu_time` | double | seconds | [cumulativeCPUTime](https://developer.apple.com/documentation/metrickit/mxsignpostintervaldata/cumulativecputime) |
| `signpost.memory_average` | double | bytes | [averageMemory](https://developer.apple.com/documentation/metrickit/mxsignpostintervaldata/averagememory) (average) |
| `signpost.logical_write_count` | double | bytes | [cumulativeLogicalWrites](https://developer.apple.com/documentation/metrickit/mxsignpostintervaldata/cumulativelogicalwrites) |
| `signpost.hitch_time_ratio` | double | ratio (dimensionless) | [cumulativeHitchTimeRatio](https://developer.apple.com/documentation/metrickit/mxsignpostintervaldata/cumulativehitchtimeratio) (iOS 15+) |

## MXDiagnosticPayload

Diagnostics are individual events that occurred during the reporting period, such as crashes, hangs, and exceptions. Unlike metrics which are aggregated, each diagnostic represents a discrete event, though the exact time it occurred within the 24-hour window is not known.

### Data Representation

For diagnostics, a parent span named `"MXDiagnosticPayload"` is created spanning the reporting period (start time = `timeStampBegin`, end time = `timeStampEnd`). For each diagnostic event, an OpenTelemetry log record is emitted (not a span, since each event is instantaneous). Each log has:

- A `name` attribute identifying the diagnostic type (e.g., `"metrickit.diagnostic.crash"`)
- Additional attributes with diagnostic details, all namespaced by type (e.g., `metrickit.diagnostic.crash.exception.code`)
- A `timestamp` set to `timeStampEnd` (so the event appears as "new" when it arrives)
- An `observedTimestamp` set to the current time when the log is emitted

The instrumentation scope is `"MetricKit"`.

### Log Names

Each diagnostic log includes a `name` attribute that identifies its type:

- `metrickit.diagnostic.cpu_exception`
- `metrickit.diagnostic.disk_write_exception`
- `metrickit.diagnostic.hang`
- `metrickit.diagnostic.crash`
- `metrickit.diagnostic.app_launch` (iOS 16+, not available on macOS)

### OpenTelemetry Semantic Conventions

This instrumentation extends the standard OpenTelemetry [exception semantic conventions](https://opentelemetry.io/docs/specs/semconv/exceptions/exceptions-logs/) with additional MetricKit-specific attributes. The standard OTel attributes for exceptions are:

- `exception.type` - The exception type/class name
- `exception.message` - The exception message
- `exception.stacktrace` - The stacktrace as a string

For MetricKit crash diagnostics, additional attributes are added in the `metrickit.diagnostic.crash.*` namespace to capture MetricKit's rich exception data (Mach exception types, signal numbers, Objective-C exception details).

#### How Standard Exception Attributes Are Derived

For **crash diagnostics**, `exception.type` and `exception.message` are derived from the most specific available information using the following priority order (highest to lowest):

1. **Objective-C exception info** (iOS 17+, highest priority) - Uses `objc.name` for type and `objc.message` for message
2. **Mach exception info** - Uses `mach_exception.name` for type and `mach_exception.description` for message
3. **POSIX signal info** (lowest priority) - Uses `signal.name` for type and `signal.description` for message

For **hang diagnostics**, only `exception.stacktrace` is set (from `callStackTree`). No `exception.type` or `exception.message` is provided since hangs don't have exception objects.

The `exception.stacktrace` attribute is always set to the JSON representation of the `callStackTree` for both crashes and hangs.

### Attribute Reference

| Attribute Name | Type | Units | Apple Documentation |
|----------------|------|-------|---------------------|
| **CPU Exception Diagnostics** | | | [MXCPUExceptionDiagnostic](https://developer.apple.com/documentation/metrickit/mxcpuexceptiondiagnostic) |
| `metrickit.diagnostic.cpu_exception.total_cpu_time` | double | seconds | [totalCPUTime](https://developer.apple.com/documentation/metrickit/mxcpuexceptiondiagnostic/totalcputime) |
| `metrickit.diagnostic.cpu_exception.total_sampled_time` | double | seconds | [totalSampledTime](https://developer.apple.com/documentation/metrickit/mxcpuexceptiondiagnostic/totalsampledtime) |
| **Disk Write Exception Diagnostics** | | | [MXDiskWriteExceptionDiagnostic](https://developer.apple.com/documentation/metrickit/mxdiskwriteexceptiondiagnostic) |
| `metrickit.diagnostic.disk_write_exception.total_writes_caused` | double | bytes | [totalWritesCaused](https://developer.apple.com/documentation/metrickit/mxdiskwriteexceptiondiagnostic/totalwritescaused) |
| **Hang Diagnostics** | | | [MXHangDiagnostic](https://developer.apple.com/documentation/metrickit/mxhangdiagnostic) |
| `metrickit.diagnostic.hang.hang_duration` | double | seconds | [hangDuration](https://developer.apple.com/documentation/metrickit/mxhangdiagnostic/hangduration) |
| **Crash Diagnostics** | | | [MXCrashDiagnostic](https://developer.apple.com/documentation/metrickit/mxcrashdiagnostic) |
| `metrickit.diagnostic.crash.exception.code` | int | - | [exceptionCode](https://developer.apple.com/documentation/metrickit/mxcrashdiagnostic/exceptioncode) |
| `metrickit.diagnostic.crash.exception.mach_exception.type` | int | - | [exceptionType](https://developer.apple.com/documentation/metrickit/mxcrashdiagnostic/exceptiontype) |
| `metrickit.diagnostic.crash.exception.mach_exception.name` | string | - | Human-readable name for the Mach exception type (e.g., "EXC_BAD_ACCESS") |
| `metrickit.diagnostic.crash.exception.mach_exception.description` | string | - | Description of the Mach exception type |
| `metrickit.diagnostic.crash.exception.signal` | int | - | [signal](https://developer.apple.com/documentation/metrickit/mxcrashdiagnostic/signal) |
| `metrickit.diagnostic.crash.exception.signal.name` | string | - | POSIX signal name (e.g., "SIGSEGV") |
| `metrickit.diagnostic.crash.exception.signal.description` | string | - | Description of the POSIX signal |
| `metrickit.diagnostic.crash.exception.termination_reason` | string | - | [terminationReason](https://developer.apple.com/documentation/metrickit/mxcrashdiagnostic/terminationreason) |
| `metrickit.diagnostic.crash.exception.objc.type` | string | - | [exceptionType](https://developer.apple.com/documentation/metrickit/mxcrashdiagnosticobjectivecexceptionreason/exceptiontype) (iOS 17+) |
| `metrickit.diagnostic.crash.exception.objc.message` | string | - | [composedMessage](https://developer.apple.com/documentation/metrickit/mxcrashdiagnosticobjectivecexceptionreason/composedmessage) (iOS 17+) |
| `metrickit.diagnostic.crash.exception.objc.name` | string | - | [exceptionName](https://developer.apple.com/documentation/metrickit/mxcrashdiagnosticobjectivecexceptionreason/exceptionname) (iOS 17+) |
| `metrickit.diagnostic.crash.exception.objc.classname` | string | - | [className](https://developer.apple.com/documentation/metrickit/mxcrashdiagnosticobjectivecexceptionreason/classname) (iOS 17+) |
| **App Launch Diagnostics** | | | [MXAppLaunchDiagnostic](https://developer.apple.com/documentation/metrickit/mxapplaunchdiagnostic) |
| `metrickit.diagnostic.app_launch.launch_duration` | double | seconds | [launchDuration](https://developer.apple.com/documentation/metrickit/mxapplaunchdiagnostic/launchduration) (iOS 16+, not on macOS) |

### Stacktrace Format

For details on the stack trace format used in crash and hang diagnostics, see [StackTraceFormat.md](StackTraceFormat.md).

**Note:** The instrumentation attempts to transform Apple's native MetricKit format into the simplified OpenTelemetry format described in StackTraceFormat.md. If the transformation fails for any reason (e.g., if the OS returns a stacktrace in a different format than documented), the stacktrace will be included as-is in its original format to ensure diagnostic data is never lost.

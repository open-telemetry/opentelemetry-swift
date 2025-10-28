# MetricKit Instrumentation

TOOD: Make sure the trace names, log names, and attribute key names are correct.
TODO: Document what the timestamps on all of the fields mean.
TODO: Double-check whether it's consistent with OpenTelemetry semantic conventions the way we're adding to the `exception` namespace.
TOOD: Make Cocoapods work.
TODO: Document why we're using traces instead of metrics.
TODO: Write a PR description.

This adds MetricKit signals to the Honeycomb Swift SDK.

This adds all of the data from Apple's MetricKit into Honeycomb. It's not obvious how to structure this data in order to best fit OTel semantics conventions while also being most usable in Honeycomb. I made my best guess how to do it, but would appreciate feedback on it. I am really not sure if this is the best way to represent this data. Here is how I'm structuring the data:

MetricKit reports a batch of data approximately once a day, with cumulative data from the previous day. There are two big categories of data: _Metrics_ and _Diagnostics_. These are covered below.

All of this data is captured using the scope `"@honeycombio/instrumentation-metric-kit"`

## Usage

TODO: Write instructions for how to use this instrumentation.

## Units

MetricKit measurements have units, so that a metric might report "1 kb" or "3 hours". To represent this data in attributes, they are all converted to the standard unit for their type (such as bytes or seconds) and represented as doubles.

## MXMetricPayload

Metrics are things like "total cpu time" and "number of abnormal exists". They are pre-aggregated over the reported period. For metrics, we report a single `Span` named `"MXMetricPayload"`. The start time of the span is the start of the reporting period, and the end of the span is the end time of the reporting period. So these spans are generally 24 hours long. Each metric is included as an attribute on that span. The attributes are namespaced corresponding to their category in `MXMetricPayload`. For example, the metrics mentioned above are named `metrickit.app_exit.foreground.abnormal_exit_count` and `metrickit.cpu.cpu_time`. For histogram data, we include only the estimated average value for now.

I used an OTel span instead of OTel metrics for a few reasons:
* Metrics usually go into a different dataset, and we want all the data in one place for a launchpad.
* The data is pre-aggregated, not individual values, so some of the OTel metric semantics don't make sense.
* The time the data is reported doesn't accurately reflect when the events occur. For example, we don't want to interpret 1000 cpu instructions over 24 hours as sitting idle for 23.999 hours and then suddenly bursting 1000 instructions.
* The Swift metrics APIs are confusing, and it's not clear how to represent some of the data.

TODO: Describe the fields in MXMetricPayload.

TODO: Rewrite this in english:
  scope="MetricKit"
  span="MXMetricPayload"

TODO: Turn this list into a markdown table with columns for (1) attribute name, with a link to the relevant Apple documentation for the equivalent MetricKit field, (2) the data type, and (3) the units of the attribute (not the comment).
  metrickit.includes_multiple_application_versions" bool)" false
  metrickit.latest_application_version" string)" '"3.14.159"'
  metrickit.cpu.cpu_time" double)" 1
  metrickit.cpu.instruction_count" double)" 2
  metrickit.gpu.time" double)" 10800  # 3 hours
  metrickit.cellular_condition.bars_average" double)" 4
  metrickit.app_time.foreground_time" double)" 300          # 5 minutes
  metrickit.app_time.background_time" double)" 0.000006     # 6 microseconds
  metrickit.app_time.background_audio_time" double)" 0.007  # 7 milliseconds
  metrickit.app_time.background_location_time" double)" 480 # 8 minutes
  metrickit.location_activity.best_accuracy_time" double)" 9
  metrickit.location_activity.best_accuracy_for_nav_time" double)" 10
  metrickit.location_activity.accuracy_10m_time" double)"  11
  metrickit.location_activity.accuracy_100m_time" double)" 12
  metrickit.location_activity.accuracy_1km_time" double)" 13
  metrickit.location_activity.accuracy_3km_time" double)" 14
  metrickit.network_transfer.wifi_upload" double)" 15                 # 15 B
  metrickit.network_transfer.wifi_download" double)" 16000            # 16 KB
  metrickit.network_transfer.cellular_upload" double)" 17000000       # 17 MB
  metrickit.network_transfer.cellular_download" double)" 18000000000  # 18 GB
  metrickit.app_launch.time_to_first_draw_average" double)" 1140            # 19 minutes
  metrickit.app_launch.app_resume_time_average" double)" 1200               # 20 minutes
  metrickit.app_launch.optimized_time_to_first_draw_average" double)" 1260  # 21 minutes
  metrickit.app_launch.extended_launch_average" double)" 1320               # 22 minutes
  metrickit.app_responsiveness.hang_time_average" double)" 82800  # 23 hours
  metrickit.diskio.logical_write_count" double)" 24000000000000  # 24 TB
  metrickit.memory.peak_memory_usage" double)" 25
  metrickit.memory.suspended_memory_average" double)" 26
  metrickit.display.pixel_luminance_average" double)" 27
  metrickit.animation.scroll_hitch_time_ratio" double)" 28
  metrickit.metadata.pid" int)" '"29"'
  metrickit.metadata.app_build_version" string)" '"build"'
  metrickit.metadata.device_type" string)" '"device"'
  metrickit.metadata.is_test_flight_app" bool)" true
  metrickit.metadata.low_power_mode_enabled" bool)" true
  metrickit.metadata.os_version" string)" '"os"'
  metrickit.metadata.platform_arch" string)" '"arch"'
  metrickit.metadata.region_format" string)" '"format"'
  metrickit.app_exit.foreground.normal_app_exit_count" int)" '"30"'
  metrickit.app_exit.foreground.memory_resource_limit_exit-count" int)" '"31"'
  metrickit.app_exit.foreground.bad_access_exit_count" int)" '"32"'
  metrickit.app_exit.foreground.abnormal_exit_count" int)" '"33"'
  metrickit.app_exit.foreground.illegal_instruction_exit_count" int)" '"34"'
  metrickit.app_exit.foreground.app_watchdog_exit_count" int)" '"35"'
  metrickit.app_exit.background.normal_app_exit_count" int)" '"36"'
  metrickit.app_exit.background.memory_resource_limit_exit_count" int)" '"37"'
  metrickit.app_exit.background.cpu_resource_limit_exit_count" int)" '"38"'
  metrickit.app_exit.background.memory_pressure_exit_count" int)" '"39"'
  metrickit.app_exit.background.bad_access-exit_count" int)" '"40"'
  metrickit.app_exit.background.abnormal_exit_count" int)" '"41"'
  metrickit.app_exit.background.illegal_instruction_exit_count" int)" '"42"'
  metrickit.app_exit.background.app_watchdog_exit_count" int)" '"43"'
  metrickit.app_exit.background.suspended_with_locked_file_exit_count" int)" '"44"'
  metrickit.app_exit.background.background_task_assertion_timeout_exit_count" int)" '"45"'
}

## MXSignpost

TODO: Rewrite this in english:
  scope="MetricKit"
  span="MXSignpostMetric"

TODO: Rewrite this list of attributes as a markdown table with (1) attribute name, linked to apple documentation, (2) the datatype, and (3) units.
"SampleRate"
"app.metadata"
"device.isBatteryMonitoringEnabled"
"device.isLowPowerModeEnabled"
"device.isMultitaskingSupported"
"device.localizedModel"
"device.manufacturer"
"device.model"
"device.model.name"
"device.name"
"device.orientation"
"device.systemName"
"device.systemVersion"
"device.userInterfaceIdiom"
"network.connection.type"
"screen.name"
"screen.path"
"session.id"
"signpost.category"
"signpost.count"
"signpost.cpu_time"
"signpost.hitch_time_ratio"
"signpost.logical_write_count"
"signpost.memory_average"
"signpost.name"'

## MXDiagnostics

Diagnostics are events that occur once. However, we don't know exactly when. We only know they occurred during the reporting period. These include things like crashes and hangs. To represent diagnostics, we emit a top-level `Span` called `"MXDiagnosticPayload"` with the start and end corresponding to the reporting period. Then, for each event, we emit an OTel "log" for the event. I used logs instead of traces, because each event is instantaneous as far as we know. Also, I wanted to be consistent with the way the Android OTel auto-instrumentation represents uncaught exceptions. Each log has a name attribute for its type, with the key `"metrickit.diagnostic.name"`. The logs have metadata attached with namespaced keys, similar to metrics. For example, crash exception codes have the key `"metrickit.diagnostic.crash.exception.code"`. Since we don't know the exact times of the events, all logs use the end time of the reporting period. This helps so that data shows up as new data in Honeycomb when it arrives.

TODO: Fix the start time vs the end time. There's some kind of bug in the code I think?

TODO: Figure out whether there's a `MXDiagnosticPayload` trace and document it.

TODO: Write this in English:
  scope="MetricKit"

TODO: Turn this list into a markdown table with columns for (1) attribute name, with a link to the relevant Apple documentation for the equivalent MetricKit field, (2) the data type, and (3) the units of the attribute (not the comment).
  metrickit.diagnostic.cpu_exception.total_cpu_time" double)" 3180        # 53 minutes
  metrickit.diagnostic.cpu_exception.total_sampled_time" double)" 194400  # 54 hours
  metrickit.diagnostic.disk_write_exception.total_writes_caused" double)" 55000000  # 55 MB
  metrickit.diagnostic.hang.hang_duration" double)" 56
  metrickit.diagnostic.hang.exception.stacktrace_json" string)" '"fake json stacktrace"'
  metrickit.diagnostic.crash.exception.mach_exception.type" int)" '"57"'
  metrickit.diagnostic.crash.exception.mach_exception.name" string)" '"Unknown exception type: 57"'
  metrickit.diagnostic.crash.exception.mach_exception.description" string)" '"Unknown exception type: 57"'
  metrickit.diagnostic.crash.exception.code" int)" '"58"'
  metrickit.diagnostic.crash.exception.signal" int)" '"59"'
  metrickit.diagnostic.crash.exception.signal.name" string)" '"Unknown signal: 59"'
  metrickit.diagnostic.crash.exception.signal.description" string)" '"Unknown signal: 59"'
  metrickit.diagnostic.crash.exception.objc.message" string)" '"message: 1 2"'
  metrickit.diagnostic.crash.exception.objc.type" string)" '"ExceptionType"'
  metrickit.diagnostic.crash.exception.termination_reason" string)" '"reason"'
  metrickit.diagnostic.crash.exception.objc.name" string)" '"MyCrash"'
  metrickit.diagnostic.crash.exception.objc.classname" string)" '"MyClass"'
  metrickit.diagnostic.crash.exception.stacktrace_json" string)" '"fake json stacktrace"'
  metrickit.diagnostic.app_launch.launch_duration" double)" 60

TODO: Do the logs produced by the metrickit instrumentation have names or something to document?


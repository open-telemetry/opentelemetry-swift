# MetricKit Instrumentation

TODO: Make spm work.
TODO: Figure out how metrics should work.
TODO: Write a PR description.
TOOD: Clean up the key names to be correct.
TODO: Document how the time spans work.
TODO: Don't clobber the `exception` namespace.
TODO: Write unit tests.
TOOD: Make Cocoapods work.

This adds MetricKit signals to the Honeycomb Swift SDK.

This adds all of the data from Apple's MetricKit into Honeycomb. It's not obvious how to structure this data in order to best fit OTel semantics conventions while also being most usable in Honeycomb. I made my best guess how to do it, but would appreciate feedback on it. I am really not sure if this is the best way to represent this data. Here is how I'm structuring the data:

MetricKit reports a batch of data approximately once a day, with cumulative data from the previous day. There are two big categories of data: _Metrics_ and _Diagnostics_. These are covered below.

All of this data is captured using the scope `"@honeycombio/instrumentation-metric-kit"`

## Usage

TODO: Write instructions.

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

  scope="io.honeycomb.metrickit"
  span="MXMetricPayload"
  attribute_for_span_key $scope $span $1 $2
}

@test "MetricKit values are present and units are converted" {
  assert_equal "$(mk_attr "metrickit.includes_multiple_application_versions" bool)" false
  assert_equal "$(mk_attr "metrickit.latest_application_version" string)" '"3.14.159"'
  assert_equal "$(mk_attr "metrickit.cpu.cpu_time" double)" 1
  assert_equal "$(mk_attr "metrickit.cpu.instruction_count" double)" 2
  assert_equal "$(mk_attr "metrickit.gpu.time" double)" 10800  # 3 hours
  assert_equal "$(mk_attr "metrickit.cellular_condition.bars_average" double)" 4
  assert_equal "$(mk_attr "metrickit.app_time.foreground_time" double)" 300          # 5 minutes
  assert_equal "$(mk_attr "metrickit.app_time.background_time" double)" 0.000006     # 6 microseconds
  assert_equal "$(mk_attr "metrickit.app_time.background_audio_time" double)" 0.007  # 7 milliseconds
  assert_equal "$(mk_attr "metrickit.app_time.background_location_time" double)" 480 # 8 minutes
  assert_equal "$(mk_attr "metrickit.location_activity.best_accuracy_time" double)" 9
  assert_equal "$(mk_attr "metrickit.location_activity.best_accuracy_for_nav_time" double)" 10
  assert_equal "$(mk_attr "metrickit.location_activity.accuracy_10m_time" double)"  11
  assert_equal "$(mk_attr "metrickit.location_activity.accuracy_100m_time" double)" 12
  assert_equal "$(mk_attr "metrickit.location_activity.accuracy_1km_time" double)" 13
  assert_equal "$(mk_attr "metrickit.location_activity.accuracy_3km_time" double)" 14
  assert_equal "$(mk_attr "metrickit.network_transfer.wifi_upload" double)" 15                 # 15 B
  assert_equal "$(mk_attr "metrickit.network_transfer.wifi_download" double)" 16000            # 16 KB
  assert_equal "$(mk_attr "metrickit.network_transfer.cellular_upload" double)" 17000000       # 17 MB
  assert_equal "$(mk_attr "metrickit.network_transfer.cellular_download" double)" 18000000000  # 18 GB
  assert_equal "$(mk_attr "metrickit.app_launch.time_to_first_draw_average" double)" 1140            # 19 minutes
  assert_equal "$(mk_attr "metrickit.app_launch.app_resume_time_average" double)" 1200               # 20 minutes
  assert_equal "$(mk_attr "metrickit.app_launch.optimized_time_to_first_draw_average" double)" 1260  # 21 minutes
  assert_equal "$(mk_attr "metrickit.app_launch.extended_launch_average" double)" 1320               # 22 minutes
  assert_equal "$(mk_attr "metrickit.app_responsiveness.hang_time_average" double)" 82800  # 23 hours
  assert_equal "$(mk_attr "metrickit.diskio.logical_write_count" double)" 24000000000000  # 24 TB
  assert_equal "$(mk_attr "metrickit.memory.peak_memory_usage" double)" 25
  assert_equal "$(mk_attr "metrickit.memory.suspended_memory_average" double)" 26
  assert_equal "$(mk_attr "metrickit.display.pixel_luminance_average" double)" 27
  assert_equal "$(mk_attr "metrickit.animation.scroll_hitch_time_ratio" double)" 28
  assert_equal "$(mk_attr "metrickit.metadata.pid" int)" '"29"'
  assert_equal "$(mk_attr "metrickit.metadata.app_build_version" string)" '"build"'
  assert_equal "$(mk_attr "metrickit.metadata.device_type" string)" '"device"'
  assert_equal "$(mk_attr "metrickit.metadata.is_test_flight_app" bool)" true
  assert_equal "$(mk_attr "metrickit.metadata.low_power_mode_enabled" bool)" true
  assert_equal "$(mk_attr "metrickit.metadata.os_version" string)" '"os"'
  assert_equal "$(mk_attr "metrickit.metadata.platform_arch" string)" '"arch"'
  assert_equal "$(mk_attr "metrickit.metadata.region_format" string)" '"format"'
  assert_equal "$(mk_attr "metrickit.app_exit.foreground.normal_app_exit_count" int)" '"30"'
  assert_equal "$(mk_attr "metrickit.app_exit.foreground.memory_resource_limit_exit-count" int)" '"31"'
  assert_equal "$(mk_attr "metrickit.app_exit.foreground.bad_access_exit_count" int)" '"32"'
  assert_equal "$(mk_attr "metrickit.app_exit.foreground.abnormal_exit_count" int)" '"33"'
  assert_equal "$(mk_attr "metrickit.app_exit.foreground.illegal_instruction_exit_count" int)" '"34"'
  assert_equal "$(mk_attr "metrickit.app_exit.foreground.app_watchdog_exit_count" int)" '"35"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.normal_app_exit_count" int)" '"36"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.memory_resource_limit_exit_count" int)" '"37"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.cpu_resource_limit_exit_count" int)" '"38"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.memory_pressure_exit_count" int)" '"39"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.bad_access-exit_count" int)" '"40"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.abnormal_exit_count" int)" '"41"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.illegal_instruction_exit_count" int)" '"42"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.app_watchdog_exit_count" int)" '"43"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.suspended_with_locked_file_exit_count" int)" '"44"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.background_task_assertion_timeout_exit_count" int)" '"45"'
}

## MXSignpost

@test "MXSignpostMetric data is present" {
  scope="io.honeycomb.metrickit"
  span="MXSignpostMetric"

  result=$(attributes_from_span_named $scope $span | jq .key | sort | uniq)

   assert_equal "$result" '"SampleRate"
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
}

## MXDiagnostic?

Diagnostics are events that occur once. However, we don't know exactly when. We only know they occurred during the reporting period. These include things like crashes and hangs. To represent diagnostics, we emit a top-level `Span` called `"MXDiagnosticPayload"` with the start and end corresponding to the reporting period. Then, for each event, we emit an OTel "log" for the event. I used logs instead of traces, because each event is instantaneous as far as we know. Also, I wanted to be consistent with the way the Android OTel auto-instrumentation represents uncaught exceptions. Each log has a name attribute for its type, with the key `"metrickit.diagnostic.name"`. The logs have metadata attached with namespaced keys, similar to metrics. For example, crash exception codes have the key `"metrickit.diagnostic.crash.exception.code"`. Since we don't know the exact times of the events, all logs use the end time of the reporting period. This helps so that data shows up as new data in Honeycomb when it arrives.

TODO: What is this thing actually named?
TODO: Describe the different diagnostics.
TODO: Fix the start time vs the end time.

  scope="io.honeycomb.metrickit"
  attribute_for_log_key $scope $1 $2
}

        "MXDiagnosticPayload"
        
@test "MetricKit diagnostic values are present and units are converted" {
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.cpu_exception.total_cpu_time" double)" 3180        # 53 minutes
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.cpu_exception.total_sampled_time" double)" 194400  # 54 hours
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.disk_write_exception.total_writes_caused" double)" 55000000  # 55 MB
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.hang.hang_duration" double)" 56
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.hang.exception.stacktrace_json" string)" '"fake json stacktrace"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.mach_exception.type" int)" '"57"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.mach_exception.name" string)" '"Unknown exception type: 57"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.mach_exception.description" string)" '"Unknown exception type: 57"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.code" int)" '"58"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.signal" int)" '"59"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.signal.name" string)" '"Unknown signal: 59"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.signal.description" string)" '"Unknown signal: 59"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.objc.message" string)" '"message: 1 2"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.objc.type" string)" '"ExceptionType"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.termination_reason" string)" '"reason"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.objc.name" string)" '"MyCrash"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.objc.classname" string)" '"MyClass"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.stacktrace_json" string)" '"fake json stacktrace"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.app_launch.launch_duration" double)" 60
}



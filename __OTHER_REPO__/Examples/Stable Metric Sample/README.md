###  Stable metrics

 Stable metrics is the working name for the otel-swift implementation of the current OpenTelemetry metrics specification.
 The existing otel-swift metric implementation is old and out-of-spec. While Stable Metrics is in an experimental phase it will maintaion
 the "stable" prefix, and can be expected to be present on overlapping constructs in the implementation.
 Expected time line will be as follows:
  Phase 1:
    Provide access to Stable Metrics along side existing Metrics. Once Stable Metrics are considered stable we will move onto phase 2.
  Phase 2:
    Mark all existing Metric APIs as deprecated. This will maintained for a period TBD
  Phase 3:
    Remove deprecated metrics api and remove Stable prefix from Stable metrics.

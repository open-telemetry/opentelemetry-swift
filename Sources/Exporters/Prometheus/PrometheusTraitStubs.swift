/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !Prometheus

  import OpenTelemetrySdk

  @available(*, unavailable, message: "PrometheusExporter requires the `Prometheus` package trait.")
  public final class PrometheusExporter {
    public init(options: PrometheusExporterOptions, aggregationTemoralitySelector: AggregationTemporalitySelector = AggregationTemporality.alwaysCumulative()) {}
  }

  @available(*, unavailable, message: "PrometheusExporter requires the `Prometheus` package trait.")
  public struct PrometheusExporterOptions {
    public init(url: String) {}
  }

#endif

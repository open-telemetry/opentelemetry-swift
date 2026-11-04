/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !Prometheus

  @available(*, unavailable, message: "PrometheusExporter requires the `Prometheus` package trait.")
  public final class PrometheusExporter {}

  @available(*, unavailable, message: "PrometheusExporter requires the `Prometheus` package trait.")
  public struct PrometheusExporterOptions {}

#endif

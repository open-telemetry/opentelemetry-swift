/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !OTLPGRPC

  @available(*, unavailable, message: "OpenTelemetryProtocolExporter requires the `OTLPGRPC` package trait.")
  public final class OtlpTraceExporter {}

  @available(*, unavailable, message: "OpenTelemetryProtocolExporter requires the `OTLPGRPC` package trait.")
  public final class OtlpMetricExporter {}

  @available(*, unavailable, message: "OpenTelemetryProtocolExporter requires the `OTLPGRPC` package trait.")
  public final class OtlpLogExporter {}

  @available(*, unavailable, message: "OpenTelemetryProtocolExporter requires the `OTLPGRPC` package trait.")
  public final class OtlpTraceJsonExporter {}

#endif

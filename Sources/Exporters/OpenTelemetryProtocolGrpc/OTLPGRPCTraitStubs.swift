/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !OTLPGRPC

  @available(*, unavailable, message: "OpenTelemetryProtocolExporter requires the `OTLPGRPC` package trait.")
  public final class OtlpTraceExporter {
    public init(channel: Any) {}
  }

  @available(*, unavailable, message: "OpenTelemetryProtocolExporter requires the `OTLPGRPC` package trait.")
  public final class OtlpMetricExporter {
    public init(channel: Any) {}
  }

  @available(*, unavailable, message: "OpenTelemetryProtocolExporter requires the `OTLPGRPC` package trait.")
  public final class OtlpLogExporter {
    public init(channel: Any) {}
  }

  @available(*, unavailable, message: "OpenTelemetryProtocolExporter requires the `OTLPGRPC` package trait.")
  public final class OtlpTraceJsonExporter {}

#endif

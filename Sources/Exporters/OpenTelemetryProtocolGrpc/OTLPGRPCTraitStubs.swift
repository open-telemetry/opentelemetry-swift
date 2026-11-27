/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !OTLPGRPC

  @available(*, unavailable, message: "OpenTelemetryProtocolExporter requires the `OTLPGRPC` package trait.")
  public final class OtlpTraceExporter {
    public init(client: Any) {}
    public init(transport: Any) {}
  }

  @available(*, unavailable, message: "OpenTelemetryProtocolExporter requires the `OTLPGRPC` package trait.")
  public final class OtlpMetricExporter {
    public init(client: Any) {}
    public init(transport: Any) {}
  }

  @available(*, unavailable, message: "OpenTelemetryProtocolExporter requires the `OTLPGRPC` package trait.")
  public final class OtlpLogExporter {
    public init(client: Any) {}
    public init(transport: Any) {}
  }

#endif

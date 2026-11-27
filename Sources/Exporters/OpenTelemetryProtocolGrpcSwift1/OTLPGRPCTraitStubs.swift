/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !OTLPGRPCSwift1

  @available(*, unavailable, message: "OpenTelemetryProtocolExporterGrpcSwift1 requires the `OTLPGRPCSwift1` package trait.")
  public final class OtlpTraceExporter {
    public init(channel: Any) {}
  }

  @available(*, unavailable, message: "OpenTelemetryProtocolExporterGrpcSwift1 requires the `OTLPGRPCSwift1` package trait.")
  public final class OtlpMetricExporter {
    public init(channel: Any) {}
  }

  @available(*, unavailable, message: "OpenTelemetryProtocolExporterGrpcSwift1 requires the `OTLPGRPCSwift1` package trait.")
  public final class OtlpLogExporter {
    public init(channel: Any) {}
  }

#endif

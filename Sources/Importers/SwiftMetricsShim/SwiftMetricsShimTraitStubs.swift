/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !SwiftObservabilityAPIBridges

  import OpenTelemetryApi

  @available(*, unavailable, message: "SwiftMetricsShim requires the `SwiftObservabilityAPIBridges` package trait.")
  public final class OpenTelemetrySwiftMetrics {
    public init(meter: any OpenTelemetryApi.Meter) {}
  }

#endif

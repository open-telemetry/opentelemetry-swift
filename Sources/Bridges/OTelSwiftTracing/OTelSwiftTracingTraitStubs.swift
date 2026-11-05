/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !SwiftObservabilityAPIBridges

  import OpenTelemetryApi

  @available(*, unavailable, message: "OTelSwiftTracing requires the `SwiftObservabilityAPIBridges` package trait.")
  public struct OTelTracer {
    public init(
      tracerProvider: TracerProvider = OpenTelemetry.instance.tracerProvider,
      propagator: TextMapPropagator = OpenTelemetry.instance.propagators.textMapPropagator,
      instrumentationName: String = "OTelSwiftTracing",
      instrumentationVersion: String = "1.0.0"
    ) {}
  }

#endif

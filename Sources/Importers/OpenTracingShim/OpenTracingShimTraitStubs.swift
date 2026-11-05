/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !OpenTracing

  import OpenTelemetryApi

  // The real methods return Opentracing's OTTracer, which stubs can't name.
  @available(*, unavailable, message: "OpenTracingShim-experimental requires the `OpenTracing` package trait.")
  public final class TraceShim: @unchecked Sendable {
    public static let instance = TraceShim()

    private init() {}

    public static func createTracerShim() -> AnyObject {
      fatalError()
    }

    public static func createTracerShim(tracerProvider: TracerProvider, baggageManager: BaggageManager) -> AnyObject {
      fatalError()
    }
  }

#endif

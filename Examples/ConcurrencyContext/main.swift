/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(_Concurrency)
  import OpenTelemetrySdk
  import OpenTelemetryConcurrency
  import StdoutExporter

  let sampleKey = "sampleKey"
  let sampleValue = "sampleValue"

  @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
  extension Task where Failure == Never, Success == Never {
    static func sleep(seconds: Double) async throws {
      try await sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
  }

  if #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) {
    // On Apple platforms, the default is the activity based context manager. We want to opt-in to the structured concurrency based context manager instead.
    OpenTelemetry.registerDefaultConcurrencyContextManager()
    
    let stdout = StdoutSpanExporter()
    OpenTelemetry.registerTracerProvider(
      tracerProvider: TracerProviderBuilder().add(
        spanProcessor: SimpleSpanProcessor(spanExporter: stdout)
      ).build()
    )
    
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ConcurrencyContext", instrumentationVersion: "semver:0.1.0")
    
    func simpleSpan() async throws {
      let span = tracer.spanBuilder(spanName: "SimpleSpan").setSpanKind(spanKind: .client).startSpan()
      span.setAttribute(key: sampleKey, value: sampleValue)
      try await Task.sleep(seconds: 0.5)
      span.end()
    }

      
    func childSpan() async throws {
      // SpanBuilder's `setActive` method is not available here, since it isn't compatible with structured concurrency based context management
      try await tracer.spanBuilder(spanName: "parentSpan").setSpanKind(spanKind: .client).withActiveSpan { @Sendable span in
        span.setAttribute(key: sampleKey, value: sampleValue)
        await Task.detached { @Sendable in
          // A detached task doesn't inherit the task local context, so this span won't have a parent.
          let notAChildSpan = tracer.spanBuilder(spanName: "notAChild").setSpanKind(spanKind: .client).startSpan()
          notAChildSpan.setAttribute(key: sampleKey, value: sampleValue)
          notAChildSpan.end()
        }.value
          
        try await Task {
          // Normal tasks should still inherit the context.
          try await Task.sleep(seconds: 0.2)
            let childSpan = tracer.spanBuilder(spanName: "childSpan").setSpanKind(spanKind: .client).startSpan()
            childSpan.setAttribute(key: sampleKey, value: sampleValue)
            try await Task.sleep(seconds: 0.5)
            childSpan.end()
          }.value
      }
    }
      
    try await simpleSpan()
    try await Task.sleep(seconds: 1)
    try await childSpan()
    try await Task.sleep(seconds: 1)
  }
#endif

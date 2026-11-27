/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if OTLPGRPC && os(macOS)

  import Foundation
  import GRPCCore
  import GRPCNIOTransportHTTP2
  import OpenTelemetryApi
  import OpenTelemetryProtocolExporterGrpc
  import OpenTelemetrySdk
  import ResourceExtension
  import SignPostIntegration
  import StdoutExporter
  import ZipkinExporter

  if #available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) {
    let sampleKey = "sampleKey"
    let sampleValue = "sampleValue"

    let instrumentationScopeName = "OTLPExporter"
    let instrumentationScopeVersion = "semver:0.1.0"

    enum CollectorTransport {
      case plaintext
      case tls
    }

    func makeCollectorTransport(host: String,
                                port: Int,
                                transport: CollectorTransport) throws -> HTTP2ClientTransport.Posix {
      switch transport {
      case .plaintext:
        return try HTTP2ClientTransport.Posix(
          target: .dns(host: host, port: port),
          transportSecurity: .plaintext
        )
      case .tls:
        return try HTTP2ClientTransport.Posix(
          target: .dns(host: host, port: port),
          transportSecurity: .tls
        )
      }
    }

    let collectorHost = "localhost"
    let collectorPort = 4317
    let collectorTransport = CollectorTransport.plaintext

    // One client serves every exporter. The exporters only send through it, so the
    // example runs the client's connections itself and shuts it down when it is done.
    // The task is `@concurrent` because a plain `Task` would inherit the main actor, which the
    // code below never yields, so the client would not run until the example ends.
    let client = GRPCClient(
      transport: try makeCollectorTransport(
        host: collectorHost,
        port: collectorPort,
        transport: collectorTransport
      )
    )
    let clientTask = Task { @concurrent in try await client.runConnections() }

    let otlpTraceExporter = OtlpTraceExporter(client: client)
    let stdoutExporter = StdoutSpanExporter()
    let spanExporter = MultiSpanExporter(spanExporters: [otlpTraceExporter, stdoutExporter])

    let spanProcessor = SimpleSpanProcessor(spanExporter: spanExporter)
    OpenTelemetry.registerTracerProvider(tracerProvider:
      TracerProviderBuilder()
        .add(spanProcessor: spanProcessor)
        .build()
    )

    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: instrumentationScopeName, instrumentationVersion: instrumentationScopeVersion)

    let tracerProviderSDK = OpenTelemetry.instance.tracerProvider as? TracerProviderSdk
    tracerProviderSDK?.addSpanProcessor(OSSignposterIntegration())

    @MainActor func createSpans() {
      let parentSpan1 = tracer.spanBuilder(spanName: "Main").setSpanKind(spanKind: .client).startSpan()
      parentSpan1.setAttribute(key: sampleKey, value: sampleValue)
      OpenTelemetry.instance.contextProvider.setActiveSpan(parentSpan1)
      for _ in 1 ... 3 {
        doWork()
      }
      Thread.sleep(forTimeInterval: 0.5)

      let parentSpan2 = tracer.spanBuilder(spanName: "Another").setSpanKind(spanKind: .client).setActive(true).startSpan()
      parentSpan2.setAttribute(key: sampleKey, value: sampleValue)
      // do more Work
      for _ in 1 ... 3 {
        doWork()
      }
      Thread.sleep(forTimeInterval: 0.5)

      parentSpan2.end()
      parentSpan1.end()
    }

    @MainActor func doWork() {
      let childSpan = tracer.spanBuilder(spanName: "doWork").setSpanKind(spanKind: .client).startSpan()
      childSpan.setAttribute(key: sampleKey, value: sampleValue)
      Thread.sleep(forTimeInterval: Double.random(in: 0 ..< 10) / 100)
      childSpan.end()
    }

    // Create a Parent span (Main) and do some Work (child Spans). Repeat for another Span.
    // Top-level code is @MainActor in Swift 6, so this @MainActor helper can be
    // called directly — a `Task { @MainActor in ... }` here would enqueue on the
    // main actor but never drain before the metrics loop below hogs the thread.
    createSpans()

    // Metrics
    let otlpMetricExporter = OtlpMetricExporter(client: client)
    let meterProvider = MeterProviderSdk.builder()
      .registerMetricReader(
        reader: PeriodicMetricReaderBuilder(
          exporter: otlpMetricExporter).setInterval(timeInterval: 60)
          .build()
      )
      .registerView(
        selector: InstrumentSelector.builder().setInstrument(name: ".*").build(),
        view: View.builder().build()
      )
      .build()

    OpenTelemetry.registerMeterProvider(meterProvider: meterProvider)

    let labels1 = ["dim1": AttributeValue.string("value1")]

    let meter = meterProvider.get(name: "otlp_example_meter'")

    let exampleCounter = meter.counterBuilder(name: "otlp_example_counter").build()
    let exampleObserver = meter.gaugeBuilder(
      name: "otlp_example_observation"
    ).buildWithCallback { observer in
      var taskInfo = mach_task_basic_info()
      var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
      let _: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
          task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
      }
      observer.record(value: Int(taskInfo.resident_size), attributes: labels1)
    }

    for _ in 1 ... 3000 {
      exampleCounter.add(value: 1, attributes: labels1)
      sleep(1)
    }

    _ = exampleObserver

    client.beginGracefulShutdown()
    try await clientTask.value
  } else {
    print("This example requires macOS 15 or later.")
  }

#elseif os(macOS)

  print("This example requires the OTLPGRPC package trait.")

#endif

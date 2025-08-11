/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if os(macOS)

  import Foundation
  import OpenTelemetryApi
  import OpenTelemetryProtocolExporterHttp
  import OpenTelemetrySdk
  import ResourceExtension
  import SignPostIntegration
  import StdoutExporter
  import ZipkinExporter

  let sampleKey = "sampleKey"
  let sampleValue = "sampleValue"

  var resources = DefaultResources().get()

  let instrumentationScopeName = "OTLPHTTPExporter"
  let instrumentationScopeVersion = "semver:0.1.0"

  let otlpHttpTraceExporter = OtlpHttpTraceExporter()
  let stdoutExporter = StdoutSpanExporter()
  let spanExporter = MultiSpanExporter(spanExporters: [otlpHttpTraceExporter, stdoutExporter])

  let spanProcessor = SimpleSpanProcessor(spanExporter: spanExporter)
  OpenTelemetry.registerTracerProvider(tracerProvider:
    TracerProviderBuilder()
      .add(spanProcessor: spanProcessor)
      .build()
  )

  let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: instrumentationScopeName, instrumentationVersion: instrumentationScopeVersion)

  if #available(iOS 15.0, macOS 12, tvOS 15.0, watchOS 8.0, *) {
    let tracerProviderSDK = OpenTelemetry.instance.tracerProvider as? TracerProviderSdk
    tracerProviderSDK?.addSpanProcessor(OSSignposterIntegration())
  } else {
    let tracerProviderSDK = OpenTelemetry.instance.tracerProvider as? TracerProviderSdk
    tracerProviderSDK?.addSpanProcessor(SignPostIntegration())
  }

  func createSpans() {
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

  func doWork() {
    let childSpan = tracer.spanBuilder(spanName: "doWork").setSpanKind(spanKind: .client).startSpan()
    childSpan.setAttribute(key: sampleKey, value: sampleValue)
    Thread.sleep(forTimeInterval: Double.random(in: 0 ..< 10) / 100)
    childSpan.end()
  }

  // Create a Parent span (Main) and do some Work (child Spans). Repeat for another Span.
  createSpans()

// Metrics
let otlpMetricExporter = OtlpHttpMetricExporter(endpoint: defaultOtlpHttpMetricsEndpoint())
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

var meter = meterProvider.get(name: "otlp_example_meter'")

var exampleCounter = meter.counterBuilder(name: "otlp_example_counter").build()
var exampleObserver = meter.gaugeBuilder(
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
#endif

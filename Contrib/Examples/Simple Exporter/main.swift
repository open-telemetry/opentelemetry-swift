/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if os(macOS)

  import Foundation
  import JaegerExporter
  import OpenTelemetryApi
  import OpenTelemetrySdk
  import ResourceExtension
  import SignPostIntegration
  import StdoutExporter
  import ZipkinExporter

  let sampleKey = "sampleKey"
  let sampleValue = "sampleValue"

  let instrumentationScopeName = "SimpleExporter"
  let instrumentationScopeVersion = "semver:0.1.0"

  var tracer: TracerSdk
  let jaegerCollectorAddress = "localhost"
  let jaegerExporter = JaegerSpanExporter(serviceName: "SimpleExporter", collectorAddress: jaegerCollectorAddress)
  let stdoutExporter = StdoutSpanExporter()

  // let zipkinExporterOptions = ZipkinTraceExporterOptions()
  // let zipkinExporter = ZipkinTraceExporter(options: zipkinExporterOptions)

  let spanExporter = MultiSpanExporter(spanExporters: [jaegerExporter, stdoutExporter /* , zipkinExporter */ ])
  let spanProcessor = SimpleSpanProcessor(spanExporter: spanExporter)
  let resources = DefaultResources().get()

  OpenTelemetry.registerTracerProvider(tracerProvider:
    TracerProviderBuilder()
      .add(spanProcessor: spanProcessor)
      .with(resource: resources)
      .build()
  )

  tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: instrumentationScopeName, instrumentationVersion: instrumentationScopeVersion) as! TracerSdk

  if #available(iOS 15.0, macOS 12, tvOS 15.0, watchOS 8.0, *) {
    let tracerProviderSDK = OpenTelemetry.instance.tracerProvider as? TracerProviderSdk
    tracerProviderSDK?.addSpanProcessor(OSSignposterIntegration())
  } else {
    let tracerProviderSDK = OpenTelemetry.instance.tracerProvider as? TracerProviderSdk
    tracerProviderSDK?.addSpanProcessor(SignPostIntegration())
  }

  func simpleSpan() {
    let span = tracer.spanBuilder(spanName: "SimpleSpan").setSpanKind(spanKind: .client).startSpan()
    span.setAttribute(key: sampleKey, value: sampleValue)
    Thread.sleep(forTimeInterval: 0.5)
    span.end()
  }

  func childSpan() {
    let span = tracer.spanBuilder(spanName: "parentSpan").setSpanKind(spanKind: .client).setActive(true).startSpan()
    span.setAttribute(key: sampleKey, value: sampleValue)
    Thread.sleep(forTimeInterval: 0.2)
    let childSpan = tracer.spanBuilder(spanName: "childSpan").setSpanKind(spanKind: .client).startSpan()
    childSpan.setAttribute(key: sampleKey, value: sampleValue)
    Thread.sleep(forTimeInterval: 0.5)
    childSpan.end()
    span.end()
  }

  simpleSpan()
  sleep(1)
  childSpan()
  sleep(1)

#endif

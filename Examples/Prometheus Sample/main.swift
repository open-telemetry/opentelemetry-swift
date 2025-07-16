/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import PrometheusExporter

print("Hello Prometheus")

//
// You should use here your real local address, change it also in the prometheus.yml file
let localAddress = "192.168.1.28"
//

let promOptions = PrometheusExporterOptions(url: "http://\(localAddress):9184/metrics")
let promExporter = PrometheusExporter(options: promOptions)
let metricsHttpServer = PrometheusExporterHttpServer(exporter: promExporter)

DispatchQueue.global(qos: .default).async {
  do {
    try metricsHttpServer.start()
  } catch {
    print("Failed staring http server")
    return
  }
}

let meterProvider = MeterProviderSdk.builder()
  .registerView(
    selector: InstrumentSelector
      .builder()
      .setInstrument(type: .histogram).build(),
    view: View.builder()
      .withAggregation(
        aggregation: ExplicitBucketHistogramAggregation(bucketBoundaries: [5, 10, 25])
      ).build()
  )
  .registerMetricReader(
    reader: PeriodicMetricReaderBuilder(exporter: promExporter).build(
    )).build()

OpenTelemetry.registerMeterProvider(meterProvider: meterProvider)

var meter = meterProvider.get(name: "MyMeter")

var testCounter = meter.counterBuilder(name: "MyCounter").build()
var testMeasure = meter.gaugeBuilder(name: "MyMeasure").build()

var testHistogram = meter.histogramBuilder(name: "MyHistogram").build()

var testObserver = meter.gaugeBuilder(name: "MyObservation").buildWithCallback { observer in
  var taskInfo = mach_task_basic_info()
  var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
  let _: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
      task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
    }
  }
  let labels1 = ["dim1": AttributeValue.string("value1")]
  observer
    .record(value: Int(taskInfo.resident_size), attributes: labels1)
}

var labels1 = ["dim1": AttributeValue.string("value1")]
var labels2 = ["dim1": AttributeValue.string("value2")]

var counter = 0
while counter < 3000 {
  testCounter.add(value: 100, attributes: labels1)

  testMeasure.record(value: 100, attributes: labels1)
  testMeasure.record(value: 500, attributes: labels1)
  testMeasure.record(value: 5, attributes: labels1)
  testMeasure.record(value: 750, attributes: labels1)

  testHistogram.record(value: 8, attributes: labels1)
  testHistogram.record(value: 20, attributes: labels1)
  testHistogram.record(value: 30, attributes: labels1)

  counter += 1
  sleep(1)
}

metricsHttpServer.stop()

print("Metrics server shutdown.")
print("Press Enter key to exit.")

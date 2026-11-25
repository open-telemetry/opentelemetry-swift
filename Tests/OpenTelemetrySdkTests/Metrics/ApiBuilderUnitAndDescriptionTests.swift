//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

// These helpers only see the API protocols, like an instrumentation library that depends on
// OpenTelemetryApi alone.
private func describe<B: LongCounterBuilder>(_ builder: B) -> B {
  builder.setUnit("s").setDescription("description")
}

private func describe<B: DoubleCounterBuilder>(_ builder: B) -> B {
  builder.setUnit("s").setDescription("description")
}

private func describe<B: LongUpDownCounterBuilder>(_ builder: B) -> B {
  builder.setUnit("s").setDescription("description")
}

private func describe<B: DoubleUpDownCounterBuilder>(_ builder: B) -> B {
  builder.setUnit("s").setDescription("description")
}

private func describe<B: DoubleHistogramBuilder>(_ builder: B) -> B {
  builder.setUnit("s").setDescription("description")
}

private func describe<B: LongHistogramBuilder>(_ builder: B) -> B {
  builder.setUnit("s").setDescription("description")
}

private func describe<B: DoubleGaugeBuilder>(_ builder: B) -> B {
  builder.setUnit("s").setDescription("description")
}

private func describe<B: LongGaugeBuilder>(_ builder: B) -> B {
  builder.setUnit("s").setDescription("description")
}

class ApiBuilderUnitAndDescriptionTests: XCTestCase {
  var exporter: MockMetricExporter!
  var reader: PeriodicMetricReaderSdk!
  var meterProvider: MeterProviderSdk!
  var meter: MeterSdk!

  override func setUp() {
    super.setUp()
    exporter = MockMetricExporter()
    reader = PeriodicMetricReaderSdk(exporter: exporter, exportInterval: 60.0)
    meterProvider = MeterProviderSdk.builder()
      .registerMetricReader(reader: reader)
      .registerView(selector: InstrumentSelectorBuilder().build(), view: View.builder().build())
      .build()
    meter = meterProvider.meterBuilder(name: "meter").build()
  }

  override func tearDown() {
    _ = meterProvider.shutdown()
    super.tearDown()
  }

  func testSynchronousInstrumentsKeepUnitAndDescriptionSetThroughApi() {
    let descriptors = [
      describe(meter.counterBuilder(name: "longCounter")).build().instrumentDescriptor,
      describe(meter.counterBuilder(name: "doubleCounter").ofDoubles()).build().instrumentDescriptor,
      describe(meter.upDownCounterBuilder(name: "longUpDown")).build().instrumentDescriptor,
      describe(meter.upDownCounterBuilder(name: "doubleUpDown").ofDoubles()).build().instrumentDescriptor,
      describe(meter.histogramBuilder(name: "doubleHistogram")).build().instrumentDescriptor,
      describe(meter.histogramBuilder(name: "longHistogram").ofLongs()).build().instrumentDescriptor,
      describe(meter.gaugeBuilder(name: "doubleGauge")).build().instrumentDescriptor,
      describe(meter.gaugeBuilder(name: "longGauge").ofLongs()).build().instrumentDescriptor
    ]

    for descriptor in descriptors {
      XCTAssertEqual(descriptor.unit, "s", descriptor.name)
      XCTAssertEqual(descriptor.description, "description", descriptor.name)
    }
  }

  func testAsynchronousInstrumentsKeepUnitAndDescriptionSetThroughApi() {
    let instruments: [Any] = [
      describe(meter.counterBuilder(name: "longCounter")).buildWithCallback { $0.record(value: 1) },
      describe(meter.counterBuilder(name: "doubleCounter").ofDoubles()).buildWithCallback { $0.record(value: 1.0) },
      describe(meter.upDownCounterBuilder(name: "longUpDown")).buildWithCallback { $0.record(value: 1) },
      describe(meter.upDownCounterBuilder(name: "doubleUpDown").ofDoubles()).buildWithCallback { $0.record(value: 1.0) },
      describe(meter.gaugeBuilder(name: "doubleGauge")).buildWithCallback { $0.record(value: 1.0) },
      describe(meter.gaugeBuilder(name: "longGauge").ofLongs()).buildWithCallback { $0.record(value: 1) }
    ]
    XCTAssertEqual(instruments.count, 6)

    XCTAssertEqual(reader.forceFlush(), .success)

    let metrics = exporter.exportData
    XCTAssertEqual(
      Set(metrics.map(\.name)),
      ["longCounter", "doubleCounter", "longUpDown", "doubleUpDown", "doubleGauge", "longGauge"]
    )
    for metric in metrics {
      XCTAssertEqual(metric.unit, "s", metric.name)
      XCTAssertEqual(metric.description, "description", metric.name)
    }
  }

  func testNoopBuildersAcceptUnitAndDescriptionThroughApi() {
    let meter = DefaultMeter()

    let counterBuilder = meter.counterBuilder(name: "counter")
    XCTAssertTrue(describe(counterBuilder) === counterBuilder)
    let doubleCounterBuilder = counterBuilder.ofDoubles()
    XCTAssertTrue(describe(doubleCounterBuilder) === doubleCounterBuilder)

    let upDownCounterBuilder = meter.upDownCounterBuilder(name: "upDown")
    XCTAssertTrue(describe(upDownCounterBuilder) === upDownCounterBuilder)
    let doubleUpDownCounterBuilder = upDownCounterBuilder.ofDoubles()
    XCTAssertTrue(describe(doubleUpDownCounterBuilder) === doubleUpDownCounterBuilder)

    let histogramBuilder = meter.histogramBuilder(name: "histogram")
    XCTAssertTrue(describe(histogramBuilder) === histogramBuilder)
    let longHistogramBuilder = histogramBuilder.ofLongs()
    XCTAssertTrue(describe(longHistogramBuilder) === longHistogramBuilder)

    let gaugeBuilder = meter.gaugeBuilder(name: "gauge")
    XCTAssertTrue(describe(gaugeBuilder) === gaugeBuilder)
    let longGaugeBuilder = gaugeBuilder.ofLongs()
    XCTAssertTrue(describe(longGaugeBuilder) === longGaugeBuilder)
  }
}

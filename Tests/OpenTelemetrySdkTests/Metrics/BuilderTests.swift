//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class BuilderTests: XCTestCase {
  func testBuilders() {
    let meterProvider = MeterProviderSdk.builder().build()
    let meter = meterProvider.meterBuilder(name: "meter").build()
    XCTAssertTrue(type(of: meter) == DefaultMeter.self)
    XCTAssertNotNil(meter.counterBuilder(name: "counter").ofDoubles().build())
    XCTAssertNotNil(meter.counterBuilder(name: "counter").build())
    XCTAssertNotNil(meter.gaugeBuilder(name: "gauge").build())
    XCTAssertNotNil(meter.gaugeBuilder(name: "gauge").buildWithCallback { _ in })
    XCTAssertNotNil(meter.gaugeBuilder(name: "gauge").ofLongs().build())
    XCTAssertNotNil(meter.gaugeBuilder(name: "gauge").ofLongs().buildWithCallback { _ in })
    XCTAssertNotNil(meter.histogramBuilder(name: "histogram").build())
    XCTAssertNotNil(meter.histogramBuilder(name: "histogram").ofLongs().build())
    XCTAssertNotNil(meter.upDownCounterBuilder(name: "updown").build())
    XCTAssertNotNil(meter.upDownCounterBuilder(name: "updown").ofDoubles().build())
    XCTAssertNotNil(meter.upDownCounterBuilder(name: "updown").buildWithCallback { _ in })
  }

  func testCounterofLongs() {
    let myReader = PeriodicMetricReaderBuilder(
      exporter: MockMetricExporter()
    ).build()

    let meterProvider = MeterProviderSdk.builder()
      .registerMetricReader(reader: myReader)
      .registerView(
        selector: InstrumentSelector.builder().setMeter(name: "*").build(),
        view: View
          .builder().build()
      )
      .build()

    let meter = meterProvider.meterBuilder(name: "meter").build()
    let instrument =
      meter
        .counterBuilder(
          name: "longCounter"
        )
        .setUnit("unit")
        .setDescription("description")
        .build()

    XCTAssertEqual(instrument.instrumentDescriptor.name, "longCounter")
    XCTAssertEqual(instrument.instrumentDescriptor.unit, "unit")
    XCTAssertEqual(instrument.instrumentDescriptor.description, "description")
    XCTAssertEqual(instrument.instrumentDescriptor.valueType, InstrumentValueType.long)
    XCTAssertEqual(
      instrument.instrumentDescriptor.type,
      InstrumentType.counter
    )
  }

  func testCounterOfDoubles() {
    let myReader = PeriodicMetricReaderBuilder(
      exporter: MockMetricExporter()
    ).build()

    let meterProvider = MeterProviderSdk.builder()
      .registerMetricReader(reader: myReader)
      .registerView(
        selector: InstrumentSelector.builder().setMeter(name: "*").build(),
        view: View
          .builder().build()
      )
      .build()

    let meter = meterProvider.meterBuilder(name: "meter").build()
    let instrument =
      meter
        .counterBuilder(
          name: "doubleCounter"
        ).ofDoubles()
        .setUnit("unit")
        .setDescription("description")
        .build()

    XCTAssertEqual(instrument.instrumentDescriptor.name, "doubleCounter")
    XCTAssertEqual(instrument.instrumentDescriptor.unit, "unit")
    XCTAssertEqual(instrument.instrumentDescriptor.description, "description")
    XCTAssertEqual(instrument.instrumentDescriptor.valueType, InstrumentValueType.double)
    XCTAssertEqual(
      instrument.instrumentDescriptor.type,
      InstrumentType.counter
    )
  }

  func testGuageOfDoubles() {
    let myReader = PeriodicMetricReaderBuilder(
      exporter: MockMetricExporter()
    ).build()

    let meterProvider = MeterProviderSdk.builder()
      .registerMetricReader(reader: myReader)
      .registerView(
        selector: InstrumentSelector.builder().setMeter(name: "*").build(),
        view: View
          .builder().build()
      )
      .build()

    let meter = meterProvider.meterBuilder(name: "meter").build()
    let instrument =
      meter.gaugeBuilder(name: "doubleGauge")
        .setUnit("unit")
        .setDescription("description")
        .build()

    XCTAssertEqual(instrument.instrumentDescriptor.name, "doubleGauge")
    XCTAssertEqual(instrument.instrumentDescriptor.unit, "unit")
    XCTAssertEqual(instrument.instrumentDescriptor.description, "description")
    XCTAssertEqual(instrument.instrumentDescriptor.valueType, InstrumentValueType.double)
    XCTAssertEqual(
      instrument.instrumentDescriptor.type,
      InstrumentType.gauge
    )
  }

  func testGaugeOfLongs() {
    let myReader = PeriodicMetricReaderBuilder(
      exporter: MockMetricExporter()
    ).build()

    let meterProvider = MeterProviderSdk.builder()
      .registerMetricReader(reader: myReader)
      .registerView(
        selector: InstrumentSelector.builder().setMeter(name: "*").build(),
        view: View
          .builder().build()
      )
      .build()

    let meter = meterProvider.meterBuilder(name: "meter").build()
    let instrument = (
      meter
        .gaugeBuilder(
          name: "longGauge"
        ).ofLongs())
      .setUnit("unit")
      .setDescription("description")
      .build()

    XCTAssertEqual(instrument.instrumentDescriptor.name, "longGauge")
    XCTAssertEqual(instrument.instrumentDescriptor.unit, "unit")
    XCTAssertEqual(instrument.instrumentDescriptor.description, "description")
    XCTAssertEqual(instrument.instrumentDescriptor.valueType, InstrumentValueType.long)
    XCTAssertEqual(
      instrument.instrumentDescriptor.type,
      InstrumentType.gauge
    )
  }

  func testHistogramOfLongs() {
    let myReader = PeriodicMetricReaderBuilder(
      exporter: MockMetricExporter()
    ).build()

    let meterProvider = MeterProviderSdk.builder()
      .registerMetricReader(reader: myReader)
      .registerView(
        selector: InstrumentSelector.builder().setMeter(name: "*").build(),
        view: View
          .builder().build()
      )
      .build()

    let meter = meterProvider.meterBuilder(name: "meter").build()
    let instrument =
      meter
        .histogramBuilder(
          name: "longHistogram"
        ).ofLongs()
        .setUnit("unit")
        .setDescription("description")
        .build()
    XCTAssertEqual(instrument.instrumentDescriptor.name, "longHistogram")
    XCTAssertEqual(instrument.instrumentDescriptor.unit, "unit")
    XCTAssertEqual(instrument.instrumentDescriptor.description, "description")
    XCTAssertEqual(instrument.instrumentDescriptor.valueType, InstrumentValueType.long)
    XCTAssertEqual(instrument.instrumentDescriptor.type, InstrumentType.histogram)
  }

  func testHistogramOfDoubles() {
    let myReader = PeriodicMetricReaderBuilder(
      exporter: MockMetricExporter()
    ).build()

    let meterProvider = MeterProviderSdk.builder()
      .registerMetricReader(reader: myReader)
      .build()

    let meter = meterProvider.meterBuilder(name: "meter").build()
    let instrument =
      meter
        .histogramBuilder(
          name: "doubleHistogram"
        )
        .setUnit("unit")
        .setDescription("description")
        .build()

    XCTAssertEqual(instrument.instrumentDescriptor.name, "doubleHistogram")
    XCTAssertEqual(instrument.instrumentDescriptor.unit, "unit")
    XCTAssertEqual(instrument.instrumentDescriptor.description, "description")
    XCTAssertEqual(instrument.instrumentDescriptor.valueType, InstrumentValueType.double)
    XCTAssertEqual(instrument.instrumentDescriptor.type, InstrumentType.histogram)
  }

  func testLongUpDownInstrument() {
    let myReader = PeriodicMetricReaderBuilder(
      exporter: MockMetricExporter()
    ).build()

    let meterProvider = MeterProviderSdk.builder()
      .registerMetricReader(reader: myReader)
      .build()
    let meter = meterProvider.meterBuilder(name: "meter").build()
    let instrument = meter.upDownCounterBuilder(name: "updown")
      .setUnit("unit")
      .setDescription("description")
      .build()

    XCTAssertEqual(instrument.instrumentDescriptor.type, InstrumentType.upDownCounter)
    XCTAssertEqual(instrument.instrumentDescriptor.name, "updown")
    XCTAssertEqual(instrument.instrumentDescriptor.valueType, InstrumentValueType.long)
    XCTAssertEqual(instrument.instrumentDescriptor.description, "description")
    XCTAssertEqual(instrument.instrumentDescriptor.unit, "unit")
  }

  func testDoubleUpDownInstrument() {
    let myReader = PeriodicMetricReaderBuilder(
      exporter: MockMetricExporter()
    ).build()

    let meterProvider = MeterProviderSdk.builder()
      .registerMetricReader(reader: myReader)
      .build()

    let meter = meterProvider.meterBuilder(name: "meter").build()
    let instrument = meter.upDownCounterBuilder(name: "doubleUpdown").ofDoubles()
      .setUnit("unit")
      .setDescription("description")
      .build()

    XCTAssertEqual(instrument.instrumentDescriptor.name, "doubleUpdown")
    XCTAssertEqual(instrument.instrumentDescriptor.unit, "unit")
    XCTAssertEqual(instrument.instrumentDescriptor.description, "description")
    XCTAssertEqual(instrument.instrumentDescriptor.valueType, InstrumentValueType.double)
    XCTAssertEqual(instrument.instrumentDescriptor.type, InstrumentType.upDownCounter)
  }
}

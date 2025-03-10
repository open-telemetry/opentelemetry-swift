//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class BuilderTests: XCTestCase {
  func testBuilders() {
    let meterProvider = StableMeterProviderBuilder().build()
    let meter = meterProvider.meterBuilder(name: "meter").build()
    XCTAssertTrue(type(of: meter) == DefaultStableMeter.self)
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
    let myReader = StablePeriodicMetricReaderBuilder(
      exporter: MockStableMetricExporter()
    ).build()

    let meterProvider = StableMeterProviderBuilder()
      .registerMetricReader(reader:myReader)
      .registerView(
        selector: InstrumentSelector.builder().setMeter(name: "*").build(),
        view: StableView
          .builder().build()
      )
      .build()

    let meter = meterProvider.meterBuilder(name: "meter").build() as! StableMeterSdk
    let instrument = (
      meter
        .counterBuilder(
          name: "longCounter"
        ) as! LongCounterMeterBuilderSdk)
      .setUnit("unit")
      .setDescription("description")
      .build() as! LongCounterSdk

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
    let myReader = StablePeriodicMetricReaderBuilder(
      exporter: MockStableMetricExporter()
    ).build()

    let meterProvider = StableMeterProviderBuilder()
      .registerMetricReader(reader:myReader)
      .registerView(
        selector: InstrumentSelector.builder().setMeter(name: "*").build(),
        view: StableView
          .builder().build()
      )
      .build()

    let meter = meterProvider.meterBuilder(name: "meter").build() as! StableMeterSdk
    let instrument = (
      meter
        .counterBuilder(
          name: "doubleCounter"
        ).ofDoubles() as! DoubleCounterMeterBuilderSdk)
      .setUnit("unit")
      .setDescription("description")
      .build() as! DoubleCounterSdk

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
    let myReader = StablePeriodicMetricReaderBuilder(
      exporter: MockStableMetricExporter()
    ).build()

    let meterProvider = StableMeterProviderBuilder()
      .registerMetricReader(reader:myReader)
      .registerView(
        selector: InstrumentSelector.builder().setMeter(name: "*").build(),
        view: StableView
          .builder().build()
      )
      .build()

    let meter = meterProvider.meterBuilder(name: "meter").build() as! StableMeterSdk
    let instrument = (
      meter
        .gaugeBuilder(
          name: "doubleGauge"
        ) as! DoubleGaugeBuilderSdk)
      .setUnit("unit")
      .setDescription("description")
      .build() as! DoubleGaugeSdk

    XCTAssertEqual(instrument.instrumentDescriptor.name, "doubleGauge")
    XCTAssertEqual(instrument.instrumentDescriptor.unit, "unit")
    XCTAssertEqual(instrument.instrumentDescriptor.description, "description")
    XCTAssertEqual(instrument.instrumentDescriptor.valueType, InstrumentValueType.double)
    XCTAssertEqual(
      instrument.instrumentDescriptor.type,
      InstrumentType.observableGauge
    )

  }

  func testGaugeOfLongs() {
    let myReader = StablePeriodicMetricReaderBuilder(
      exporter: MockStableMetricExporter()
    ).build()

    let meterProvider = StableMeterProviderBuilder()
      .registerMetricReader(reader:myReader)
      .registerView(
        selector: InstrumentSelector.builder().setMeter(name: "*").build(),
        view: StableView
          .builder().build()
      )
      .build()

    let meter = meterProvider.meterBuilder(name: "meter").build() as! StableMeterSdk
    let instrument = (
      meter
        .gaugeBuilder(
          name: "longGauge"
        ).ofLongs () as! LongGaugeBuilderSdk)
      .setUnit("unit")
      .setDescription("description")
      .build() as!LongGaugeSdk

    XCTAssertEqual(instrument.instrumentDescriptor.name, "longGauge")
    XCTAssertEqual(instrument.instrumentDescriptor.unit, "unit")
    XCTAssertEqual(instrument.instrumentDescriptor.description, "description")
    XCTAssertEqual(instrument.instrumentDescriptor.valueType, InstrumentValueType.long)
    XCTAssertEqual(
      instrument.instrumentDescriptor.type,
      InstrumentType.observableGauge
    )
  }

  func testHistogramOfLongs() {
    let myReader = StablePeriodicMetricReaderBuilder(
      exporter: MockStableMetricExporter()
    ).build()

    let meterProvider = StableMeterProviderBuilder()
      .registerMetricReader(reader:myReader)
      .registerView(
        selector: InstrumentSelector.builder().setMeter(name: "*").build(),
        view: StableView
          .builder().build()
      )
      .build()

    let meter = meterProvider.meterBuilder(name: "meter").build() as! StableMeterSdk
    let instrument = (
      meter
        .histogramBuilder(
          name: "longHistogram"
        ).ofLongs() as! LongHistogramMeterBuilderSdk)
      .setUnit("unit")
      .setDescription("description")
      .build() as!LongHistogramMeterSdk

    XCTAssertEqual(instrument.instrumentDescriptor.name, "longHistogram")
    XCTAssertEqual(instrument.instrumentDescriptor.unit, "unit")
    XCTAssertEqual(instrument.instrumentDescriptor.description, "description")
    XCTAssertEqual(instrument.instrumentDescriptor.valueType, InstrumentValueType.long)
    XCTAssertEqual(instrument.instrumentDescriptor.type, InstrumentType.histogram)
  }

  func testHistogramOfDoubles() {
    let myReader = StablePeriodicMetricReaderBuilder(
      exporter: MockStableMetricExporter()
    ).build()

    let meterProvider = StableMeterProviderBuilder()
      .registerMetricReader(reader:myReader)
      .build()

    let meter = meterProvider.meterBuilder(name: "meter").build() as! StableMeterSdk
    let instrument = (
      meter
        .histogramBuilder(
          name: "doubleHistogram"
        ) as! DoubleHistogramMeterBuilderSdk)
      .setUnit("unit")
      .setDescription("description")
      .build() as! DoubleHistogramMeterSdk

    XCTAssertEqual(instrument.instrumentDescriptor.name, "doubleHistogram")
    XCTAssertEqual(instrument.instrumentDescriptor.unit, "unit")
    XCTAssertEqual(instrument.instrumentDescriptor.description, "description")
    XCTAssertEqual(instrument.instrumentDescriptor.valueType, InstrumentValueType.double)
    XCTAssertEqual(instrument.instrumentDescriptor.type, InstrumentType.histogram)
  }

  func testLongUpDownInstrument() {
    let myReader = StablePeriodicMetricReaderBuilder(
      exporter: MockStableMetricExporter()
    ).build()

    let meterProvider = StableMeterProviderBuilder()
      .registerMetricReader(reader:myReader)
      .build()
    let meter = meterProvider.meterBuilder(name: "meter").build() as! StableMeterSdk
    let instrument = (meter.upDownCounterBuilder(name: "updown") as! LongUpDownCounterBuilderSdk)
      .setUnit("unit")
      .setDescription("description")
      .build() as! LongUpDownCounterSdk

    XCTAssertEqual(instrument.instrumentDescriptor.type, InstrumentType.upDownCounter)
    XCTAssertEqual(instrument.instrumentDescriptor.name, "updown")
    XCTAssertEqual(instrument.instrumentDescriptor.valueType, InstrumentValueType.long)
    XCTAssertEqual(instrument.instrumentDescriptor.description, "description")
    XCTAssertEqual(instrument.instrumentDescriptor.unit, "unit")
  }
  func testDoubleUpDownInstrument() {
    let myReader = StablePeriodicMetricReaderBuilder(
      exporter: MockStableMetricExporter()
    ).build()
    
    let meterProvider = StableMeterProviderBuilder()
      .registerMetricReader(reader:myReader)
      .build()

    let meter = meterProvider.meterBuilder(name: "meter").build() as! StableMeterSdk
    let instrument = (meter.upDownCounterBuilder(name: "doubleUpdown").ofDoubles() as! DoubleUpDownCounterBuilderSdk)
      .setUnit("unit")
      .setDescription("description")
      .build() as! DoubleUpDownCounterSdk

    XCTAssertEqual(instrument.instrumentDescriptor.name, "doubleUpdown")
    XCTAssertEqual(instrument.instrumentDescriptor.unit, "unit")
    XCTAssertEqual(instrument.instrumentDescriptor.description, "description")
    XCTAssertEqual(instrument.instrumentDescriptor.valueType, InstrumentValueType.double)
    XCTAssertEqual(instrument.instrumentDescriptor.type, InstrumentType.upDownCounter)
  }
}

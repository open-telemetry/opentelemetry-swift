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

  func testAcceptsConformingInstrumentNames() {
    let names = [
      "a",
      "counter",
      "http.server.request.duration",
      "queue_size",
      "cache-hits",
      "system/cpu/time",
      "a1",
      "A_mixed.Case-name/1",
      String(repeating: "a", count: InstrumentBuilder.maximumNameLength)
    ]
    for name in names {
      XCTAssertTrue(InstrumentBuilder.isValidName(name), "expected \"\(name)\" to be valid")
    }
  }

  func testRejectsNonConformingInstrumentNames() {
    let names = [
      "", // empty
      "1counter", // leading digit
      "_counter", // leading underscore
      ".counter", // leading period
      "-counter", // leading hyphen
      "/counter", // leading slash
      "requests per second", // space
      "requests%", // disallowed punctuation
      "requests:total", // disallowed punctuation
      "café.requests", // non-ASCII
      String(repeating: "a", count: InstrumentBuilder.maximumNameLength + 1) // too long
    ]
    for name in names {
      XCTAssertFalse(InstrumentBuilder.isValidName(name), "expected \"\(name)\" to be invalid")
    }
  }

  func testBuildingInstrumentWithInvalidNameReportsFeedback() {
    let original = OpenTelemetry.instance.feedbackHandler
    defer {
      if let original {
        OpenTelemetry.registerFeedbackHandler(original)
      }
    }

    var messages: [String] = []
    OpenTelemetry.registerFeedbackHandler { messages.append($0) }

    let meter = Self.makeSdkMeter()
    _ = meter.counterBuilder(name: "1invalid").build()

    XCTAssertEqual(messages.count, 1)
    XCTAssertTrue(messages.first?.contains("1invalid") == true)
    XCTAssertTrue(messages.first?.contains("does not conform") == true)
  }

  func testBuildingInstrumentWithValidNameReportsNothing() {
    let original = OpenTelemetry.instance.feedbackHandler
    defer {
      if let original {
        OpenTelemetry.registerFeedbackHandler(original)
      }
    }

    var messages: [String] = []
    OpenTelemetry.registerFeedbackHandler { messages.append($0) }

    let meter = Self.makeSdkMeter()
    _ = meter.counterBuilder(name: "valid.counter").build()

    XCTAssertTrue(messages.isEmpty, "unexpected feedback: \(messages)")
  }

  /// A meter backed by `MeterSdk`. Without a registered reader the provider hands back a
  /// `DefaultMeter`, which never reaches `InstrumentBuilder`.
  private static func makeSdkMeter() -> any Meter {
    let reader = PeriodicMetricReaderBuilder(exporter: MockMetricExporter()).build()
    return MeterProviderSdk.builder()
      .registerMetricReader(reader: reader)
      .build()
      .meterBuilder(name: "meter")
      .build()
  }
}

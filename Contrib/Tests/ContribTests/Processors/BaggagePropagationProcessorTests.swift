/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import InMemoryExporter
import OpenTelemetryApi
import OpenTelemetrySdk
import BaggagePropagationProcessor
import XCTest

class BaggagePropagationProcessorTests: XCTestCase {
  func testProcessor() {
    guard let key = EntryKey(name: "test-key") else {
      XCTFail()
      return
    }

    guard let keep = EntryKey(name: "keepme") else {
      XCTFail("cannot create entry key")
      return
    }

    guard let value = EntryValue(string: "test-value") else {
      XCTFail()
      return
    }

    // create two baggage items, one we will keep and one will
    // be filtered out by the processor
    let b = DefaultBaggageManager.instance.baggageBuilder()
      .put(key: key, value: value, metadata: nil)
      .put(key: keep, value: value, metadata: nil)
      .build()

    var processor = BaggagePropagationProcessor(filter: { $0.key.name == "keepme" })
    processor.activeBaggage = { b }
    let exporter = InMemoryExporter()
    let simple = SimpleSpanProcessor(spanExporter: exporter)
    let tp = TracerProviderBuilder().add(spanProcessor: processor).add(spanProcessor: simple).build()
    let tracer = tp.get(instrumentationName: "test",
                        instrumentationVersion: "1.0.0")

    let parent = tracer.spanBuilder(spanName: "parent").startSpan()

    let child = tracer.spanBuilder(spanName: "child").startSpan()

    child.end()
    parent.end()

    simple.forceFlush()

    let spans = exporter.getFinishedSpanItems()
    XCTAssertEqual(spans.count, 2)

    guard let pChild = spans.first(where: { $0.name == "child" }) else {
      XCTFail("failed to find child span")
      return
    }

    XCTAssertTrue(spans.contains(where: { $0.name == "parent" }))

    XCTAssertEqual(pChild.attributes.count, 1)

    guard let attr = pChild.attributes.first else {
      XCTFail("failed to get span attributes")
      return
    }

    XCTAssertEqual(attr.key, "keepme")
    XCTAssertEqual(attr.value.description, "test-value")
  }
}

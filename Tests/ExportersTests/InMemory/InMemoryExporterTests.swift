// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

@testable import InMemoryExporter
@testable import OpenTelemetrySdk
@testable import OpenTelemetryApi
import XCTest

final class InMemoryExporterTests: XCTestCase {
  private var tracerSdkFactory = TracerProviderSdk()
  private var tracer: Tracer!
  private var exporter: InMemoryExporter!

  override func setUp() {
    exporter = InMemoryExporter()
    tracerSdkFactory.addSpanProcessor(SimpleSpanProcessor(spanExporter: exporter))
    tracer = tracerSdkFactory.get(instrumentationName: "InMemoryExporterTests")
  }

  func testGetFinishedSpanItems() {
    tracer.spanBuilder(spanName: "one").startSpan().end()
    tracer.spanBuilder(spanName: "two").startSpan().end()
    tracer.spanBuilder(spanName: "three").startSpan().end()

    let spans = exporter.getFinishedSpanItems()
    XCTAssertEqual(spans.count, 3)
    XCTAssertEqual(spans[0].name, "one")
    XCTAssertEqual(spans[1].name, "two")
    XCTAssertEqual(spans[2].name, "three")
  }

  func testResetClearsFinishedSpans() {
    tracer.spanBuilder(spanName: "one").startSpan().end()
    tracer.spanBuilder(spanName: "two").startSpan().end()
    tracer.spanBuilder(spanName: "three").startSpan().end()

    var spans = exporter.getFinishedSpanItems()
    XCTAssertEqual(spans.count, 3)

    exporter.reset()
    spans = exporter.getFinishedSpanItems()
    XCTAssertEqual(spans.count, 0)
  }

  func testResetDoesNotRestartAfterShutdown() {
    tracer.spanBuilder(spanName: "one").startSpan().end()

    exporter.shutdown()
    exporter.reset()

    XCTAssertEqual(exporter.export(spans: []), .failure)
  }

  func testShutdownClearsFinishedSpans() {
    tracer.spanBuilder(spanName: "one").startSpan().end()
    tracer.spanBuilder(spanName: "two").startSpan().end()
    tracer.spanBuilder(spanName: "three").startSpan().end()

    exporter.shutdown()

    let spans = exporter.getFinishedSpanItems()
    XCTAssertEqual(spans.count, 0)
  }

  func testShutdownStopsFurtherExports() {
    tracer.spanBuilder(spanName: "one").startSpan().end()
    tracer.spanBuilder(spanName: "two").startSpan().end()
    tracer.spanBuilder(spanName: "three").startSpan().end()

    exporter.shutdown()
    tracer.spanBuilder(spanName: "four").startSpan().end()

    let spans = exporter.getFinishedSpanItems()
    XCTAssertEqual(spans.count, 0)
  }

  func testExportReturnsSuccessWhenStarted() {
    XCTAssertEqual(exporter.export(spans: []), .success)
  }

  func testExportReturnsFailureWhenStopped() {
    exporter.shutdown()
    XCTAssertEqual(exporter.export(spans: []), .failure)
  }

  func testFlushReturnsSuccessWhenRunning() {
    XCTAssertEqual(exporter.flush(), .success)
  }

  func testFlushReturnsFailiureWhenStopped() {
    exporter.shutdown()
    XCTAssertEqual(exporter.flush(), .failure)
  }
}

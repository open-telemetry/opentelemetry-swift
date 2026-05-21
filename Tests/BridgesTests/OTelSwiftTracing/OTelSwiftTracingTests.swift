import XCTest
import InMemoryExporter
import OpenTelemetryApi
import OpenTelemetrySdk
import Tracing

@testable import OTelSwiftTracing

final class OTelSwiftTracingTests: XCTestCase {
  func testSpanAttributes() throws {
    let (tracer, exporter, processor) = makeTracer()

    tracer.withSpan("testSpan") { span in
      span.attributes = [
        "string": "value",
        "int": 1,
        "double": 2.5,
        "bool": true,
        "stringArray": .stringArray(["a", "b"])
      ]
    }

    processor.forceFlush()
    let exportedSpans = exporter.getFinishedSpanItems()
    XCTAssertEqual(exportedSpans.count, 1)
    let exportedSpan = try XCTUnwrap(exportedSpans.first)

    XCTAssertEqual(exportedSpan.attributes.count, 5)
    XCTAssertEqual(exportedSpan.attributes["string"], .string("value"))
    XCTAssertEqual(exportedSpan.attributes["int"], .int(1))
    XCTAssertEqual(exportedSpan.attributes["double"], .double(2.5))
    XCTAssertEqual(exportedSpan.attributes["bool"], .bool(true))
    XCTAssertEqual(
      exportedSpan.attributes["stringArray"],
      .array(AttributeArray(values: [.string("a"), .string("b")]))
    )
  }

  func testSpanExport() throws {
    let (tracer, exporter, processor) = makeTracer()

    tracer.withSpan("testSpan", ofKind: .client) { span in
      span.attributes["key"] = "value"
      span.addEvent(.init(name: "event", attributes: ["eventKey": "eventValue"]))
      span.setStatus(.init(code: .ok))
    }

    processor.forceFlush()
    let exportedSpans = exporter.getFinishedSpanItems()
    XCTAssertEqual(exportedSpans.count, 1)
    let exportedSpan = try XCTUnwrap(exportedSpans.first)
    XCTAssertEqual(exportedSpan.name, "testSpan")
    XCTAssertEqual(exportedSpan.kind, .client)
    XCTAssertEqual(exportedSpan.attributes.count, 1)
    XCTAssertEqual(exportedSpan.attributes["key"], .string("value"))
    XCTAssertEqual(exportedSpan.events.count, 1)
    XCTAssertEqual(exportedSpan.events.first?.name, "event")
    XCTAssertEqual(exportedSpan.events.first?.attributes.count, 1)
    XCTAssertEqual(exportedSpan.events.first?.attributes["eventKey"], .string("eventValue"))
    XCTAssertEqual(exportedSpan.links.count, 0)
    XCTAssertEqual(exportedSpan.status, .ok)
  }

  func testSpanParenting() throws {
    let (tracer, exporter, processor) = makeTracer()

    tracer.withSpan("parent") { _ in
      tracer.withSpan("child") { _ in }
    }

    processor.forceFlush()
    let exportedSpans = exporter.getFinishedSpanItems()
    XCTAssertEqual(exportedSpans.count, 2)
    let parentSpan = try XCTUnwrap(exportedSpans.first { $0.name == "parent" })
    let childSpan = try XCTUnwrap(exportedSpans.first { $0.name == "child" })

    XCTAssertNil(parentSpan.parentSpanId)
    XCTAssertEqual(childSpan.traceId, parentSpan.traceId)
    XCTAssertEqual(childSpan.parentSpanId, parentSpan.spanId)
    XCTAssertEqual(parentSpan.events.count, 0)
    XCTAssertEqual(childSpan.events.count, 0)
    XCTAssertEqual(parentSpan.links.count, 0)
    XCTAssertEqual(childSpan.links.count, 0)
  }

  func testInjectExtractSpanContext() {
    let (tracer, exporter, processor) = makeTracer()
    var carrier = [String: String]()
    var extractedContext = ServiceContext.topLevel
    var spanContext: OpenTelemetryApi.SpanContext?

    tracer.withSpan("testSpan") { span in
      spanContext = span.context.otelSpanContext
      tracer.inject(span.context, into: &carrier, using: DictionaryInjector())
      tracer.extract(carrier, into: &extractedContext, using: DictionaryExtractor())
    }

    XCTAssertNotNil(carrier["traceparent"])
    XCTAssertEqual(extractedContext.otelSpanContext?.traceId, spanContext?.traceId)
    XCTAssertEqual(extractedContext.otelSpanContext?.spanId, spanContext?.spanId)

    processor.forceFlush()
    let exportedSpans = exporter.getFinishedSpanItems()
    XCTAssertEqual(exportedSpans.count, 1)
    XCTAssertEqual(exportedSpans.first?.events.count, 0)
    XCTAssertEqual(exportedSpans.first?.links.count, 0)
  }

  func testSpanLinkExport() throws {
    let (tracer, exporter, processor) = makeTracer()

    var linkedSpanContext = ServiceContext.topLevel
    tracer.withSpan("linkedSpan") { span in
      linkedSpanContext = span.context
    }

    tracer.withSpan("testSpan") { span in
      span.addLink(.init(context: linkedSpanContext, attributes: ["linkKey": "linkValue"]))
    }

    processor.forceFlush()
    let exportedSpans = exporter.getFinishedSpanItems()
    XCTAssertEqual(exportedSpans.count, 2)
    let sourceSpan = try XCTUnwrap(exportedSpans.first { $0.name == "testSpan" })
    let linkedExportedSpan = try XCTUnwrap(exportedSpans.first { $0.name == "linkedSpan" })
    let link = try XCTUnwrap(sourceSpan.links.first)

    XCTAssertEqual(sourceSpan.links.count, 1)
    XCTAssertEqual(sourceSpan.events.count, 0)
    XCTAssertEqual(linkedExportedSpan.links.count, 0)
    XCTAssertEqual(linkedExportedSpan.events.count, 0)
    XCTAssertEqual(link.context.traceId, linkedExportedSpan.traceId)
    XCTAssertEqual(link.context.spanId, linkedExportedSpan.spanId)
    XCTAssertEqual(link.attributes["linkKey"], .string("linkValue"))
  }

  private func makeTracer() -> (
    tracer: any Tracing.Tracer,
    exporter: InMemoryExporter,
    processor: SimpleSpanProcessor
  ) {
    let exporter = InMemoryExporter()
    let processor = SimpleSpanProcessor(spanExporter: exporter)
    let tracerProvider = TracerProviderSdk(
      spanProcessors: [processor]
    )
    let tracer = OTelTracer(
      tracerProvider: tracerProvider,
      propagator: W3CTraceContextPropagator(),
    )
    return (tracer, exporter, processor)
  }
}

private struct DictionaryInjector: Injector {
  func inject(_ value: String, forKey key: String, into carrier: inout [String: String]) {
    carrier[key] = value
  }
}

private struct DictionaryExtractor: Extractor {
  func extract(key: String, from carrier: [String: String]) -> String? {
    carrier[key]
  }
}

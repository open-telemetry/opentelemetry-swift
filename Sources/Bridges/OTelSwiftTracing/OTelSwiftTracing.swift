import Foundation
import OpenTelemetryApi
import ServiceContextModule
import Tracing

private enum OTelSpanContextKey: ServiceContextKey {
    typealias Value = OpenTelemetryApi.SpanContext
}

extension ServiceContext {
    var otelSpanContext: OpenTelemetryApi.SpanContext? {
        get { self[OTelSpanContextKey.self] }
        set { self[OTelSpanContextKey.self] = newValue }
    }
}

let tracer = OTelTracer()

let _ = InstrumentationSystem.bootstrap(tracer)

/// A `swift-distributed-tracing` tracer which emits spans using OpenTelemetry Swift.
public struct OTelTracer: Tracing.Tracer, @unchecked Sendable {
    public typealias Span = OTelSpan

    private let tracerProvider: TracerProvider
    private let propagator: TextMapPropagator
    private let instrumentationName: String
    private let instrumentationVersion: String
    private let tracer: OpenTelemetryApi.Tracer

    public init(
        tracerProvider: TracerProvider = OpenTelemetry.instance.tracerProvider,
        propagator: TextMapPropagator = OpenTelemetry.instance.propagators.textMapPropagator,
        instrumentationName: String = "OTelSwiftTracing",
        instrumentationVersion: String = "1.0.0"
    ) {
        self.tracerProvider = tracerProvider
        self.propagator = propagator
        self.instrumentationName = instrumentationName
        self.instrumentationVersion = instrumentationVersion
        tracer = tracerProvider.get(
            instrumentationName: instrumentationName,
            instrumentationVersion: instrumentationVersion
        )
    }

    public func startSpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: Tracing.SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> OTelSpan {
        let parentContext = context()
        let spanBuilder = tracer.spanBuilder(spanName: operationName)
            .setActive(false)
            .setSpanKind(spanKind: Self.mapSpanKind(kind))
            .setStartTime(time: Self.date(from: instant()))

        if let parentSpanContext = parentContext.otelSpanContext, parentSpanContext.isValid {
            _ = spanBuilder.setParent(parentSpanContext)
        } else {
            _ = spanBuilder.setNoParent()
        }

        let otelSpan = spanBuilder.startSpan()

        var spanContext = parentContext
        spanContext.otelSpanContext = otelSpan.context
        return OTelSpan(otelSpan: otelSpan, context: spanContext)
    }

    @available(*, deprecated, message: "prefer withSpan")
    public func startAnySpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: Tracing.SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> any Tracing.Span {
        startSpan(
            operationName,
            context: context(),
            ofKind: kind,
            at: instant(),
            function: function,
            file: fileID,
            line: line
        )
    }

    @available(*, deprecated)
    public func forceFlush() {
        // Not available at the OpenTelemetryApi level.
    }

    public func extract<Carrier, Extract>(
        _ carrier: Carrier,
        into context: inout ServiceContext,
        using extractor: Extract
    ) where Extract: Extractor, Extract.Carrier == Carrier {
        var headers: [String: String] = [:]
        headers.reserveCapacity(propagator.fields.count)
        for key in propagator.fields {
            if let value = extractor.extract(key: key, from: carrier) {
                headers[key] = value
            }
        }

        if let extracted = propagator.extract(carrier: headers, getter: DictionaryGetter()) {
            context.otelSpanContext = extracted
        }
    }

    public func inject<Carrier, Inject>(
        _ context: ServiceContext,
        into carrier: inout Carrier,
        using injector: Inject
    ) where Inject: Injector, Inject.Carrier == Carrier {
        guard let spanContext = context.otelSpanContext, spanContext.isValid else {
            return
        }

        var headers: [String: String] = [:]
        propagator.inject(spanContext: spanContext, carrier: &headers, setter: DictionarySetter())
        for (key, value) in headers {
            injector.inject(value, forKey: key, into: &carrier)
        }
    }

    private static func mapSpanKind(_ kind: Tracing.SpanKind) -> OpenTelemetryApi.SpanKind {
        switch kind {
        case .server:
            return .server
        case .client:
            return .client
        case .producer:
            return .producer
        case .consumer:
            return .consumer
        case .internal:
            return .internal
        }
    }

    private static func date(from instant: some TracerInstant) -> Date {
        let seconds = Double(instant.nanosecondsSinceEpoch) / 1_000_000_000
        return Date(timeIntervalSince1970: seconds)
    }

    private struct DictionarySetter: Setter {
        func set(carrier: inout [String: String], key: String, value: String) {
            carrier[key] = value
        }
    }

    private struct DictionaryGetter: Getter {
        func get(carrier: [String: String], key: String) -> [String]? {
            guard let value = carrier[key] else { return nil }
            return [value]
        }
    }
}


public final class OTelSpan: Tracing.Span, @unchecked Sendable {
    public let context: ServiceContext

    private let otelSpan: OpenTelemetryApi.Span
    private let lock = NSLock()
    private var storedAttributes: Tracing.SpanAttributes = [:]
    private var storedLinks: [Tracing.SpanLink] = []

    internal init(otelSpan: OpenTelemetryApi.Span, context: ServiceContext) {
        self.otelSpan = otelSpan
        self.context = context
    }

    public var operationName: String {
        get { otelSpan.name }
        set { otelSpan.name = newValue }
    }

    public var attributes: Tracing.SpanAttributes {
        get {
            lock.withLock {
                storedAttributes
            }
        }
        set {
            lock.withLock {
                storedAttributes = newValue
                otelSpan.setAttributes(Self.convertAttributes(newValue))
            }
        }
    }

    public var isRecording: Bool {
        otelSpan.isRecording
    }

    public func setStatus(_ status: Tracing.SpanStatus) {
        switch status.code {
        case .ok:
            otelSpan.status = .ok
        case .error:
            otelSpan.status = .error(description: status.message ?? "")
        }
    }

    public func addEvent(_ event: Tracing.SpanEvent) {
        otelSpan.addEvent(
            name: event.name,
            attributes: Self.convertAttributes(event.attributes),
            timestamp: Self.date(fromNanosecondsSinceEpoch: event.nanosecondsSinceEpoch)
        )
    }

    public func recordError<Instant: TracerInstant>(
        _ error: Error,
        attributes: Tracing.SpanAttributes,
        at instant: @autoclosure () -> Instant
    ) {
        otelSpan.recordException(
            error,
            attributes: Self.convertAttributes(attributes),
            timestamp: Self.date(from: instant())
        )
    }

    public func addLink(_ link: Tracing.SpanLink) {
        // OpenTelemetry Swift only supports links at span creation time (builder-time).
        // Swift Distributed Tracing allows adding links after span creation.
        
        // Potentially workaround:
        // Create a spanBuilder internally but DONT start it (but set its startDate)
        // propagate that builder's spanContext as the "real" spanContext for parenting and propagation purposes
        // only when ending the span we actualyly start the span using the builder, which allows us to add links until the end of the span.
        //
        // The consequence would be that activeSpan would not reflect the correct value
        // This might be acceptable since users will likely rely on Swift DistributedTracing (which doesnt offer access to it)
    }

    public func end<Instant: TracerInstant>(at instant: @autoclosure () -> Instant) {
        otelSpan.end(time: Self.date(from: instant()))
    }

    private static func convertAttributes(_ attributes: Tracing.SpanAttributes) -> [String:
        AttributeValue]
    {
        var converted: [String: AttributeValue] = [:]
        converted.reserveCapacity(attributes.count)
        attributes.forEach { key, value in
            if let convertedValue = Self.convertAttributeValue(value) {
                converted[key] = convertedValue
            }
        }
        return converted
    }

    private static func convertAttributeValue(_ value: Tracing.SpanAttribute) -> AttributeValue? {
        switch value {
        case .int32(let v):
            return Int(exactly: v).map(AttributeValue.init) ?? .string(String(describing: v))
        case .int64(let v):
            return Int(exactly: v).map(AttributeValue.init) ?? .string(String(describing: v))
        case .int32Array(let v):
            return .array(
                AttributeArray(values: v.compactMap { Int(exactly: $0) }.map(AttributeValue.init))
            )
        case .int64Array(let v):
            return .array(
                AttributeArray(values: v.compactMap { Int(exactly: $0) }.map(AttributeValue.init))
            )
        case .double(let v):
            return .double(v)
        case .doubleArray(let v):
            return .array(AttributeArray(values: v.map(AttributeValue.init)))
        case .bool(let v):
            return .bool(v)
        case .boolArray(let v):
            return .array(AttributeArray(values: v.map(AttributeValue.init)))
        case .string(let v):
            return .string(v)
        case .stringArray(let v):
            return .array(AttributeArray(values: v.map(AttributeValue.init)))
        case .stringConvertible(let v):
            return .string(String(describing: v))
        case .stringConvertibleArray(let v):
            return .array(
                AttributeArray(values: v.map { AttributeValue.string(String(describing: $0)) })
            )
        default:
            return nil
        }
    }

    private static func date(from instant: some TracerInstant) -> Date {
        let seconds = Double(instant.nanosecondsSinceEpoch) / 1_000_000_000
        return Date(timeIntervalSince1970: seconds)
    }

    private static func date(fromNanosecondsSinceEpoch nanos: UInt64) -> Date {
        let seconds = Double(nanos) / 1_000_000_000
        return Date(timeIntervalSince1970: seconds)
    }
}

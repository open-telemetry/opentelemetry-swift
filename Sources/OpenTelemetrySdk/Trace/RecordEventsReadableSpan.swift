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
import OpenTelemetryApi

/// Implementation for the Span class that records trace events.
public class RecordEventsReadableSpan: ReadableSpan {
    public var isRecordingEvents = true
    /// The displayed name of the span.
    public var name: String {
        didSet {
            if hasEnded {
                name = oldValue
            }
        }
    }

    /// Contains the identifiers associated with this Span.
    public private(set) var context: SpanContext
    /// The parent SpanId of this span. Invalid if this is a root span.
    private(set) var parentSpanId: SpanId?
    /// True if the parent is on a different process.
    public private(set) var hasRemoteParent: Bool
    /// /Handler called when the span starts and ends.
    public private(set) var spanProcessor: SpanProcessor
    /// List of recorded links to parent and child spans.
    public private(set) var links = [Link]()
    /// Number of links recorded.
    public private(set) var totalRecordedLinks: Int

    /// The kind of the span.
    public private(set) var kind: SpanKind
    /// The clock used to get the time.
    public private(set) var clock: Clock
    /// The resource associated with this span.
    public private(set) var resource: Resource
    /// The start time of the span.
    /// instrumentation library of the named tracer which created this span
    public private(set) var instrumentationLibraryInfo: InstrumentationLibraryInfo
    /// The resource associated with this span.
    public private(set) var startEpochNanos: Int
    /// Set of recorded attributes. DO NOT CALL any other method that changes the ordering of events.
    private var attributes: AttributesWithCapacity
    /// List of recorded events.
    public private(set) var events: ArrayWithCapacity<TimedEvent>
    /// Number of events recorded.
    public private(set) var totalRecordedEvents = 0
    /// The number of children.
    public private(set) var numberOfChildren: Int = 0
    /// The status of the span.
    public var status: Status? = Status.ok {
        didSet {
            if hasEnded || status == nil {
                status = oldValue
            }
        }
    }

    /// Returns the latency of the {@code Span} in nanos. If still active then returns now() - start time.
    public var latencyNanos: Int {
        return (hasEnded ? endEpochNanos! : clock.now) - startEpochNanos
    }

    /// The end time of the span.
    public private(set) var endEpochNanos: Int?
    /// True if the span is ended.
    public private(set) var hasEnded: Bool = false

    private init(context: SpanContext,
                 name: String,
                 instrumentationLibraryInfo: InstrumentationLibraryInfo,
                 kind: SpanKind,
                 parentSpanId: SpanId?,
                 hasRemoteParent: Bool,
                 traceConfig: TraceConfig,
                 spanProcessor: SpanProcessor,
                 clock: Clock,
                 resource: Resource,
                 attributes: AttributesWithCapacity,
                 links: [Link],
                 totalRecordedLinks: Int,
                 startEpochNanos: Int) {
        self.context = context
        self.name = name
        self.instrumentationLibraryInfo = instrumentationLibraryInfo
        self.parentSpanId = parentSpanId
        self.hasRemoteParent = hasRemoteParent
        self.links = links
        self.totalRecordedLinks = totalRecordedLinks
        self.kind = kind
        self.spanProcessor = spanProcessor
        self.clock = clock
        self.resource = resource
        self.startEpochNanos = (startEpochNanos == 0 ? clock.now : startEpochNanos)
        self.attributes = attributes
        events = ArrayWithCapacity<TimedEvent>(capacity: traceConfig.maxNumberOfEvents)
    }

    /// Creates and starts a span with the given configuration.
    /// - Parameters:
    ///   - context: supplies the trace_id and span_id for the newly started span.
    ///   - name: the displayed name for the new span.
    ///   - instrumentationLibraryInfo: the information about the instrumentation library
    ///   - kind: the span kind.
    ///   - parentSpanId: the span_id of the parent span, or nil if the new span is a root span.
    ///   - hasRemoteParent: true if the parentContext is remote, false if this is a root span.
    ///   - traceConfig: trace parameters like sampler and probability.
    ///   - spanProcessor: handler called when the span starts and ends.
    ///   - clock: the clock used to get the time.
    ///   - resource: the resource associated with this span.
    ///   - attributes: the attributes set during span creation.
    ///   - links: the links set during span creation, may be truncated.
    ///   - totalRecordedLinks: the total number of links set (including dropped links).
    ///   - startEpochNanos: the timestamp for the new span.
    public static func startSpan(context: SpanContext,
                                 name: String,
                                 instrumentationLibraryInfo: InstrumentationLibraryInfo,
                                 kind: SpanKind,
                                 parentSpanId: SpanId?,
                                 hasRemoteParent: Bool,
                                 traceConfig: TraceConfig,
                                 spanProcessor: SpanProcessor,
                                 clock: Clock,
                                 resource: Resource,
                                 attributes: AttributesWithCapacity,
                                 links: [Link],
                                 totalRecordedLinks: Int,
                                 startEpochNanos: Int) -> RecordEventsReadableSpan {
        let span = RecordEventsReadableSpan(context: context,
                                            name: name,
                                            instrumentationLibraryInfo: instrumentationLibraryInfo,
                                            kind: kind, parentSpanId: parentSpanId,
                                            hasRemoteParent: hasRemoteParent,
                                            traceConfig: traceConfig,
                                            spanProcessor: spanProcessor,
                                            clock: clock,
                                            resource: resource,
                                            attributes: attributes,
                                            links: links,
                                            totalRecordedLinks: totalRecordedLinks,
                                            startEpochNanos: startEpochNanos)
        spanProcessor.onStart(span: span)
        return span
    }

    public func toSpanData() -> SpanData {
        return SpanData(traceId: context.traceId,
                        spanId: context.spanId,
                        traceFlags: context.traceFlags,
                        traceState: context.traceState,
                        parentSpanId: parentSpanId,
                        resource: resource,
                        instrumentationLibraryInfo: instrumentationLibraryInfo,
                        name: name,
                        kind: kind,
                        startEpochNanos: startEpochNanos,
                        attributes: attributes.dictionary,
                        timedEvents: adaptTimedEvents(),
                        links: adaptLinks(),
                        status: status,
                        endEpochNanos: endEpochNanos ?? clock.now,
                        hasRemoteParent: hasRemoteParent,
                        hasEnded: hasEnded,
                        totalRecordedEvents: totalRecordedEvents,
                        totalRecordedLinks: totalRecordedLinks)
    }

    private func adaptTimedEvents() -> [SpanData.TimedEvent] {
        let sourceEvents = events
        var result = [SpanData.TimedEvent]()
        sourceEvents.forEach {
            result.append(SpanData.TimedEvent(epochNanos: $0.epochNanos, name: $0.name, attributes: $0.attributes))
        }
        return result
    }

    private func adaptLinks() -> [SpanData.Link] {
        var result = [SpanData.Link]()
        links.forEach {
            result.append(SpanData.Link(context: $0.context, attributes: $0.attributes))
        }
        return result
    }

    public func setAttribute(key: String, value: String) {
        if value.isEmpty {
            return
        }
        setAttribute(key: key, value: AttributeValue.string(value))
    }

    public func setAttribute(key: String, value: Int) {
        setAttribute(key: key, value: AttributeValue.int(value))
    }

    public func setAttribute(key: String, value: Double) {
        setAttribute(key: key, value: AttributeValue.double(value))
    }

    public func setAttribute(key: String, value: Bool) {
        setAttribute(key: key, value: AttributeValue.bool(value))
    }

    public func setAttribute(key: String, value: AttributeValue) {
        if case let .string(string) = value,
            string?.isEmpty ?? true {
            return
        }

        if hasEnded {
            return
        }
        attributes[key] = value
    }

    public func addEvent(name: String) {
        addTimedEvent(timedEvent: TimedEvent(nanotime: clock.now, name: name))
    }

    public func addEvent(name: String, timestamp: Int) {
        addTimedEvent(timedEvent: TimedEvent(nanotime: timestamp, name: name))
    }

    public func addEvent(name: String, attributes: [String: AttributeValue]) {
        addTimedEvent(timedEvent: TimedEvent(nanotime: clock.now, name: name, attributes: attributes))
    }

    public func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Int) {
        addTimedEvent(timedEvent: TimedEvent(nanotime: timestamp, name: name, attributes: attributes))
    }

    public func addEvent<E>(event: E) where E: Event {
        addTimedEvent(timedEvent: TimedEvent(nanotime: clock.now, event: event))
    }

    public func addEvent<E>(event: E, timestamp: Int) where E: Event {
        addTimedEvent(timedEvent: TimedEvent(nanotime: timestamp, event: event))
    }

    private func addTimedEvent(timedEvent: TimedEvent) {
        if hasEnded {
            return
        }
        events.append(timedEvent)
        totalRecordedEvents += 1
    }

    public func end() {
        endInternal(timestamp: clock.now)
    }

    public func end(endOptions: EndSpanOptions) {
        endInternal(timestamp: endOptions.timestamp == 0 ? clock.now : endOptions.timestamp)
    }

    private func endInternal(timestamp: Int) {
        if hasEnded {
            return
        }
        endEpochNanos = timestamp
        hasEnded = true
        spanProcessor.onEnd(span: self)
    }

    public func addChild() {
        if hasEnded {
            return
        }
        numberOfChildren += 1
    }

    private func getStatusWithDefault() -> Status {
        return status ?? Status.ok
    }

    public var description: String {
        return "RecordEventsReadableSpan{}"
    }

    /// For testing purposes
    internal func getDroppedLinksCount() -> Int {
        return totalRecordedLinks - links.count
    }

    internal func getNumberOfChildren() -> Int {
        return numberOfChildren
    }

    internal func getTotalRecordedEvents() -> Int {
        return totalRecordedEvents
    }
}

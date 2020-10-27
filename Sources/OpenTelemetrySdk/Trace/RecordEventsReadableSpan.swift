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

    // The config used when constructing this Span.
    public private(set) var traceConfig: TraceConfig
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
    /// Max number of attibutes per span.
    public private(set) var maxNumberOfAttributes: Int
    /// Max number of attributes per event.
    public private(set) var maxNumberOfAttributesPerEvent: Int

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
    public private(set) var startEpochNanos: UInt64
    /// Set of recorded attributes. DO NOT CALL any other method that changes the ordering of events.
    private var attributes: AttributesWithCapacity
    /// List of recorded events.
    public private(set) var events: ArrayWithCapacity<TimedEvent>
    /// Number of attributes recorded.
    public private(set) var totalAttributeCount: Int = 0
    /// Number of events recorded.
    public private(set) var totalRecordedEvents = 0
    /// The status of the span.
    public var status: Status? = Status.ok {
        didSet {
            if hasEnded || status == nil {
                status = oldValue
            }
        }
    }

    /// Returns the latency of the {@code Span} in nanos. If still active then returns now() - start time.
    public var latencyNanos: UInt64 {
        return (hasEnded ? endEpochNanos! : clock.now) - startEpochNanos
    }

    /// The end time of the span.
    public private(set) var endEpochNanos: UInt64?

    private let endSyncLock = Lock()
    private var endedPrivate = false
    /// True if the span is ended.
    public private(set) var hasEnded: Bool {
        get {
            endSyncLock.withLock{ return self.endedPrivate }
        }
        set(newValue) {
            endSyncLock.withLockVoid {self.endedPrivate = newValue}
        }
    }

    private let eventsSyncLock = Lock()
    private let attributesSyncLock = Lock()

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
                 startEpochNanos: UInt64) {
        self.context = context
        self.name = name
        self.instrumentationLibraryInfo = instrumentationLibraryInfo
        self.parentSpanId = parentSpanId
        self.hasRemoteParent = hasRemoteParent
        self.traceConfig = traceConfig
        self.links = links
        self.totalRecordedLinks = totalRecordedLinks
        self.kind = kind
        self.spanProcessor = spanProcessor
        self.clock = clock
        self.resource = resource
        self.startEpochNanos = (startEpochNanos == 0 ? clock.now : startEpochNanos)
        self.attributes = attributes
        events = ArrayWithCapacity<TimedEvent>(capacity: traceConfig.maxNumberOfEvents)
        maxNumberOfAttributes = traceConfig.maxNumberOfAttributes
        maxNumberOfAttributesPerEvent = traceConfig.maxNumberOfAttributesPerEvent
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
                                 startEpochNanos: UInt64) -> RecordEventsReadableSpan {
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
                        attributes: attributes.attributes,
                        timedEvents: adaptTimedEvents(),
                        links: adaptLinks(),
                        status: status,
                        endEpochNanos: endEpochNanos ?? clock.now,
                        hasRemoteParent: hasRemoteParent,
                        hasEnded: hasEnded,
                        totalRecordedEvents: totalRecordedEvents,
                        totalRecordedLinks: totalRecordedLinks,
                        totalAttributeCount: totalAttributeCount)
    }

    private func adaptTimedEvents() -> [TimedEvent] {
        var result = [TimedEvent]()
        eventsSyncLock.withLockVoid {
            events.forEach {
                result.append(TimedEvent(name: $0.name, epochNanos: $0.epochNanos, attributes: $0.attributes))
            }
        }
        return result
    }

    private func adaptLinks() -> [SpanData.Link] {
        var result = [SpanData.Link]()
        let linksRef = links
        linksRef.forEach {
            result.append(SpanData.Link(context: $0.context, attributes: $0.attributes))
        }
        return result
    }

    public func setAttribute(key: String, value: AttributeValue?) {
        if hasEnded {
            return
        }

        attributesSyncLock.withLockVoid {
            if value == nil {
                attributes.removeValueForKey(key: key)
            }
            totalAttributeCount += 1
            if attributes[key] == nil, totalAttributeCount > maxNumberOfAttributes {
                return
            }
            attributes[key] = value
        }
    }

    public func addEvent(name: String) {
        addTimedEvent(timedEvent: TimedEvent(name: name, epochNanos: clock.now))
    }

    public func addEvent(name: String, timestamp: Date) {
        addTimedEvent(timedEvent: TimedEvent(name: name, timestamp: timestamp))
    }

    public func addEvent(name: String, attributes: [String: AttributeValue]) {
        var limitedAttributes = AttributesWithCapacity(capacity: maxNumberOfAttributesPerEvent)
        limitedAttributes.updateValues(attributes: attributes)
        addTimedEvent(timedEvent: TimedEvent(name: name, epochNanos: clock.now, attributes: limitedAttributes.attributes))
    }

    public func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {
        var limitedAttributes = AttributesWithCapacity(capacity: maxNumberOfAttributesPerEvent)
        limitedAttributes.updateValues(attributes: attributes)
        addTimedEvent(timedEvent: TimedEvent(name: name, timestamp: timestamp, attributes: limitedAttributes.attributes))
    }

    public func addEvent<E>(event: E) where E: Event {
        addTimedEvent(timedEvent: TimedEvent(epochNanos: clock.now, event: event))
    }

    public func addEvent(event: TimedEvent) {
        addTimedEvent(timedEvent: event)
    }

    public func addEvent<E>(event: E, timestamp: Date) where E: Event {
        addTimedEvent(timedEvent: TimedEvent(timestamp: timestamp, event: event))
    }

    private func addTimedEvent(timedEvent: TimedEvent) {
        if hasEnded {
            return
        }
        eventsSyncLock.withLockVoid {
            events.append(timedEvent)
            totalRecordedEvents += 1
        }
    }

    public func end() {
        endInternal(timestamp: clock.now)
    }

    public func end(endOptions: EndSpanOptions) {
        endInternal(timestamp: endOptions.timestamp == 0 ? clock.now : endOptions.timestamp)
    }

    private func endInternal(timestamp: UInt64) {
        if hasEnded {
            return
        }
        hasEnded = true
        endEpochNanos = timestamp
        spanProcessor.onEnd(span: self)
        context.scope?.close()
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

    internal func getTotalRecordedEvents() -> Int {
        return totalRecordedEvents
    }
}

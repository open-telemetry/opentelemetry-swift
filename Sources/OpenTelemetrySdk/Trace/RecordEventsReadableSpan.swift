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
import Atomics

/// Implementation for the Span class that records trace events.
public class RecordEventsReadableSpan: ReadableSpan {
    public var isRecording = true
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
    public private(set) var parentContext: SpanContext?
    /// True if the parent is on a different process.
    public private(set) var hasRemoteParent: Bool
    /// /Handler called when the span starts and ends.
    public private(set) var spanProcessor: SpanProcessor
    /// List of recorded links to parent and child spans.
    public private(set) var links = [SpanData.Link]()
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
    public private(set) var startTime: Date
    /// Set of recorded attributes. DO NOT CALL any other method that changes the ordering of events.
    private var attributes: AttributesDictionary
    /// List of recorded events.
    public private(set) var events: ArrayWithCapacity<SpanData.Event>
    /// Number of attributes recorded.
    public private(set) var totalAttributeCount: Int = 0
    /// Number of events recorded.
    public private(set) var totalRecordedEvents = 0
    /// The status of the span.
    public var status: Status = Status.unset {
        didSet {
            if hasEnded {
                status = oldValue
            }
        }
    }

    /// The scope where the span is associated
    public var scope: Scope?

    /// Returns the latency of the Span in seconds. If still active then returns now() - start time.
    public var latency: TimeInterval {
        return endTime?.timeIntervalSince(startTime) ?? clock.now.timeIntervalSince(startTime)
    }

    /// The end time of the span.
    public private(set) var endTime: Date?
    /// True if the span is ended.
    fileprivate var endAtomic = ManagedAtomic<Bool>(false)
    public var hasEnded: Bool {
        get {
            return self.endAtomic.load(ordering: .relaxed)
        }
    }

    private let eventsSyncLock = Lock()
    private let attributesSyncLock = Lock()

    private init(context: SpanContext,
                 name: String,
                 instrumentationLibraryInfo: InstrumentationLibraryInfo,
                 kind: SpanKind,
                 parentContext: SpanContext?,
                 hasRemoteParent: Bool,
                 traceConfig: TraceConfig,
                 spanProcessor: SpanProcessor,
                 clock: Clock,
                 resource: Resource,
                 attributes: AttributesDictionary,
                 links: [SpanData.Link],
                 totalRecordedLinks: Int,
                 startTime: Date?) {
        self.context = context
        self.name = name
        self.instrumentationLibraryInfo = instrumentationLibraryInfo
        self.parentContext = parentContext
        self.hasRemoteParent = hasRemoteParent
        self.traceConfig = traceConfig
        self.links = links
        self.totalRecordedLinks = totalRecordedLinks
        self.kind = kind
        self.spanProcessor = spanProcessor
        self.clock = clock
        self.resource = resource
        self.startTime = startTime ?? clock.now
        self.attributes = attributes
        events = ArrayWithCapacity<SpanData.Event>(capacity: traceConfig.maxNumberOfEvents)
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
    ///   - startTime: the time for the new span.
    public static func startSpan(context: SpanContext,
                                 name: String,
                                 instrumentationLibraryInfo: InstrumentationLibraryInfo,
                                 kind: SpanKind,
                                 parentContext: SpanContext?,
                                 hasRemoteParent: Bool,
                                 traceConfig: TraceConfig,
                                 spanProcessor: SpanProcessor,
                                 clock: Clock,
                                 resource: Resource,
                                 attributes: AttributesDictionary,
                                 links: [SpanData.Link],
                                 totalRecordedLinks: Int,
                                 startTime: Date) -> RecordEventsReadableSpan {
        let span = RecordEventsReadableSpan(context: context,
                                            name: name,
                                            instrumentationLibraryInfo: instrumentationLibraryInfo,
                                            kind: kind,
                                            parentContext: parentContext,
                                            hasRemoteParent: hasRemoteParent,
                                            traceConfig: traceConfig,
                                            spanProcessor: spanProcessor,
                                            clock: clock,
                                            resource: resource,
                                            attributes: attributes,
                                            links: links,
                                            totalRecordedLinks: totalRecordedLinks,
                                            startTime: startTime)
        spanProcessor.onStart(parentContext: parentContext, span: span)
        return span
    }

    public func toSpanData() -> SpanData {
        return SpanData(traceId: context.traceId,
                        spanId: context.spanId,
                        traceFlags: context.traceFlags,
                        traceState: context.traceState,
                        parentSpanId: parentContext?.spanId,
                        resource: resource,
                        instrumentationLibraryInfo: instrumentationLibraryInfo,
                        name: name,
                        kind: kind,
                        startTime: startTime,
                        attributes: attributes.attributes,
                        events: adaptEvents(),
                        links: adaptLinks(),
                        status: status,
                        endTime: endTime ?? clock.now,
                        hasRemoteParent: hasRemoteParent,
                        hasEnded: hasEnded,
                        totalRecordedEvents: totalRecordedEvents,
                        totalRecordedLinks: totalRecordedLinks,
                        totalAttributeCount: totalAttributeCount)
    }

    private func adaptEvents() -> [SpanData.Event] {
        let sourceEvents = events
        var result = [SpanData.Event]()
        sourceEvents.forEach {
            result.append(SpanData.Event(name: $0.name, timestamp: $0.timestamp, attributes: $0.attributes))
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
        attributesSyncLock.withLockVoid {
            if !isRecording {
                return
            }
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
        addEvent(event: SpanData.Event(name: name, timestamp: clock.now))
    }

    public func addEvent(name: String, timestamp: Date) {
        addEvent(event: SpanData.Event(name: name, timestamp: timestamp))
    }

    public func addEvent(name: String, attributes: [String: AttributeValue]) {
        var limitedAttributes = AttributesDictionary(capacity: maxNumberOfAttributesPerEvent)
        limitedAttributes.updateValues(attributes: attributes)
        addEvent(event: SpanData.Event(name: name, timestamp: clock.now, attributes: limitedAttributes.attributes))
    }

    public func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {
        var limitedAttributes = AttributesDictionary(capacity: maxNumberOfAttributesPerEvent)
        limitedAttributes.updateValues(attributes: attributes)
        addEvent(event: SpanData.Event(name: name, timestamp: timestamp, attributes: limitedAttributes.attributes))
    }

    private func addEvent(event: SpanData.Event) {
        eventsSyncLock.withLockVoid {
            if !isRecording {
                return
            }
            events.append(event)
            totalRecordedEvents += 1
        }
    }

    public func end() {
        end(time: clock.now)
    }

    public func end(time: Date) {
        if endAtomic.exchange(true, ordering: .relaxed) {
            return
        }
        eventsSyncLock.withLockVoid{
            attributesSyncLock.withLockVoid{
                isRecording = false
            }
        }
        endTime = time
        spanProcessor.onEnd(span: self)
        scope?.close()
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

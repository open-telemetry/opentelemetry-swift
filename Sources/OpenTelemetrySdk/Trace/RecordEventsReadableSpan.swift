/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// Implementation for the Span class that records trace events.
public class RecordEventsReadableSpan: ReadableSpan {
    public var isRecording = true

    fileprivate let internalStatusQueue = DispatchQueue(label: "org.opentelemetry.RecordEventsReadableSpan.internalStatusQueue", attributes: .concurrent)
    /// The displayed name of the span.
    fileprivate var internalName: String
    public var name: String {
        get {
            var value: String = ""
            internalStatusQueue.sync {
                value = internalName
            }
            return value
        }
        set {
            internalStatusQueue.sync(flags: .barrier) {
                if !internalEnd {
                    internalName = newValue
                }
            }
        }
    }

    // The config used when constructing this Span.
    public private(set) var spanLimits: SpanLimits
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
    /// Max number of attributes per span.
    public private(set) var maxNumberOfAttributes: Int
    /// Max number of attributes per event.
    public private(set) var maxNumberOfAttributesPerEvent: Int

    /// The kind of the span.
    public private(set) var kind: SpanKind
    /// The clock used to get the time.
    public private(set) var clock: Clock
    /// The resource associated with this span.
    public private(set) var resource: Resource
    /// instrumentation library of the named tracer which created this span
    public private(set) var instrumentationScopeInfo: InstrumentationScopeInfo
    /// The start time of the span.
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
    fileprivate var internalStatus: Status = .unset
    public var status: Status {
        get {
            var value: Status = .unset
            internalStatusQueue.sync {
                value = internalStatus
            }
            return value
        }
        set {
            internalStatusQueue.sync(flags: .barrier) {
                if !internalEnd {
                    internalStatus = newValue
                }
            }
        }
    }

    /// Returns the latency of the Span in seconds. If still active then returns now() - start time.
    public var latency: TimeInterval {
        return endTime?.timeIntervalSince(startTime) ?? clock.now.timeIntervalSince(startTime)
    }

    /// The end time of the span.
    public private(set) var endTime: Date?
    /// True if the span is ended.
    fileprivate var internalEnd = false
    public var hasEnded: Bool {
        var value = false
        internalStatusQueue.sync {
            value = internalEnd
        }
        return value
    }

    private let eventsSyncLock = Lock()
    private let attributesSyncLock = Lock()

    private init(context: SpanContext,
                 name: String,
                 instrumentationScopeInfo: InstrumentationScopeInfo,
                 kind: SpanKind,
                 parentContext: SpanContext?,
                 hasRemoteParent: Bool,
                 spanLimits: SpanLimits,
                 spanProcessor: SpanProcessor,
                 clock: Clock,
                 resource: Resource,
                 attributes: AttributesDictionary,
                 links: [SpanData.Link],
                 totalRecordedLinks: Int,
                 startTime: Date?)
    {
        self.context = context
        self.internalName = name
        self.instrumentationScopeInfo = instrumentationScopeInfo
        self.parentContext = parentContext
        self.hasRemoteParent = hasRemoteParent
        self.spanLimits = spanLimits
        self.links = links
        self.totalRecordedLinks = totalRecordedLinks
        self.kind = kind
        self.spanProcessor = spanProcessor
        self.clock = clock
        self.resource = resource
        self.startTime = startTime ?? clock.now
        self.attributes = attributes
        self.totalAttributeCount = attributes.count
        events = ArrayWithCapacity<SpanData.Event>(capacity: spanLimits.eventCountLimit)
        maxNumberOfAttributes = spanLimits.attributeCountLimit
        maxNumberOfAttributesPerEvent = spanLimits.attributePerEventCountLimit
    }

    /// Creates and starts a span with the given configuration.
    /// - Parameters:
    ///   - context: supplies the trace_id and span_id for the newly started span.
    ///   - name: the displayed name for the new span.
    ///   - instrumentationScopeInfo: the information about the instrumentation Scope
    ///   - kind: the span kind.
    ///   - parentSpanId: the span_id of the parent span, or nil if the new span is a root span.
    ///   - hasRemoteParent: true if the parentContext is remote, false if this is a root span.
    ///   - spanLimits: trace parameters like sampler and probability.
    ///   - spanProcessor: handler called when the span starts and ends.
    ///   - clock: the clock used to get the time.
    ///   - resource: the resource associated with this span.
    ///   - attributes: the attributes set during span creation.
    ///   - links: the links set during span creation, may be truncated.
    ///   - totalRecordedLinks: the total number of links set (including dropped links).
    ///   - startTime: the time for the new span, if not set it will use assigned Clock time
    public static func startSpan(context: SpanContext,
                                 name: String,
                                 instrumentationScopeInfo: InstrumentationScopeInfo,
                                 kind: SpanKind,
                                 parentContext: SpanContext?,
                                 hasRemoteParent: Bool,
                                 spanLimits: SpanLimits,
                                 spanProcessor: SpanProcessor,
                                 clock: Clock,
                                 resource: Resource,
                                 attributes: AttributesDictionary,
                                 links: [SpanData.Link],
                                 totalRecordedLinks: Int,
                                 startTime: Date?) -> RecordEventsReadableSpan
    {
        let span = RecordEventsReadableSpan(context: context,
                                            name: name,
                                            instrumentationScopeInfo: instrumentationScopeInfo,
                                            kind: kind,
                                            parentContext: parentContext,
                                            hasRemoteParent: hasRemoteParent,
                                            spanLimits: spanLimits,
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
                        instrumentationScope: instrumentationScopeInfo,
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
                        totalRecordedEvents: getTotalRecordedEvents(),
                        totalRecordedLinks: totalRecordedLinks,
                        totalAttributeCount: totalAttributeCount)
    }

    private func adaptEvents() -> [SpanData.Event] {
        var sourceEvents = [SpanData.Event]()
        eventsSyncLock.withLockVoid {
            sourceEvents = events.array
        }
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
                if attributes.removeValueForKey(key: key) != nil {
                    totalAttributeCount -= 1
                }
                return
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
        let alreadyEnded = internalStatusQueue.sync(flags: .barrier) { () -> Bool in
            if internalEnd {
                return true
            }

            internalEnd = true
            return false
        }

        if alreadyEnded {
            return
        }

        eventsSyncLock.withLockVoid {
            attributesSyncLock.withLockVoid {
                isRecording = false
            }
        }
        endTime = time
        OpenTelemetry.instance.contextProvider.removeContextForSpan(self)
        spanProcessor.onEnd(span: self)
    }

    public var description: String {
        return "RecordEventsReadableSpan{}"
    }

    internal func getTotalRecordedEvents() -> Int {
        eventsSyncLock.withLock {
            totalRecordedEvents
        }
    }

    /// For testing purposes
    internal func getDroppedLinksCount() -> Int {
        return totalRecordedLinks - links.count
    }
}

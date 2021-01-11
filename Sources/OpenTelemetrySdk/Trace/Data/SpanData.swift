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

/// representation of all data collected by the Span.
public struct SpanData: Equatable {
    /// The trace id for this span.
    public private(set) var traceId: TraceId

    /// The span id for this span.
    public private(set) var spanId: SpanId

    /// The trace flags for this span.
    public private(set) var traceFlags: TraceFlags = TraceFlags()

    /// The TraceState for this span.
    public private(set) var traceState: TraceState = TraceState()

    /// The parent SpanId. If the  Span is a root Span, the SpanId
    /// returned will be nil.
    public private(set) var parentSpanId: SpanId?

    /// The resource of this Span.
    public private(set) var resource: Resource = Resource()

    /// The instrumentation library specified when creating the tracer which produced this Span
    public private(set) var instrumentationLibraryInfo: InstrumentationLibraryInfo = InstrumentationLibraryInfo()

    /// The name of this Span.
    public private(set) var name: String

    /// The kind of this Span.
    public private(set) var kind: SpanKind

    /// The start epoch time in nanos of this Span.
    public private(set) var startTime: Date

    /// The attributes recorded for this Span.
    public private(set) var attributes = [String: AttributeValue]()

    /// The timed events recorded for this Span.
    public private(set) var events = [Event]()

    /// The links recorded for this Span.
    public private(set) var links = [Link]()

    /// The Status.
    public private(set) var status: Status = .unset

    /// The end epoch time in nanos of this Span
    public private(set) var endTime: Date

    /// True if the parent is on a different process, false if this is a root span.
    public private(set) var hasRemoteParent: Bool = false

    /// True if the span has already been ended, false if not.
    public private(set) var hasEnded: Bool = false

    /// The total number of {@link TimedEvent} events that were recorded on this span. This
    /// number may be larger than the number of events that are attached to this span, if the total
    /// number recorded was greater than the configured maximum value. See TraceConfig.maxNumberOfEvents
    public private(set) var totalRecordedEvents: Int = 0

    /// The total number of  links that were recorded on this span. This number
    /// may be larger than the number of links that are attached to this span, if the total number
    /// recorded was greater than the configured maximum value. See TraceConfig.maxNumberOfLinks
    public private(set) var totalRecordedLinks: Int = 0

    /// The total number of attributes that were recorded on this span. This number may be larger than
    /// the number of attributes that are attached to this span, if the total number recorded was
    /// greater than the configured maximum value. See TraceConfig.maxNumberOfAttributes
    public private(set) var totalAttributeCount: Int = 0

    public static func == (lhs: SpanData, rhs: SpanData) -> Bool {
        return lhs.traceId == rhs.traceId &&
            lhs.spanId == rhs.spanId &&
            lhs.traceFlags == rhs.traceFlags &&
            lhs.traceState == rhs.traceState &&
            lhs.parentSpanId == rhs.parentSpanId &&
            lhs.name == rhs.name &&
            lhs.kind == rhs.kind &&
            lhs.status == rhs.status &&
            lhs.endTime == rhs.endTime &&
            lhs.startTime == rhs.startTime &&
            lhs.hasRemoteParent == rhs.hasRemoteParent &&
            lhs.resource == rhs.resource &&
            lhs.attributes == rhs.attributes &&
            lhs.events == rhs.events &&
            lhs.links == rhs.links &&
            lhs.hasEnded == rhs.hasEnded &&
            lhs.totalRecordedEvents == rhs.totalRecordedEvents &&
            lhs.totalRecordedLinks == rhs.totalRecordedLinks &&
            lhs.totalAttributeCount == rhs.totalAttributeCount
    }

    @discardableResult public mutating func settingName(_ name: String) -> SpanData {
        self.name = name
        return self
    }

    @discardableResult public mutating func settingTraceId(_ traceId: TraceId) -> SpanData {
        self.traceId = traceId
        return self
    }

    @discardableResult public mutating func settingSpanId(_ spanId: SpanId) -> SpanData {
        self.spanId = spanId
        return self
    }

    @discardableResult public mutating func settingTraceFlags(_ traceFlags: TraceFlags) -> SpanData {
        self.traceFlags = traceFlags
        return self
    }

    @discardableResult public mutating func settingTraceState(_ traceState: TraceState) -> SpanData {
        self.traceState = traceState
        return self
    }

    @discardableResult public mutating func settingAttributes(_ attributes: [String: AttributeValue]) -> SpanData {
        self.attributes = attributes
        return self
    }

    @discardableResult public mutating func settingStartTime(_ time: Date) -> SpanData {
        startTime = time
        return self
    }

    @discardableResult public mutating func settingEndTime(_ time: Date) -> SpanData {
        endTime = time
        return self
    }

    @discardableResult public mutating func settingKind(_ kind: SpanKind) -> SpanData {
        self.kind = kind
        return self
    }

    @discardableResult public mutating func settingLinks(_ links: [Link]) -> SpanData {
        self.links = links
        return self
    }

    @discardableResult public mutating func settingParentSpanId(_ parentSpanId: SpanId) -> SpanData {
        self.parentSpanId = parentSpanId
        return self
    }

    @discardableResult public mutating func settingResource(_ resource: Resource) -> SpanData {
        self.resource = resource
        return self
    }

    @discardableResult public mutating func settingStatus(_ status: Status) -> SpanData {
        self.status = status
        return self
    }

    @discardableResult public mutating func settingEvents(_ events: [Event]) -> SpanData {
        self.events = events
        return self
    }

    @discardableResult public mutating func settingHasRemoteParent(_ hasRemoteParent: Bool) -> SpanData {
        self.hasRemoteParent = hasRemoteParent
        return self
    }

    @discardableResult public mutating func settingHasEnded(_ hasEnded: Bool) -> SpanData {
        self.hasEnded = hasEnded
        return self
    }

    @discardableResult public mutating func settingTotalRecordedEvents(_ totalRecordedEvents: Int) -> SpanData {
        self.totalRecordedEvents = totalRecordedEvents
        return self
    }

    @discardableResult public mutating func settingTotalRecordedLinks(_ totalRecordedLinks: Int) -> SpanData {
        self.totalRecordedLinks = totalRecordedLinks
        return self
    }

    @discardableResult public mutating func settingTotalAttributeCount(_ totalAttributeCount: Int) -> SpanData {
        self.totalAttributeCount = totalAttributeCount
        return self
    }
}

public extension SpanData {
    /// Timed event.
    struct Event: Equatable {
        public private(set) var timestamp: Date
        public private(set) var name: String
        public private(set) var attributes: [String: AttributeValue]

        /// Creates an Event with the given time, name and empty attributes.
        /// - Parameters:
        ///   - nanotime: epoch time in nanos.
        ///   - name: the name of this Event.
        ///   - attributes: the attributes of this Event. Empty by default.
        public init(name: String, timestamp: Date, attributes: [String: AttributeValue]? = nil) {
            self.timestamp = timestamp
            self.name = name
            self.attributes = attributes ?? [String: AttributeValue]()
        }

        /// Creates an Event with the given time and event.
        /// - Parameters:
        ///   - nanotime: epoch time in nanos.
        ///   - event: the event.
        public init(timestamp: Date, event: Event) {
            self.init(name: event.name, timestamp: timestamp, attributes: event.attributes)
        }
    }
}

public extension SpanData {
    struct Link {
        public let context: SpanContext
        public let attributes: [String: AttributeValue]

        public init(context: SpanContext, attributes: [String: AttributeValue] = [String: AttributeValue]()) {
            self.context = context
            self.attributes = attributes
        }
    }
}

public func == (lhs: SpanData.Link, rhs: SpanData.Link) -> Bool {
    return lhs.context == rhs.context && lhs.attributes == rhs.attributes
}

public func == (lhs: [SpanData.Link], rhs: [SpanData.Link]) -> Bool {
    return lhs.elementsEqual(rhs) { $0.context == $1.context && $0.attributes == $1.attributes }
}

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
    public struct TimedEvent: Event, Equatable {
        public var epochNanos: Int
        public var name: String
        public var attributes: [String: AttributeValue]
    }

    public class Link: OpenTelemetryApi.Link {
        public var context: SpanContext
        public var attributes: [String: AttributeValue]

        init(context: SpanContext, attributes: [String: AttributeValue] = [String: AttributeValue]()) {
            self.context = context
            self.attributes = attributes
        }
    }

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
    public private(set) var parentSpanId: SpanId? = SpanId.invalid

    /// The resource of this Span.
    public private(set) var resource: Resource = Resource()

    /// The instrumentation library specified when creating the tracer which produced this Span
    public private(set) var instrumentationLibraryInfo: InstrumentationLibraryInfo = InstrumentationLibraryInfo()

    /// The name of this Span.
    public private(set) var name: String

    /// The kind of this Span.
    public private(set) var kind: SpanKind

    /// The start epoch timestamp in nanos of this Span.
    public private(set) var startEpochNanos: Int

    /// The attributes recorded for this Span.
    public private(set) var attributes = [String: AttributeValue]()

    /// The timed events recorded for this Span.
    public private(set) var timedEvents = [TimedEvent]()

    /// The links recorded for this Span.
    public private(set) var links = [Link]()

    /// The Status.
    public private(set) var status: Status?

    /// The end epoch timestamp in nanos of this Span
    public private(set) var endEpochNanos: Int

    /// True if the parent is on a different process, false if this is a root span.
    public private(set) var hasRemoteParent: Bool = false

    /// True if the span has already been ended, false if not.
    public private(set) var hasEnded: Bool = false

    /// The total number of {@link SpanData.TimedEvent} events that were recorded on this span. This
    /// number may be larger than the number of events that are attached to this span, if the total
    /// number recorded was greater than the configured maximum value. See TraceConfig.maxNumberOfEvents
    public private(set) var totalRecordedEvents: Int = 0

    /// The total number of child spans that were created for this span.
    public private(set) var numberOfChildren: Int = 0

    /// The total number of  links that were recorded on this span. This number
    /// may be larger than the number of links that are attached to this span, if the total number
    /// recorded was greater than the configured maximum value. See TraceConfig.maxNumberOfLinks
    public private(set) var totalRecordedLinks: Int = 0

    public static func == (lhs: SpanData, rhs: SpanData) -> Bool {
        return lhs.traceId == rhs.traceId &&
            lhs.spanId == rhs.spanId &&
            lhs.traceFlags == rhs.traceFlags &&
            lhs.traceState == rhs.traceState &&
            lhs.parentSpanId == rhs.parentSpanId &&
            lhs.name == rhs.name &&
            lhs.kind == rhs.kind &&
            lhs.status == rhs.status &&
            lhs.endEpochNanos == rhs.endEpochNanos &&
            lhs.startEpochNanos == rhs.startEpochNanos &&
            lhs.hasRemoteParent == rhs.hasRemoteParent &&
            lhs.resource == rhs.resource &&
            lhs.attributes == rhs.attributes &&
            lhs.timedEvents == rhs.timedEvents &&
            lhs.links == rhs.links &&
            lhs.hasEnded == rhs.hasEnded &&
            lhs.totalRecordedEvents == rhs.totalRecordedEvents &&
            lhs.numberOfChildren == rhs.numberOfChildren &&
            lhs.totalRecordedLinks == rhs.totalRecordedLinks
    }

    public mutating func settingName(_ name: String) -> SpanData {
        self.name = name
        return self
    }

    public mutating func settingTraceId(_ traceId: TraceId) -> SpanData {
        self.traceId = traceId
        return self
    }

    public mutating func settingSpanId(_ spanId: SpanId) -> SpanData {
        self.spanId = spanId
        return self
    }

    public mutating func settingTraceFlags(_ traceFlags: TraceFlags) -> SpanData {
        self.traceFlags = traceFlags
        return self
    }

    public mutating func settingTraceState(_ traceState: TraceState) -> SpanData {
        self.traceState = traceState
        return self
    }

    public mutating func settingAttributes(_ attributes: [String: AttributeValue]) -> SpanData {
        self.attributes = attributes
        return self
    }

    public mutating func settingStartEpochNanos(_ nanos: Int) -> SpanData {
        startEpochNanos = nanos
        return self
    }

    public mutating func settingEndEpochNanos(_ nanos: Int) -> SpanData {
        endEpochNanos = nanos
        return self
    }

    public mutating func settingKind(_ kind: SpanKind) -> SpanData {
        self.kind = kind
        return self
    }

    public mutating func settingLinks(_ links: [Link]) -> SpanData {
        self.links = links
        return self
    }

    public mutating func settingParentSpanId(_ parentSpanId: SpanId) -> SpanData {
        self.parentSpanId = parentSpanId
        return self
    }

    public mutating func settingResource(_ resource: Resource) -> SpanData {
        self.resource = resource
        return self
    }

    public mutating func settingStatus(_ status: Status) -> SpanData {
        self.status = status
        return self
    }

    public mutating func settingTimedEvents(_ timedEvents: [TimedEvent]) -> SpanData {
        self.timedEvents = timedEvents
        return self
    }

    public mutating func settingHasRemoteParent(_ hasRemoteParent: Bool) -> SpanData {
        self.hasRemoteParent = hasRemoteParent
        return self
    }

    public mutating func settingHasEnded(_ hasEnded: Bool) -> SpanData {
        self.hasEnded = hasEnded
        return self
    }

    public mutating func settingTotalRecordedEvents(_ totalRecordedEvents: Int) -> SpanData {
        self.totalRecordedEvents = totalRecordedEvents
        return self
    }

    public mutating func settingNumberOfChildren(_ numberOfChildren: Int) -> SpanData {
        self.numberOfChildren = numberOfChildren
        return self
    }

    public mutating func settingTotalRecordedLinks(_ totalRecordedLinks: Int) -> SpanData {
        self.totalRecordedLinks = totalRecordedLinks
        return self
    }
}

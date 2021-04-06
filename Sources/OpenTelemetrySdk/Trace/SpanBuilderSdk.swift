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

/// SpanBuilderSdk is SDK implementation of SpanBuilder.
class SpanBuilderSdk: SpanBuilder {
    private enum ParentType {
        case currentSpan
        case explicitParent
        case explicitRemoteParent
        case noParent
    }

    static let traceOptionsSampled = TraceFlags().settingIsSampled(true)
    static let traceOptionsNotSampled = TraceFlags().settingIsSampled(false)

    private var spanName: String
    private var instrumentationLibraryInfo: InstrumentationLibraryInfo
    private var tracerSharedState: TracerSharedState
    private var spanLimits: SpanLimits

    private var parent: Span?
    private var remoteParent: SpanContext?
    private var spanKind = SpanKind.internal
    private var attributes: AttributesDictionary
    private var links = [SpanData.Link]()
    private var totalNumberOfLinksAdded: Int = 0
    private var parentType: ParentType = .currentSpan

    private var startTime = Date()

    init(spanName: String,
         instrumentationLibraryInfo: InstrumentationLibraryInfo,
         tracerSharedState: TracerSharedState,
         spanLimits: SpanLimits)
    {
        self.spanName = spanName
        self.instrumentationLibraryInfo = instrumentationLibraryInfo
        self.tracerSharedState = tracerSharedState
        self.spanLimits = spanLimits
        attributes = AttributesDictionary(capacity: spanLimits.attributeCountLimit)
    }

    @discardableResult func setParent(_ parent: Span) -> Self {
        self.parent = parent
        remoteParent = nil
        parentType = .explicitParent
        return self
    }

    @discardableResult func setParent(_ parent: SpanContext) -> Self {
        remoteParent = parent
        self.parent = nil
        parentType = .explicitRemoteParent
        return self
    }

    @discardableResult func setNoParent() -> Self {
        parentType = .noParent
        remoteParent = nil
        parent = nil
        return self
    }

    @discardableResult func addLink(spanContext: SpanContext) -> Self {
        return addLink(SpanData.Link(context: spanContext))
    }

    @discardableResult func addLink(spanContext: SpanContext, attributes: [String: AttributeValue]) -> Self {
        return addLink(SpanData.Link(context: spanContext, attributes: attributes))
    }

    @discardableResult func addLink(_ link: SpanData.Link) -> Self {
        totalNumberOfLinksAdded += 1
        if links.count >= spanLimits.linkCountLimit {
            return self
        }
        links.append(link)
        return self
    }

    @discardableResult func setAttribute(key: String, value: AttributeValue) -> Self {
        attributes.updateValue(value: value, forKey: key)
        return self
    }

    @discardableResult func setSpanKind(spanKind: SpanKind) -> Self {
        self.spanKind = spanKind
        return self
    }

    @discardableResult func setStartTime(time: Date) -> Self {
        startTime = time
        return self
    }

    func startSpan() -> Span {
        var parentContext = getParentContext(parentType: parentType, explicitParent: parent, remoteParent: remoteParent)
        let traceId: TraceId
        let spanId = tracerSharedState.idGenerator.generateSpanId()
        var traceState = TraceState()

        if parentContext?.isValid ?? false {
            traceId = parentContext!.traceId
            traceState = parentContext!.traceState
        } else {
            traceId = tracerSharedState.idGenerator.generateTraceId()
            parentContext = nil
        }

        let samplingDecision = tracerSharedState.sampler.shouldSample(parentContext: parentContext,
                                                                      traceId: traceId,
                                                                      name: spanName,
                                                                      kind: spanKind,
                                                                      attributes: attributes.attributes,
                                                                      parentLinks: links)

        let spanContext = SpanContext.create(traceId: traceId,
                                             spanId: spanId,
                                             traceFlags: TraceFlags().settingIsSampled(samplingDecision.isSampled),
                                             traceState: traceState)

        if !samplingDecision.isSampled {
            return DefaultTracer.instance.spanBuilder(spanName: spanName).startSpan()
        }

        attributes.updateValues(attributes: samplingDecision.attributes)

        return RecordEventsReadableSpan.startSpan(context: spanContext,
                                                  name: spanName,
                                                  instrumentationLibraryInfo: instrumentationLibraryInfo,
                                                  kind: spanKind,
                                                  parentContext: parentContext,
                                                  hasRemoteParent: parentContext?.isRemote ?? false,
                                                  spanLimits: spanLimits,
                                                  spanProcessor: tracerSharedState.activeSpanProcessor,
                                                  clock: SpanBuilderSdk.getClock(parent: SpanBuilderSdk.getParentSpan(parentType: parentType, explicitParent: parent), clock: tracerSharedState.clock),
                                                  resource: tracerSharedState.resource,
                                                  attributes: attributes,
                                                  links: links,
                                                  totalRecordedLinks: totalNumberOfLinksAdded,
                                                  startTime: startTime)
    }

    private static func getClock(parent: Span?, clock: Clock) -> Clock {
        if let parentRecordEventSpan = parent as? RecordEventsReadableSpan {
            return parentRecordEventSpan.clock
        } else {
            return MonotonicClock(clock: clock)
        }
    }

    private func getParentContext(parentType: ParentType, explicitParent: Span?, remoteParent: SpanContext?) -> SpanContext? {
        let currentSpan = OpenTelemetryContext.activeSpan
        switch parentType {
        case .noParent:
            return nil
        case .currentSpan:
            return currentSpan?.context
        case .explicitParent:
            return explicitParent?.context
        case .explicitRemoteParent:
            return remoteParent
        }
    }

    private static func getParentSpan(parentType: ParentType, explicitParent: Span?) -> Span? {
        switch parentType {
        case .currentSpan:
            return OpenTelemetryContext.activeSpan
        case .explicitParent:
            return explicitParent
        default:
            return nil
        }
    }
}

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
public class SpanBuilderSdk: SpanBuilder {
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
    private var spanProcessor: SpanProcessor
    private var traceConfig: TraceConfig
    private var resource: Resource
    private var idsGenerator: IdsGenerator
    private var clock: Clock

    private var parent: Span?
    private var remoteParent: SpanContext?
    private var spanKind = SpanKind.internal
    private var attributes: AttributesDictionary
    private var links = [SpanData.Link]()
    private var totalNumberOfLinksAdded: Int = 0
    private var parentType: ParentType = .currentSpan

    private var startTime: Date = Date()

    public init(spanName: String,
                instrumentationLibraryInfo: InstrumentationLibraryInfo,
                spanProcessor: SpanProcessor,
                traceConfig: TraceConfig,
                resource: Resource,
                idsGenerator: IdsGenerator,
                clock: Clock) {
        self.spanName = spanName
        self.instrumentationLibraryInfo = instrumentationLibraryInfo
        self.spanProcessor = spanProcessor
        self.traceConfig = traceConfig
        attributes = AttributesDictionary(capacity: traceConfig.maxNumberOfAttributes)
        self.resource = resource
        self.idsGenerator = idsGenerator
        self.clock = clock
    }

    @discardableResult public func setParent(_ parent: Span) -> Self {
        self.parent = parent
        remoteParent = nil
        parentType = .explicitParent
        return self
    }

    @discardableResult public func setParent(_ parent: SpanContext) -> Self {
        remoteParent = parent
        self.parent = nil
        parentType = .explicitRemoteParent
        return self
    }

    @discardableResult public func setNoParent() -> Self {
        parentType = .noParent
        remoteParent = nil
        parent = nil
        return self
    }

    @discardableResult public func addLink(spanContext: SpanContext) -> Self {
        return addLink(SpanData.Link(context: spanContext))
    }

    @discardableResult public func addLink(spanContext: SpanContext, attributes: [String: AttributeValue]) -> Self {
        return addLink(SpanData.Link(context: spanContext, attributes: attributes))
    }

    @discardableResult public func addLink(_ link: SpanData.Link) -> Self {
        totalNumberOfLinksAdded += 1
        if links.count >= traceConfig.maxNumberOfLinks {
            return self
        }
        links.append(link)
        return self
    }

    @discardableResult public func setAttribute(key: String, value: AttributeValue) -> Self {
        attributes.updateValue(value: value, forKey: key)
        return self
    }

    @discardableResult public func setSpanKind(spanKind: SpanKind) -> Self {
        self.spanKind = spanKind
        return self
    }

    @discardableResult public func setStartTime(time: Date) -> Self {
        startTime = time
        return self
    }

    public func startSpan() -> Span {
        var parentContext = getParentContext(parentType: parentType, explicitParent: parent, remoteParent: remoteParent)
        let traceId: TraceId
        let spanId = idsGenerator.generateSpanId()
        var traceState = TraceState()

        if parentContext?.isValid ?? false {
            traceId = parentContext!.traceId
            traceState = parentContext!.traceState
        } else {
            traceId = idsGenerator.generateTraceId()
            parentContext = nil
        }

        let samplingDecision = traceConfig.sampler.shouldSample(parentContext: parentContext,
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
            return DefaultSpan(context: spanContext, kind: spanKind)
        }

        attributes.updateValues(attributes: samplingDecision.attributes)

        return RecordEventsReadableSpan.startSpan(context: spanContext,
                                                  name: spanName,
                                                  instrumentationLibraryInfo: instrumentationLibraryInfo,
                                                  kind: spanKind,
                                                  parentContext: parentContext,
                                                  hasRemoteParent: parentContext?.isRemote ?? false,
                                                  traceConfig: traceConfig,
                                                  spanProcessor: spanProcessor,
                                                  clock: SpanBuilderSdk.getClock(parent: SpanBuilderSdk.getParentSpan(parentType: parentType, explicitParent: parent), clock: clock),
                                                  resource: resource,
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
        let currentSpan = ContextUtils.getCurrentSpan()
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
            return ContextUtils.getCurrentSpan()
        case .explicitParent:
            return explicitParent
        default:
            return nil
        }
    }
}

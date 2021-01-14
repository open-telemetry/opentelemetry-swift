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
import Opentracing

public class TracerShim: OTTracer, BaseShimProtocol {
    public static let OTReferenceChildOf = "child_of"
    public static let OTReferenceFollowsFrom = "follows_from"

    enum InjectError: Error {
        case injectError
        case extractError
    }

    var telemetryInfo: TelemetryInfo
    let propagation: Propagation

    init(telemetryInfo: TelemetryInfo) {
        self.telemetryInfo = telemetryInfo
        propagation = Propagation(telemetryInfo: telemetryInfo)
    }

    public func startSpan(_ operationName: String) -> OTSpan {
        return startSpan(operationName, tags: nil)
    }

    public func startSpan(_ operationName: String, tags: [AnyHashable: Any]?) -> OTSpan {
        return startSpan(operationName, childOf: nil, tags: tags)
    }

    public func startSpan(_ operationName: String, childOf parent: OTSpanContext?) -> OTSpan {
        return startSpan(operationName, childOf: parent, tags: nil)
    }

    public func startSpan(_ operationName: String, childOf parent: OTSpanContext?, tags: [AnyHashable: Any]?) -> OTSpan {
        return startSpan(operationName, childOf: parent, tags: tags, startTime: nil)
    }

    public func startSpan(_ operationName: String, childOf parent: OTSpanContext?, tags: [AnyHashable: Any]?, startTime: Date?) -> OTSpan {
        var baggage: Baggage?
        let builder = tracer.spanBuilder(spanName: operationName)
        if let parent = parent as? SpanContextShim {
            builder.setParent(parent.context)
            baggage = parent.baggage
        }

        if let tags = tags as? [String: NSObject] {
            let attributes = SpanShim.convertToAttributes(fields: tags)
            attributes.forEach {
                builder.setAttribute(key: $0.key, value: $0.value)
            }
        }

        if let startTime = startTime {
            builder.setStartTime(time: startTime)
        }

        let span = builder.startSpan()
        tracer.setActive(span)
        let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
        if baggage != nil, !(baggage! == telemetryInfo.emptyBaggage) {
            spanContextTable.create(spanShim: spanShim, distContext: baggage!)
        }
        return spanShim
    }

    public func startSpan(_ operationName: String, references: [Any]?, tags: [AnyHashable: Any]?, startTime: Date?) -> OTSpan {
        var parent: OTSpanContext?
        if references != nil {
            for object in references! {
                if let ref = object as? OTReference,
                    ref.type == TracerShim.OTReferenceChildOf || ref.type == TracerShim.OTReferenceFollowsFrom {
                    parent = ref.referencedContext
                }
            }
        }
        return startSpan(operationName, childOf: parent, tags: tags, startTime: nil)
    }

    public func inject(_ spanContext: OTSpanContext, format: String, carrier: Any) -> Bool {
        if let contextShim = spanContext as? SpanContextShim,
            let dict = carrier as? NSMutableDictionary,
            format == OTFormatTextMap || format == OTFormatBinary {
            propagation.injectTextFormat(contextShim: contextShim, carrier: dict)
            return true
        } else {
            return false
        }
    }

    public func extract(withFormat format: String, carrier: Any) -> OTSpanContext? {
        if format == OTFormatTextMap || format == OTFormatBinary,
            let carrier = carrier as? [String: String] {
            return propagation.extractTextFormat(carrier: carrier)
        } else {
            return nil
        }
    }

    public func inject(spanContext: OTSpanContext, format: String, carrier: Any) throws {
        if let contextShim = spanContext as? SpanContextShim,
            let dict = carrier as? NSMutableDictionary,
            format == OTFormatTextMap || format == OTFormatBinary {
            propagation.injectTextFormat(contextShim: contextShim, carrier: dict)
        } else {
            throw InjectError.injectError
        }
    }

    public func extractWithFormat(format: String, carrier: Any) throws -> OTSpanContext {
        if format == OTFormatTextMap || format == OTFormatBinary,
            let carrier = carrier as? [String: String],
            let context = propagation.extractTextFormat(carrier: carrier) {
            return context
        } else {
            throw InjectError.extractError
        }
    }
}

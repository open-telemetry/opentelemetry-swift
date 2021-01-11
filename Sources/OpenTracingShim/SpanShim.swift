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

public class SpanShim: OTSpan, BaseShimProtocol {
    static let defaultEventName = "log"

    static let OpenTracingErrorTag = "error"
    static let OpenTracingEventField = "event"

    public private(set) var span: Span
    var telemetryInfo: TelemetryInfo

    init(telemetryInfo: TelemetryInfo, span: Span) {
        self.telemetryInfo = telemetryInfo
        self.span = span
    }

    public func context() -> OTSpanContext {
        var contextShim = spanContextTable.get(spanShim: self)
        if contextShim == nil {
            contextShim = spanContextTable.create(spanShim: self)
        }
        return contextShim!
    }

    public func tracer() -> OTTracer {
        return TraceShim.instance.otTracer
    }

    public func setOperationName(_ operationName: String) {
        span.name = operationName
    }

    public func setTag(_ key: String, value: String) {
        if key == SpanShim.OpenTracingErrorTag {
            let error = Bool(value) ?? false
            span.status = error ? .error : .ok
        } else {
            span.setAttribute(key: key, value: value)
        }
    }

    public func setTag(_ key: String, numberValue value: NSNumber) {
        let numberType = CFNumberGetType(value)

        switch numberType {
        case .charType:
            span.setAttribute(key: key, value: value.boolValue)
        case .sInt8Type, .sInt16Type, .sInt32Type, .sInt64Type, .shortType, .intType, .longType, .longLongType, .cfIndexType, .nsIntegerType:
            span.setAttribute(key: key, value: value.intValue)
        case .float32Type, .float64Type, .floatType, .doubleType, .cgFloatType:
            span.setAttribute(key: key, value: value.doubleValue)
        @unknown default:
            span.setAttribute(key: key, value: value.doubleValue)
        }
    }

    public func setTag(_ key: String, boolValue value: Bool) {
        if key == SpanShim.OpenTracingErrorTag {
            span.status = value ? .error : .ok
        } else {
            span.setAttribute(key: key, value: value)
        }
    }

    public func log(_ fields: [String: NSObject]) {
        span.addEvent(name: SpanShim.getEventNameFrom(fields: fields), attributes: SpanShim.convertToAttributes(fields: fields))
    }

    public func log(_ fields: [String: NSObject], timestamp: Date?) {
        span.addEvent(name: SpanShim.getEventNameFrom(fields: fields), attributes: SpanShim.convertToAttributes(fields: fields), timestamp: timestamp ?? Date())
    }

    public func logEvent(_ eventName: String) {
        span.addEvent(name: eventName)
    }

    public func logEvent(_ eventName: String, payload: NSObject?) {
        if let object = payload {
            span.addEvent(name: eventName, attributes: SpanShim.convertToAttributes(fields: [eventName: object]))
        } else {
            span.addEvent(name: eventName)
        }
    }

    public func log(_ eventName: String, timestamp: Date?, payload: NSObject?) {
        if let object = payload {
            span.addEvent(name: eventName, attributes: SpanShim.convertToAttributes(fields: [eventName: object]), timestamp: timestamp ?? Date())
        } else {
            span.addEvent(name: eventName, timestamp: timestamp ?? Date())
        }
    }

    public func setBaggageItem(_ key: String, value: String) -> OTSpan {
        spanContextTable.setBaggageItem(spanShim: self, key: key, value: value)
        return self
    }

    public func getBaggageItem(_ key: String) -> String? {
        return spanContextTable.getBaggageItem(spanShim: self, key: key)
    }

    public func finish() {
        span.end()
    }

    public func finish(withTime finishTime: Date?) {
        if let finishTime = finishTime {
            span.end(time: finishTime)
        } else {
            span.end()
        }
    }

    static func getEventNameFrom(fields: [String: NSObject]) -> String {
        return fields[OpenTracingEventField]?.description ?? defaultEventName
    }

    static func convertToAttributes(fields: [String: NSObject]) -> [String: AttributeValue] {
        let attributes: [String: AttributeValue] = fields.mapValues { value in
            if (value as? NSString) != nil {
                return AttributeValue.string(value as! String)
            } else if (value as? NSNumber) != nil {
                let number = value as! NSNumber
                let numberType = CFNumberGetType(number)

                switch numberType {
                case .charType:
                    return AttributeValue.bool(number.boolValue)
                case .sInt8Type, .sInt16Type, .sInt32Type, .sInt64Type, .shortType, .intType, .longType, .longLongType, .cfIndexType, .nsIntegerType:
                    return AttributeValue.int(number.intValue)
                case .float32Type, .float64Type, .floatType, .doubleType, .cgFloatType:
                    return AttributeValue.double(number.doubleValue)
                @unknown default:
                    return AttributeValue.double(number.doubleValue)
                }
            } else {
                return AttributeValue.string("")
            }
        }
        return attributes
    }
}

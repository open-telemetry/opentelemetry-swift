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

class LoggingSpan: Span {
    var name: String
    var kind: SpanKind
    var context: SpanContext = SpanContext.invalid
    var isRecording: Bool = true
    var status: Status = .unset
    var scope: Scope?


    public init(name: String, kind: SpanKind) {
        self.name = name
        self.kind = kind
    }

    public var description: String {
        return name
    }

    public func updateName(name: String) {
        Logger.log("Span.updateName(\(name))")
        self.name = name
    }

    public func setAttribute(key: String, value: String) {
        Logger.log("Span.setAttribute(key: \(key), value: \(value))")
    }

    public func setAttribute(key: String, value: Int) {
        Logger.log("Span.setAttribute(key: \(key), value: \(value))")
    }

    public func setAttribute(key: String, value: Double) {
        Logger.log("Span.setAttribute(key: \(key), value: \(value))")
    }

    public func setAttribute(key: String, value: Bool) {
        Logger.log("Span.setAttribute(key: \(key), value: \(value))")
    }

    public func setAttribute(key: String, value: AttributeValue?) {
        Logger.log("Span.setAttribute(key: \(key), value: \(String(describing: value)))")
    }

    public func setAttribute(keyValuePair: (String, AttributeValue)) {
        Logger.log("Span.SetAttributes(keyValue: \(keyValuePair))")
        setAttribute(key: keyValuePair.0, value: keyValuePair.1)
    }

    public func addEvent(name: String) {
        Logger.log("Span.addEvent(\(name))")
    }

    public func addEvent(name: String, timestamp: Date) {
        Logger.log("Span.addEvent(\(name) timestamp:\(timestamp))")
    }

    public func addEvent(name: String, attributes: [String: AttributeValue]) {
        Logger.log("Span.addEvent(\(name), attributes:\(attributes) )")
    }

    public func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {
        Logger.log("Span.addEvent(\(name), attributes:\(attributes), timestamp:\(timestamp))")
    }

    public func end() {
        Logger.log("Span.End, Name: \(name)")
    }

    public func end(time: Date) {
        Logger.log("Span.End, Name: \(name), time:\(time)) }")
    }
}

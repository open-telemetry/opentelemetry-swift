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

/// DefaultContextPropagators  is the default, built-in implementation of ContextPropagators
/// All the registered propagators are stored internally as a simple list, and are invoked
/// synchronically upon injection and extraction.
public struct DefaultContextPropagators: ContextPropagators {
    public var textMapPropagator: TextMapPropagator
    public var textMapBaggagePropagator: TextMapBaggagePropagator

    public init() {
        textMapPropagator = NoopTextMapPropagator()
        textMapBaggagePropagator = NoopBaggagePropagator()
    }

    public init(textPropagators: [TextMapPropagator], baggagePropagator: TextMapBaggagePropagator) {
        textMapPropagator = MultiTextMapPropagator(textPropagators: textPropagators)
        textMapBaggagePropagator = baggagePropagator
    }

    public mutating func addTextMapPropagator(textFormat: TextMapPropagator) {
        if textMapPropagator is NoopTextMapPropagator {
            textMapPropagator = textFormat
        } else if var multiFormat = textMapPropagator as? MultiTextMapPropagator {
            multiFormat.textPropagators.append(textFormat)
        } else {
            textMapPropagator = MultiTextMapPropagator(textPropagators: [textMapPropagator])
            if var multiFormat = textMapPropagator as? MultiTextMapPropagator {
                multiFormat.textPropagators.append(textFormat)
            }
        }
    }

    struct MultiTextMapPropagator: TextMapPropagator {
        public var fields: Set<String>
        var textPropagators = [TextMapPropagator]()

        init(textPropagators: [TextMapPropagator]) {
            self.textPropagators = textPropagators
            fields = MultiTextMapPropagator.getAllFields(textPropagators: self.textPropagators)
        }

        private static func getAllFields(textPropagators: [TextMapPropagator]) -> Set<String> {
            var fields = Set<String>()
            textPropagators.forEach {
                fields.formUnion($0.fields)
            }
            return fields
        }

        public func inject<S>(spanContext: SpanContext, carrier: inout [String: String], setter: S) where S: Setter {
            textPropagators.forEach {
                $0.inject(spanContext: spanContext, carrier: &carrier, setter: setter)
            }
        }

        public func extract<G>(carrier: [String: String], getter: G) -> SpanContext? where G: Getter {
            var spanContext: SpanContext?
            textPropagators.forEach {
                spanContext = $0.extract(carrier: carrier, getter: getter)
            }
            return spanContext
        }
    }


    struct NoopTextMapPropagator: TextMapPropagator {
        public var fields = Set<String>()

        public func inject<S>(spanContext: SpanContext, carrier: inout [String: String], setter: S) where S: Setter {}

        public func extract<G>(carrier: [String: String], getter: G) -> SpanContext? where G: Getter {
            return nil
        }
    }

    struct NoopBaggagePropagator: TextMapBaggagePropagator {

        public var fields = Set<String>()

        public func inject<S>(baggage: Baggage, carrier: inout [String: String], setter: S) where S: Setter {}

        public func extract<G>(carrier: [String: String], getter: G) -> Baggage? where G: Getter {
            return nil
        }
    }
}

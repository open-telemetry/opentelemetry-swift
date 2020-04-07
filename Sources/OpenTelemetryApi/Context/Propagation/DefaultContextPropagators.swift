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
    public var httpTextFormat: HTTPTextFormattable

    init() {
        httpTextFormat = NoopHttpTextFormat()
    }

    init(textPropagators: [HTTPTextFormattable]) {
        httpTextFormat = MultiHttpTextFormat(textPropagators: textPropagators)
    }

    public mutating func addHttpTextFormat(textFormat: HTTPTextFormattable) {
        if httpTextFormat is NoopHttpTextFormat {
            httpTextFormat = textFormat
        } else if var multiFormat = httpTextFormat as? MultiHttpTextFormat {
            multiFormat.textPropagators.append(textFormat)
        } else {
            httpTextFormat = MultiHttpTextFormat(textPropagators: [httpTextFormat])
            if var multiFormat = httpTextFormat as? MultiHttpTextFormat {
                multiFormat.textPropagators.append(textFormat)
            }
        }
    }

    struct MultiHttpTextFormat: HTTPTextFormattable {
        public var fields: Set<String>
        var textPropagators = [HTTPTextFormattable]()

        init(textPropagators: [HTTPTextFormattable]) {
            self.textPropagators = textPropagators
            fields = MultiHttpTextFormat.getAllFields(textPropagators: self.textPropagators)
        }

        private static func getAllFields(textPropagators: [HTTPTextFormattable]) -> Set<String> {
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

        public func extract<G>(spanContext: SpanContext?, carrier: [String: String], getter: G) -> SpanContext? where G: Getter {
            textPropagators.forEach {
                $0.extract(spanContext: spanContext, carrier: carrier, getter: getter)
            }
            return spanContext
        }
    }

    struct NoopHttpTextFormat: HTTPTextFormattable {
        public var fields = Set<String>()

        public func inject<S>(spanContext: SpanContext, carrier: inout [String: String], setter: S) where S: Setter {
        }

        public func extract<G>(spanContext: SpanContext?, carrier: [String: String], getter: G) -> SpanContext? where G: Getter {
            return spanContext
        }
    }
}

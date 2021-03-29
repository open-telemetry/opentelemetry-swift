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

// Model class
struct OtlpSpan: Codable {
    var resourceSpans: [ResourceSpan]?
    
    struct ResourceSpan: Codable {
        var resource: Resource?
        var instrumentationLibrarySpans: [InstrumentationLibrarySpan]?
        
        struct Resource: Codable {
            var attributes: [Attribute]?
        }
        
        struct InstrumentationLibrarySpan: Codable {
            var instrumentationLibrary: InstrumentationLibrary?
            var spans: [Span]?
            
            struct InstrumentationLibrary: Codable {
                var name: String?
                var version: String?
            }
            
            struct Span: Codable {
                var traceId: String?
                var spanId: String?
                var name: String?
                var kind: String?
                var startTimeUnixNano: String?
                var endTimeUnixNano: String?
                var attributes: [Attribute]?
                var status: SpanStatus?
                
                struct SpanStatus: Codable {
                    var status: String?
                }
            }
        }
    }
}

public struct Attribute: Codable {
    var key: String?
    var value: Value?
    
    public struct Value: Codable {
        var stringValue: String?
        var boolValue: Bool?
    }
}

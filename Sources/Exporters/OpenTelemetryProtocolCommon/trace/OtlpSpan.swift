/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

// Model class
public struct OtlpSpan: Codable {
    var resourceSpans: [ResourceSpan]?
    
    struct ResourceSpan: Codable {
        var resource: Resource?
        var scopeSpans: [scopeSpan]?
        
        struct Resource: Codable {
            var attributes: [Attribute]?
        }
        
        struct scopeSpan: Codable {
            var instrumentationScope: InstrumentationScope?
            var spans: [Span]?
            
            struct InstrumentationScope: Codable {
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

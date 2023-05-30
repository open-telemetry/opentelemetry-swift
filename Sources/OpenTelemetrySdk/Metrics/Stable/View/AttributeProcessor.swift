//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public protocol AttributeProcessorProtocol  {
    func process(incoming : [String: AttributeValue]) -> [String: AttributeValue]
}
public class AttributeProcessor : AttributeProcessorProtocol {
    
    public func then(other : AttributeProcessor) -> AttributeProcessor {
        if type(of: other) == NoopAttributeProcessor.self {
            return self
        }
        if type(of: self) == NoopAttributeProcessor.self {
            return other
        }
        
        if type(of: other) == JoinedAttributeProcessor.self {
            return (other as! JoinedAttributeProcessor).prepend(processor:self)
        }
        return JoinedAttributeProcessor([self, other])
    }
    
    
    public func process(incoming: [String : AttributeValue]) -> [String : AttributeValue] {
        return incoming
    }
    
    public static func filterByKeyName( nameFilter : @escaping (String) -> Bool) -> AttributeProcessor {
        return SimpleAttributeProcessor { attributes in
            attributes.filter { key, value in
                nameFilter(key)
            }
        }
    }
    
    public static func append(attributes: [String : AttributeValue]) -> AttributeProcessor {
        SimpleAttributeProcessor { incoming in
            incoming.merging(attributes) { a, b in
                b
            }
        }
    }
    
    
}

internal class SimpleAttributeProcessor : AttributeProcessor {
    
    let attributeProcessor : ([String: AttributeValue]) -> [String:AttributeValue]
    
    init(attributeProcessor : @escaping ([String: AttributeValue]) -> [String: AttributeValue]) {
        self.attributeProcessor = attributeProcessor
        
    }
    
    override func process(incoming: [String : OpenTelemetryApi.AttributeValue]) -> [String : OpenTelemetryApi.AttributeValue] {
        return attributeProcessor(incoming)
    }
    
    
}


public class JoinedAttributeProcessor : AttributeProcessor {
    
    override public func process(incoming: [String : OpenTelemetryApi.AttributeValue]) -> [String : OpenTelemetryApi.AttributeValue] {
        var result = incoming
        for processor in processors {
            result = processor.process(incoming: result)
        }
        return result
    }
    
    override public func then(other: AttributeProcessor) -> AttributeProcessor {
        var newList = processors
        if let otherJoined = other as? JoinedAttributeProcessor {
            newList.append(contentsOf: otherJoined.processors)
        } else {
            newList.append(other)
        }
        return JoinedAttributeProcessor(newList)
    }
    
    public func prepend(processor: AttributeProcessor) -> AttributeProcessor {
        var newProcessors = [processor]
        newProcessors.append(contentsOf: processors)
        return JoinedAttributeProcessor(newProcessors)
    }
    
    var processors = [AttributeProcessor]()
    init(_ processors : [AttributeProcessor]) {
        self.processors = processors
    }
    
}

public class NoopAttributeProcessor : AttributeProcessor {
    static let noop = NoopAttributeProcessor()
    private override init() {}
    override public func process(incoming: [String : AttributeValue]) -> [String : AttributeValue] {
        return incoming
    }
}

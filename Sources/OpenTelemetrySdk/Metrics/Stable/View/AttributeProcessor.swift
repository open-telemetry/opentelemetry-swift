//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public protocol AttributeProcessor {
  func process(incoming: [String: AttributeValue]) -> [String: AttributeValue]
}

public extension AttributeProcessor {
  func then(other: AttributeProcessor) -> AttributeProcessor {
    if type(of: other) == NoopAttributeProcessor.self {
      return self
    }
    if type(of: self) == NoopAttributeProcessor.self {
      return other
    }

    if let joined = self as? JoinedAttributeProcessor {
      return joined.append(processor: other)
    }
    if let joined = other as? JoinedAttributeProcessor {
      return joined.prepend(processor: self)
    }

    return JoinedAttributeProcessor([self, other])
  }
}

public class SimpleAttributeProcessor: AttributeProcessor {
  let attributeProcessor: ([String: AttributeValue]) -> [String: AttributeValue]

  init(attributeProcessor: @escaping ([String: AttributeValue]) -> [String: AttributeValue]) {
    self.attributeProcessor = attributeProcessor
  }

  public func process(incoming: [String: AttributeValue]) -> [String: AttributeValue] {
    return attributeProcessor(incoming)
  }

  static func filterByKeyName(nameFilter: @escaping (String) -> Bool) -> AttributeProcessor {
    return SimpleAttributeProcessor { attributes in
      attributes.filter { key, _ in
        nameFilter(key)
      }
    }
  }

  static func append(attributes: [String: AttributeValue]) -> AttributeProcessor {
    SimpleAttributeProcessor { incoming in
      incoming.merging(attributes) { _, b in
        b
      }
    }
  }
}

public class JoinedAttributeProcessor: AttributeProcessor {
  public func process(incoming: [String: AttributeValue]) -> [String: AttributeValue] {
    var result = incoming
    for processor in processors {
      result = processor.process(incoming: result)
    }
    return result
  }

  public func append(processor: AttributeProcessor) -> JoinedAttributeProcessor {
    var newList = processors
    if let joinedProcessor = processor as? JoinedAttributeProcessor {
      newList.append(contentsOf: joinedProcessor.processors)
    } else {
      newList.append(processor)
    }
    return JoinedAttributeProcessor(newList)
  }

  public func prepend(processor: AttributeProcessor) -> JoinedAttributeProcessor {
    var newProcessors = [processor]
    newProcessors.append(contentsOf: processors)
    return JoinedAttributeProcessor(newProcessors)
  }

  var processors = [AttributeProcessor]()
  init(_ processors: [AttributeProcessor]) {
    self.processors = processors
  }
}

public class NoopAttributeProcessor: AttributeProcessor {
  static let noop = NoopAttributeProcessor()
  private init() {}
  public func process(incoming: [String: AttributeValue]) -> [String: AttributeValue] {
    return incoming
  }
}

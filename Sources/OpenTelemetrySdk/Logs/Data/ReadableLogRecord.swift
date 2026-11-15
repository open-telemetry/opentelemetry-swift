/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public struct ReadableLogRecord: Codable, Sendable {
  public init(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, timestamp: Date, observedTimestamp: Date? = nil, spanContext: SpanContext? = nil, severity: Severity? = nil, body: AttributeValue? = nil, attributes: [String: AttributeValue], eventName: String? = nil) {
    self.resource = resource
    self.instrumentationScopeInfo = instrumentationScopeInfo
    self.timestamp = timestamp
    self.observedTimestamp = observedTimestamp
    self.spanContext = spanContext
    self.severity = severity
    self.body = body
    self.attributes = attributes
    self.eventName = eventName
  }

  public private(set) var resource: Resource
  public private(set) var instrumentationScopeInfo: InstrumentationScopeInfo
  public private(set) var timestamp: Date
  public private(set) var observedTimestamp: Date?
  public private(set) var spanContext: SpanContext?
  public private(set) var severity: Severity?
  public private(set) var body: AttributeValue?
  public private(set) var attributes: [String: AttributeValue]
  public private(set) var eventName: String?

  /// Puts a new attribute to the log record.
  /// - Parameters:
  ///   - key: Key of the attribute.
  ///   - value: Attribute value.
  public mutating func setAttribute(key: String, value: AttributeValue?) {
    if let value = value {
      attributes[key] = value
    } else {
      attributes.removeValue(forKey: key)
    }
  }
}

public extension ReadableLogRecord {
  mutating func setAttribute(key: String, value: String) {
    setAttribute(key: key, value: AttributeValue.string(value))
  }

  mutating func setAttribute(key: String, value: Int) {
    setAttribute(key: key, value: AttributeValue.int(value))
  }

  mutating func setAttribute(key: String, value: Double) {
    setAttribute(key: key, value: AttributeValue.double(value))
  }

  mutating func setAttribute(key: String, value: Bool) {
    setAttribute(key: key, value: AttributeValue.bool(value))
  }

  mutating func setAttribute(key: any RawRepresentable<String>, value: String) {
    setAttribute(key: key.rawValue, value: AttributeValue.string(value))
  }

  mutating func setAttribute(key: any RawRepresentable<String>, value: Int) {
    setAttribute(key: key.rawValue, value: AttributeValue.int(value))
  }

  mutating func setAttribute(key: any RawRepresentable<String>, value: Double) {
    setAttribute(key: key.rawValue, value: AttributeValue.double(value))
  }

  mutating func setAttribute(key: any RawRepresentable<String>, value: Bool) {
    setAttribute(key: key.rawValue, value: AttributeValue.bool(value))
  }
}

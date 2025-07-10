//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class ExemplarData: Equatable {
  init(epochNanos: UInt64, filteredAttributes: [String: AttributeValue], spanContext: SpanContext? = nil) {
    self.filteredAttributes = filteredAttributes
    self.epochNanos = epochNanos
    self.spanContext = spanContext
  }

  public var filteredAttributes: [String: AttributeValue]
  public var epochNanos: UInt64
  public var spanContext: OpenTelemetryApi.SpanContext?

  public func isEqual(to other: ExemplarData) -> Bool {
    return epochNanos == other.epochNanos
      && filteredAttributes == other.filteredAttributes
      && spanContext == other.spanContext
  }

  public static func == (lhs: ExemplarData, rhs: ExemplarData) -> Bool {
    return type(of: lhs) == type(of: rhs) && lhs.isEqual(to: rhs)
  }
}

public final class DoubleExemplarData: ExemplarData, Codable {
  public var value: Double

  enum CodingKeys: String, CodingKey {
    case value
    case filteredAttributes
    case epochNanos
    case spanContext
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    value = try values.decode(Double.self, forKey: .value)
    let filteredAttributes = try values.decode([String: AttributeValue].self, forKey: .filteredAttributes)
    let epochNanos = try values.decode(UInt64.self, forKey: .epochNanos)
    let spanContext: SpanContext? = try values.decodeIfPresent(SpanContext.self, forKey: .spanContext)
    super.init(
      epochNanos: epochNanos,
      filteredAttributes: filteredAttributes,
      spanContext: spanContext
    )
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(value, forKey: .value)
    try container.encode(filteredAttributes, forKey: .filteredAttributes)
    try container.encode(epochNanos, forKey: .epochNanos)
    try container.encode(spanContext, forKey: .spanContext)
  }

  init(value: Double, epochNanos: UInt64, filteredAttributes: [String: AttributeValue], spanContext: SpanContext? = nil) {
    self.value = value
    super.init(epochNanos: epochNanos, filteredAttributes: filteredAttributes, spanContext: spanContext)
  }

  override public func isEqual(to other: ExemplarData) -> Bool {
    return value == (other as! DoubleExemplarData).value &&
      super.isEqual(to: other)
  }
}

public final class LongExemplarData: ExemplarData, Codable {
  public var value: Int

  enum CodingKeys: String, CodingKey {
    case value
    case filteredAttributes
    case epochNanos
    case spanContext
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    value = try values.decode(Int.self, forKey: .value)
    let filteredAttributes = try values.decode([String: AttributeValue].self, forKey: .filteredAttributes)
    let epochNanos = try values.decode(UInt64.self, forKey: .epochNanos)
    let spanContext: SpanContext? = try values.decodeIfPresent(SpanContext.self, forKey: .spanContext)
    super.init(
      epochNanos: epochNanos,
      filteredAttributes: filteredAttributes,
      spanContext: spanContext
    )
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(value, forKey: .value)
    try container.encode(filteredAttributes, forKey: .filteredAttributes)
    try container.encode(epochNanos, forKey: .epochNanos)
    try container.encode(spanContext, forKey: .spanContext)
  }

  init(value: Int, epochNanos: UInt64, filteredAttributes: [String: AttributeValue], spanContext: SpanContext? = nil) {
    self.value = value
    super.init(epochNanos: epochNanos, filteredAttributes: filteredAttributes, spanContext: spanContext)
  }

  override public func isEqual(to other: ExemplarData) -> Bool {
    return value == (other as! LongExemplarData).value &&
      super.isEqual(to: other)
  }
}

//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DoublePointData: PointData, Codable, @unchecked Sendable {
  public var value: Double

  enum CodingKeys: String, CodingKey {
    case value
    case startEpochNanos
    case endEpochNanos
    case attributes
    case exemplars
  }

  init(startEpochNanos: UInt64, endEpochNanos: UInt64, attributes: [String: AttributeValue], exemplars: [ExemplarData], value: Double) {
    self.value = value
    super.init(startEpochNanos: startEpochNanos, endEpochNanos: endEpochNanos, attributes: attributes, exemplars: exemplars)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(value, forKey: .value)
    try container.encode(attributes, forKey: .attributes)
    try container.encode(endEpochNanos, forKey: .endEpochNanos)
    try container.encode(startEpochNanos, forKey: .startEpochNanos)
    try container.encode(exemplars as! [DoubleExemplarData], forKey: .exemplars)
  }

  public required init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    value = try values.decode(Double.self, forKey: .value)
    let attributes = try values.decode([String: AttributeValue].self, forKey: .attributes)
    let endEpochNanos = try values.decode(UInt64.self, forKey: .endEpochNanos)
    let exemplars = try values.decode([DoubleExemplarData].self, forKey: .exemplars)
    let startEpochNanos = try values
      .decode(UInt64.self, forKey: .startEpochNanos)
    super.init(
      startEpochNanos: startEpochNanos,
      endEpochNanos: endEpochNanos,
      attributes: attributes,
      exemplars: exemplars
    )
  }

  static func - (left: DoublePointData, right: DoublePointData) -> Self {
    return DoublePointData(startEpochNanos: left.startEpochNanos, endEpochNanos: left.endEpochNanos, attributes: left.attributes, exemplars: left.exemplars, value: left.value - right.value) as! Self
  }
}

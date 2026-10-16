//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class SummaryPointData: PointData, Codable, @unchecked Sendable {
  public var count: UInt64
  public var sum: Double
  public var values: [ValueAtQuantile]

  enum CodingKeys: String, CodingKey {
    case count
    case sum
    case values
    case startEpochNanos
    case endEpochNanos
    case attributes
    case exemplars
  }

  init(startEpochNanos: UInt64, endEpochNanos: UInt64, attributes: [String: AttributeValue], count: UInt64, sum: Double, percentileValues: [ValueAtQuantile]) {
    self.count = count
    self.sum = sum
    values = percentileValues
    super.init(startEpochNanos: startEpochNanos, endEpochNanos: endEpochNanos, attributes: attributes, exemplars: [ExemplarData]())
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(sum, forKey: .sum)
    try container.encode(count, forKey: .count)
    try container.encodeIfPresent(values, forKey: .values)
    try container.encode(attributes, forKey: .attributes)
    try container.encode(endEpochNanos, forKey: .endEpochNanos)
    try container.encode(startEpochNanos, forKey: .startEpochNanos)
    try container.encode(exemplars as! [DoubleExemplarData], forKey: .exemplars)
  }

  public required init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    count = try values.decode(UInt64.self, forKey: .count)
    sum = try values.decode(Double.self, forKey: .sum)
    self.values = try values.decode([ValueAtQuantile].self, forKey: .values)
    let startEpochNanos = try values.decode(UInt64.self, forKey: .startEpochNanos)
    let endEpochNanos = try values.decode(UInt64.self, forKey: .endEpochNanos)
    let attributes = try values.decode([String: AttributeValue].self, forKey: .attributes)
    let exemplars = try values.decode([DoubleExemplarData].self, forKey: .exemplars)
    super.init(
      startEpochNanos: startEpochNanos,
      endEpochNanos: endEpochNanos,
      attributes: attributes,
      exemplars: exemplars
    )
  }
}

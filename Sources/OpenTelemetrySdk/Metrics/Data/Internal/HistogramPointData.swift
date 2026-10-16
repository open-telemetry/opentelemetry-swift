//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class HistogramPointData: PointData, Codable, @unchecked Sendable {
  public var sum: Double
  public var count: UInt64
  public var min: Double
  public var max: Double
  public var boundaries: [Double]
  public var counts: [Int]
  public var hasMin: Bool
  public var hasMax: Bool

  enum CodingKeys: String, CodingKey {
    case sum
    case counts
    case min
    case max
    case boundaries
    case count
    case hasMin
    case hasMax
    case startEpochNanos
    case endEpochNanos
    case attributes
    case exemplars
  }

  init(startEpochNanos: UInt64, endEpochNanos: UInt64, attributes: [String: AttributeValue], exemplars: [ExemplarData], sum: Double, count: UInt64, min: Double, max: Double, boundaries: [Double], counts: [Int], hasMin: Bool, hasMax: Bool) {
    self.sum = sum
    self.count = count
    self.min = min
    self.max = max
    self.boundaries = boundaries
    self.counts = counts
    self.hasMin = hasMin
    self.hasMax = hasMax
    super.init(startEpochNanos: startEpochNanos, endEpochNanos: endEpochNanos, attributes: attributes, exemplars: exemplars)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(sum, forKey: .sum)
    try container.encode(count, forKey: .count)
    try container.encode(counts, forKey: .counts)
    try container.encode(min, forKey: .min)
    try container.encode(max, forKey: .max)
    try container.encode(boundaries, forKey: .boundaries)
    try container.encode(hasMin, forKey: .hasMin)
    try container.encode(hasMax, forKey: .hasMax)
    try container.encode(attributes, forKey: .attributes)
    try container.encode(endEpochNanos, forKey: .endEpochNanos)
    try container.encode(startEpochNanos, forKey: .startEpochNanos)
    try container.encode(exemplars as! [DoubleExemplarData], forKey: .exemplars)
  }

  public required init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    sum = try values.decode(Double.self, forKey: .sum)
    counts = try values.decode([Int].self, forKey: .counts)
    count = try values.decode(UInt64.self, forKey: .count)
    hasMin = try values.decode(Bool.self, forKey: .hasMin)
    hasMax = try values.decode(Bool.self, forKey: .hasMax)
    min = try values.decode(Double.self, forKey: .min)
    max = try values.decode(Double.self, forKey: .max)
    boundaries = try values.decode([Double].self, forKey: .boundaries)
    let attributes = try values.decode([String: AttributeValue].self, forKey: .attributes)
    let endEpochNanos = try values.decode(UInt64.self, forKey: .endEpochNanos)
    let exemplars = try values.decode([DoubleExemplarData].self, forKey: .exemplars)
    let startEpochNanos = try values.decode(UInt64.self, forKey: .startEpochNanos)
    super.init(
      startEpochNanos: startEpochNanos,
      endEpochNanos: endEpochNanos,
      attributes: attributes,
      exemplars: exemplars
    )
  }
}

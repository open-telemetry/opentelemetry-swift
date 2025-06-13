//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class HistogramPointData: PointData {

  public var sum: Double
  public var count: UInt64
  public var min: Double
  public var max: Double
  public var boundaries: [Double]
  public var counts: [Int]
  public var hasMin: Bool
  public var hasMax: Bool

  enum CodingKeys : String, CodingKey {
    case sum
    case counts
    case min
    case max
    case boundaries
    case count
    case hasMin
    case hasMax
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

  required init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    sum = try values.decode(Double.self, forKey: .sum)
    counts = try values.decode([Int].self, forKey: .counts)
    count = try values.decode(UInt64.self, forKey: .count)
    hasMin = try values.decode(Bool.self, forKey: .hasMin)
    hasMax = try values.decode(Bool.self, forKey: .hasMax)
    min = try values.decode(Double.self, forKey: .min)
    max = try values.decode(Double.self, forKey: .max)
    boundaries = try values.decode([Double].self, forKey: .boundaries)
    try super.init(from: decoder)
  }

}

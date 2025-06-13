//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class SummaryPointData: PointData {
  public var count: UInt64
  public var sum: Double
  public var values: [ValueAtQuantile]

  enum CodingKeys : String, CodingKey {
    case count
    case sum
    case values
  }

  init(startEpochNanos: UInt64, endEpochNanos: UInt64, attributes: [String: AttributeValue], count: UInt64, sum: Double, percentileValues: [ValueAtQuantile]) {
    self.count = count
    self.sum = sum
    values = percentileValues
    super.init(startEpochNanos: startEpochNanos, endEpochNanos: endEpochNanos, attributes: attributes, exemplars: [ExemplarData]())
  }


  required init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    self.count = try values.decode(UInt64.self, forKey: .count)
    self.sum = try values.decode(Double.self, forKey: .sum)
    self.values = try values.decode([ValueAtQuantile].self, forKey: .values)
    try super.init(from: decoder)
  }
}

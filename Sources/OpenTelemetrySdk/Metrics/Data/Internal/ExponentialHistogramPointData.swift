//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class ExponentialHistogramPointData: PointData, Codable {
  public var scale: Int
  public var sum: Double
  public var count: Int
  public var zeroCount: Int64
  public var hasMin: Bool
  public var hasMax: Bool
  public var min: Double
  public var max: Double
  public var positiveBuckets: ExponentialHistogramBuckets
  public var negativeBuckets: ExponentialHistogramBuckets

  enum CodingKeys: String, CodingKey {
    case scale
    case sum
    case count
    case zeroCount
    case hasMin
    case hasMax
    case min
    case max
    case positiveBuckets
    case negativeBuckets
    case startEpochNanos
    case endEpochNanos
    case attributes
    case exemplars
  }

  public init(scale: Int,
              sum: Double,
              zeroCount: Int64,
              hasMin: Bool,
              hasMax: Bool,
              min: Double,
              max: Double,
              positiveBuckets: ExponentialHistogramBuckets,
              negativeBuckets: ExponentialHistogramBuckets,
              startEpochNanos: UInt64,
              epochNanos: UInt64,
              attributes: [String: AttributeValue],
              exemplars: [ExemplarData]) {
    self.scale = scale
    self.sum = sum
    self.zeroCount = zeroCount
    self.hasMin = hasMin
    self.hasMax = hasMax
    self.min = min
    self.max = max
    self.positiveBuckets = positiveBuckets
    self.negativeBuckets = negativeBuckets

    count = Int(zeroCount) + positiveBuckets.totalCount + negativeBuckets.totalCount

    super.init(startEpochNanos: startEpochNanos, endEpochNanos: epochNanos, attributes: attributes, exemplars: exemplars)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(count, forKey: .count)
    try container.encode(scale, forKey: .scale)
    try container.encode(sum, forKey: .sum)
    try container.encode(zeroCount, forKey: .zeroCount)
    try container.encode(hasMin, forKey: .hasMin)
    try container.encode(hasMax, forKey: .hasMax)
    try container.encode(min, forKey: .min)
    try container.encode(max, forKey: .max)
    try container.encode(startEpochNanos, forKey: .startEpochNanos)
    try container.encode(endEpochNanos, forKey: .endEpochNanos)
    try container.encode(attributes, forKey: .attributes)
    try container.encode(exemplars as! [DoubleExemplarData], forKey: .exemplars)

    if positiveBuckets is EmptyExponentialHistogramBuckets {
      try container.encodeNil(forKey: .positiveBuckets)
    } else {
      try container.encode(positiveBuckets, forKey: .positiveBuckets)
    }
    if negativeBuckets is EmptyExponentialHistogramBuckets {
      try container.encodeNil(forKey: .negativeBuckets)
    } else {
      try container.encode(negativeBuckets, forKey: .negativeBuckets)
    }
  }

  public required init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    count = try values.decode(Int.self, forKey: .count)
    scale = try values.decode(Int.self, forKey: .scale)
    sum = try values.decode(Double.self, forKey: .sum)
    zeroCount = try values.decode(Int64.self, forKey: .zeroCount)
    hasMin = try values.decode(Bool.self, forKey: .hasMin)
    hasMax = try values.decode(Bool.self, forKey: .hasMax)
    min = try values.decode(Double.self, forKey: .min)
    max = try values.decode(Double.self, forKey: .max)

    do {
      positiveBuckets = try values.decode(DoubleBase2ExponentialHistogramBuckets.self, forKey: .positiveBuckets)
    } catch {
      positiveBuckets = EmptyExponentialHistogramBuckets(scale: scale)
    }

    do {
      negativeBuckets = try values
        .decode(
          DoubleBase2ExponentialHistogramBuckets.self,
          forKey: .negativeBuckets
        )
    } catch {
      negativeBuckets = EmptyExponentialHistogramBuckets(scale: scale)
    }
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
}

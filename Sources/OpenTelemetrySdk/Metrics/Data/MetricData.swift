//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public enum MetricDataType: Codable {
  case LongGauge
  case DoubleGauge
  case LongSum
  case DoubleSum
  case Summary
  case Histogram
  case ExponentialHistogram
}

@available(*, deprecated, renamed: "MetricData")
public typealias StableMetricData = MetricData

public struct MetricData: Equatable, Codable {
  public private(set) var resource: Resource
  public private(set) var instrumentationScopeInfo: InstrumentationScopeInfo
  public private(set) var name: String
  public private(set) var description: String
  public private(set) var unit: String
  public private(set) var type: MetricDataType
  public private(set) var isMonotonic: Bool
  public private(set) var data: Data

  public static let empty = MetricData(
    resource: Resource.empty,
    instrumentationScopeInfo: InstrumentationScopeInfo(),
    name: "",
    description: "",
    unit: "",
    type: .Summary,
    isMonotonic: false,
    data: MetricData
      .Data(aggregationTemporality: .cumulative, points: [PointData]())
  )

  public class Data: Equatable {
    public private(set) var points: [PointData]
    public private(set) var aggregationTemporality: AggregationTemporality

    init(aggregationTemporality: AggregationTemporality, points: [PointData]) {
      self.aggregationTemporality = aggregationTemporality
      self.points = points
    }

    public static func == (lhs: MetricData.Data, rhs: MetricData.Data) -> Bool {
      return lhs.points == rhs.points && lhs.aggregationTemporality == rhs.aggregationTemporality
    }
  }

  enum CodingKeys: String, CodingKey {
    case resource
    case instrumentationScopeInfo
    case name
    case description
    case unit
    case type
    case isMonotonic
    case dataPoints
    case aggregationTemporality
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(resource, forKey: .resource)
    try container
      .encode(instrumentationScopeInfo, forKey: .instrumentationScopeInfo)
    try container.encode(name, forKey: .name)
    try container.encode(description, forKey: .description)
    try container.encode(unit, forKey: .unit)
    try container.encode(type, forKey: .type)
    try container.encode(isMonotonic, forKey: .isMonotonic)

    switch type {
    case .Summary:
      try container.encode(data.points as! [SummaryPointData], forKey: .dataPoints)
    case .LongGauge, .LongSum:
      try container
        .encode(data.points as! [LongPointData], forKey: .dataPoints)
    case .DoubleGauge, .DoubleSum:
      try container.encode(data.points as! [DoublePointData], forKey: .dataPoints)
    case .Histogram, .ExponentialHistogram:
      try container
        .encode(data.points as! [HistogramPointData], forKey: .dataPoints)
    }

    try container.encode(data.aggregationTemporality, forKey: .aggregationTemporality)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    resource = try container.decode(Resource.self, forKey: .resource)
    instrumentationScopeInfo = try container
      .decode(InstrumentationScopeInfo.self, forKey: .instrumentationScopeInfo)
    name = try container.decode(String.self, forKey: .name)
    description = try container.decode(String.self, forKey: .description)
    unit = try container.decode(String.self, forKey: .unit)
    type = try container.decode(MetricDataType.self, forKey: .type)
    isMonotonic = try container.decode(Bool.self, forKey: .isMonotonic)

    let aggregationTemporality = try container.decode(
      AggregationTemporality.self,
      forKey: .aggregationTemporality
    )
    switch type {
    case .Summary:
      let points = try container.decode([SummaryPointData].self, forKey: .dataPoints)
      data = Data(aggregationTemporality: aggregationTemporality, points: points)
    case .LongGauge, .LongSum:
      let points = try container.decode(
        [LongPointData].self,
        forKey: .dataPoints
      )
      data = Data(
        aggregationTemporality: aggregationTemporality,
        points: points
      )
    case .DoubleGauge, .DoubleSum:
      let points = try container.decode(
        [DoublePointData].self,
        forKey: .dataPoints
      )
      data = Data(
        aggregationTemporality: aggregationTemporality,
        points: points
      )
    case .Histogram, .ExponentialHistogram:
      let points = try container.decode(
        [HistogramPointData].self,
        forKey: .dataPoints
      )
      data = Data(
        aggregationTemporality: aggregationTemporality,
        points: points
      )
    }
  }

  init(
    resource: Resource,
    instrumentationScopeInfo: InstrumentationScopeInfo,
    name: String,
    description: String,
    unit: String,
    type: MetricDataType,
    isMonotonic: Bool,
    data: MetricData.Data
  ) {
    self.resource = resource
    self.instrumentationScopeInfo = instrumentationScopeInfo
    self.name = name
    self.description = description
    self.unit = unit
    self.type = type
    self.isMonotonic = isMonotonic
    self.data = data
  }

  public static func == (lhs: MetricData, rhs: MetricData) -> Bool {
    return lhs.resource == rhs.resource &&
      lhs.instrumentationScopeInfo == rhs.instrumentationScopeInfo &&
      lhs.name == rhs.name &&
      lhs.description == rhs.description &&
      lhs.unit == rhs.unit &&
      lhs.type == rhs.type &&
      lhs.isMonotonic == rhs.isMonotonic &&
      lhs.data == rhs.data
  }
}

extension MetricData {
  static func createExponentialHistogram(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, data: ExponentialHistogramData) -> MetricData {
    MetricData(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: name,
      description: description,
      unit: unit,
      type: .ExponentialHistogram,
      isMonotonic: false,
      data: data
    )
  }

  static func createDoubleGauge(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, data: GaugeData) -> MetricData {
    MetricData(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: name,
      description: description,
      unit: unit,
      type: .DoubleGauge,
      isMonotonic: false,
      data: data
    )
  }

  static func createLongGauge(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, data: GaugeData) -> MetricData {
    MetricData(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: name,
      description: description,
      unit: unit,
      type: .LongGauge,
      isMonotonic: false,
      data: data
    )
  }

  static func createDoubleSum(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, isMonotonic: Bool, data: SumData) -> MetricData {
    MetricData(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: name,
      description: description,
      unit: unit,
      type: .DoubleSum,
      isMonotonic: isMonotonic,
      data: data
    )
  }

  static func createLongSum(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, isMonotonic: Bool, data: SumData) -> MetricData {
    MetricData(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: name,
      description: description,
      unit: unit,
      type: .LongSum,
      isMonotonic: isMonotonic,
      data: data
    )
  }

  static func createHistogram(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, data: HistogramData) -> MetricData {
    MetricData(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: name,
      description: description,
      unit: unit,
      type: .Histogram,
      isMonotonic: false,
      data: data
    )
  }

  func isEmpty() -> Bool {
    return data.points.isEmpty
  }

  func getHistogramData() -> [HistogramPointData] {
    if type == .Histogram {
      return data.points as! [HistogramPointData]
    }

    return [HistogramPointData]()
  }
}

@available(*, deprecated, renamed: "HistogramData")
public typealias StableHistogramData = HistogramData

public class HistogramData: MetricData.Data {
  init(aggregationTemporality: AggregationTemporality, points: [HistogramPointData]) {
    super.init(aggregationTemporality: aggregationTemporality, points: points)
  }
}

@available(*, deprecated, renamed: "ExponentialHistogramData")
public typealias StableExponentialHistogramData = ExponentialHistogramData

public class ExponentialHistogramData: MetricData.Data {
  override init(aggregationTemporality: AggregationTemporality, points: [PointData]) {
    super.init(aggregationTemporality: aggregationTemporality, points: points)
  }
}

@available(*, deprecated, renamed: "GaugeData")
public typealias StableGaugeData = GaugeData

public class GaugeData: MetricData.Data {
  override init(aggregationTemporality: AggregationTemporality, points: [PointData]) {
    super.init(aggregationTemporality: aggregationTemporality, points: points)
  }
}

@available(*, deprecated, renamed: "SumData")
public typealias StableSumData = SumData

public class SumData: MetricData.Data {
  override init(aggregationTemporality: AggregationTemporality, points: [PointData]) {
    super.init(aggregationTemporality: aggregationTemporality, points: points)
  }
}

@available(*, deprecated, renamed: "SummaryData")
public typealias StableSummaryData = SummaryData

public class SummaryData: MetricData.Data {
  override init(aggregationTemporality: AggregationTemporality, points: [PointData]) {
    super.init(aggregationTemporality: aggregationTemporality, points: points)
  }
}

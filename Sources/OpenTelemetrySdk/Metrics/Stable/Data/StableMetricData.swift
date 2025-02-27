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

public struct StableMetricData: Equatable, Encodable {
  public private(set) var resource: Resource
  public private(set) var instrumentationScopeInfo: InstrumentationScopeInfo
  public private(set) var name: String
  public private(set) var description: String
  public private(set) var unit: String
  public private(set) var type: MetricDataType
  public private(set) var isMonotonic: Bool
  public private(set) var data: Data

  public static let empty = StableMetricData(resource: Resource.empty, instrumentationScopeInfo: InstrumentationScopeInfo(), name: "", description: "", unit: "", type: .Summary, isMonotonic: false, data: StableMetricData.Data(aggregationTemporality: .cumulative, points: [PointData]()))

  public class Data: Equatable, Encodable {
    public private(set) var points: [PointData]
    public private(set) var aggregationTemporality: AggregationTemporality

    init(aggregationTemporality: AggregationTemporality, points: [PointData]) {
      self.aggregationTemporality = aggregationTemporality
      self.points = points
    }

    public static func == (lhs: StableMetricData.Data, rhs: StableMetricData.Data) -> Bool {
      return lhs.points == rhs.points && lhs.aggregationTemporality == rhs.aggregationTemporality
    }
  }

  init(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, type: MetricDataType, isMonotonic: Bool, data: StableMetricData.Data) {
    self.resource = resource
    self.instrumentationScopeInfo = instrumentationScopeInfo
    self.name = name
    self.description = description
    self.unit = unit
    self.type = type
    self.isMonotonic = isMonotonic
    self.data = data
  }

  public static func == (lhs: StableMetricData, rhs: StableMetricData) -> Bool {
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

extension StableMetricData {
  static func createExponentialHistogram(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, data: StableExponentialHistogramData) -> StableMetricData {
    StableMetricData(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, type: .ExponentialHistogram, isMonotonic: false, data: data)
  }

  static func createDoubleGauge(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, data: StableGaugeData) -> StableMetricData {
    StableMetricData(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, type: .DoubleGauge, isMonotonic: false, data: data)
  }

  static func createLongGauge(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, data: StableGaugeData) -> StableMetricData {
    StableMetricData(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, type: .LongGauge, isMonotonic: false, data: data)
  }

  static func createDoubleSum(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, isMonotonic: Bool, data: StableSumData) -> StableMetricData {
    StableMetricData(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, type: .DoubleSum, isMonotonic: isMonotonic, data: data)
  }

  static func createLongSum(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, isMonotonic: Bool, data: StableSumData) -> StableMetricData {
    StableMetricData(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, type: .LongSum, isMonotonic: isMonotonic, data: data)
  }

  static func createHistogram(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, data: StableHistogramData) -> StableMetricData {
    StableMetricData(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, type: .Histogram, isMonotonic: false, data: data)
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

public class StableHistogramData: StableMetricData.Data {
  init(aggregationTemporality: AggregationTemporality, points: [HistogramPointData]) {
    super.init(aggregationTemporality: aggregationTemporality, points: points)
  }
}

public class StableExponentialHistogramData: StableMetricData.Data {
  override init(aggregationTemporality: AggregationTemporality, points: [PointData]) {
    super.init(aggregationTemporality: aggregationTemporality, points: points)
  }
}

public class StableGaugeData: StableMetricData.Data {
  override init(aggregationTemporality: AggregationTemporality, points: [PointData]) {
    super.init(aggregationTemporality: aggregationTemporality, points: points)
  }
}

public class StableSumData: StableMetricData.Data {
  override init(aggregationTemporality: AggregationTemporality, points: [PointData]) {
    super.init(aggregationTemporality: aggregationTemporality, points: points)
  }
}

public class StableSummaryData: StableMetricData.Data {
  override init(aggregationTemporality: AggregationTemporality, points: [PointData]) {
    super.init(aggregationTemporality: aggregationTemporality, points: points)
  }
}

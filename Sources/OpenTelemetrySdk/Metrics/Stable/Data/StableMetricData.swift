//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public enum MetricDataType {
    case LongGauge
    case DoubleGauge
    case LongSum
    case DoubleSum
    case Summary
    case Histogram
    case ExponentialHistogram
}

public struct StableMetricData: Equatable {
    public private(set) var resource: Resource
    public private(set) var instrumentationScopeInfo: InstrumentationScopeInfo
    public private(set) var name: String
    public private(set) var description: String
    public private(set) var unit: String
    public private(set) var type: MetricDataType
    public private(set) var data: Data

    public static let empty = StableMetricData(resource: Resource.empty, instrumentationScopeInfo: InstrumentationScopeInfo(), name: "", description: "", unit: "", type: .Summary, data: StableMetricData.Data(points: [PointData]()))

    public class Data: Equatable {
        public private(set) var points: [PointData]

        internal init(points: [PointData]) {
            self.points = points
        }

        public static func == (lhs: StableMetricData.Data, rhs: StableMetricData.Data) -> Bool {
            return lhs.points == rhs.points
        }
    }

    internal init(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, type: MetricDataType, data: StableMetricData.Data) {
        self.resource = resource
        self.instrumentationScopeInfo = instrumentationScopeInfo
        self.name = name
        self.description = description
        self.unit = unit
        self.type = type
        self.data = data
    }

    public static func == (lhs: StableMetricData, rhs: StableMetricData) -> Bool {
        return lhs.resource == rhs.resource &&
            lhs.instrumentationScopeInfo == rhs.instrumentationScopeInfo &&
            lhs.name == rhs.name &&
            lhs.description == rhs.description &&
            lhs.unit == rhs.unit &&
            lhs.type == rhs.type &&
            lhs.data.points == rhs.data.points
    }
}

extension StableMetricData {
    static func createExponentialHistogram(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, data: StableExponentialHistogramData) -> StableMetricData {
        StableMetricData(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, type: .ExponentialHistogram, data: data)
    }

    static func createDoubleGauge(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, data: StableGaugeData) -> StableMetricData {
        StableMetricData(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, type: .DoubleGauge, data: data)
    }

    static func createLongGauge(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, data: StableGaugeData) -> StableMetricData {
        StableMetricData(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, type: .LongGauge, data: data)
    }

    static func createDoubleSum(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, data: StableSumData) -> StableMetricData {
        StableMetricData(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, type: .DoubleSum, data: data)
    }

    static func createLongSum(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, data: StableSumData) -> StableMetricData {
        StableMetricData(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, type: .LongSum, data: data)
    }

    static func createHistogram(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, data: StableHistogramData) -> StableMetricData {
        StableMetricData(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, type: .Histogram, data: data)
    }

    func isEmpty() -> Bool {
        return data.points.isEmpty
    }

    func getHistogramData() -> [HistogramPointData] {
        if self.type == .Histogram {
            return data.points as! [HistogramPointData]
        }

        return [HistogramPointData]()
    }
}

public class StableHistogramData: StableMetricData.Data {
    public private(set) var aggregationTemporality: AggregationTemporality
    init(aggregationTemporality: AggregationTemporality, points: [HistogramPointData]) {
        self.aggregationTemporality = aggregationTemporality
        super.init(points: points)
    }
}

public class StableExponentialHistogramData: StableMetricData.Data {
    public private(set) var aggregationTemporality: AggregationTemporality
    init(aggregationTemporality: AggregationTemporality, points: [PointData]) {
        self.aggregationTemporality = aggregationTemporality
        super.init(points: points)
    }
}

public class StableGaugeData: StableMetricData.Data {
    public private(set) var aggregationTemporality: AggregationTemporality
    init(aggregationTemporality: AggregationTemporality, points: [PointData]) {
        self.aggregationTemporality = aggregationTemporality
        super.init(points: points)
    }
}

public class StableSumData: StableMetricData.Data {
    public private(set) var aggregationTemporality: AggregationTemporality
    init(aggregationTemporality: AggregationTemporality, points: [PointData]) {
        self.aggregationTemporality = aggregationTemporality
        super.init(points: points)
    }
}

public class StableSummaryData: StableMetricData.Data {
    public private(set) var aggregationTemporality: AggregationTemporality
    init(aggregationTemporality: AggregationTemporality, points: [PointData]) {
        self.aggregationTemporality = aggregationTemporality
        super.init(points: points)
    }
}

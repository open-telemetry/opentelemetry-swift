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



public struct StableMetricData {
    public static let empty = StableMetricData(resource: Resource.empty, instrumentationScopeInfo: InstrumentationScopeInfo(), name: "", description: "", unit: "", type: .Summary, data: StableMetricData.Data(points: [PointData]()))
    public class Data {
        internal init(points: [PointData]) {
            self.points = points
        }
        
        public private(set) var points : [PointData]
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
    
    var resource : Resource
    var instrumentationScopeInfo : InstrumentationScopeInfo
    var name : String
    var description : String
    var unit : String
    var type : MetricDataType
    var data : Data
}

extension StableMetricData {
    
    static func createHistogram(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, name: String, description: String, unit: String, data: StableHistogramData) -> StableMetricData {
        StableMetricData(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, type: .Histogram, data:data)
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


public class StableHistogramData : StableMetricData.Data {
    public private(set) var aggregationTemporality : AggregationTemporality
    init(aggregationTemporality: AggregationTemporality, points : [HistogramPointData]) {
        super.init(points: points)
        self.aggregationTemporality = aggregationTemporality
    }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public struct Metric {
    public private(set) var namespace: String
    public private(set) var resource: Resource
    public private(set) var instrumentationScopeInfo : InstrumentationScopeInfo
    public private(set) var name: String
    public private(set) var description: String
    public private(set) var aggregationType: AggregationType
    public internal(set) var data = [MetricData]()

    init(namespace: String, name: String, desc: String, type: AggregationType, resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo) {
        self.namespace = namespace
        self.instrumentationScopeInfo = instrumentationScopeInfo
        self.name = name
        description = desc
        aggregationType = type
        self.resource = resource
    }
}

extension Metric: Equatable {
    private static func isEqual<T: Equatable>(type: T.Type, lhs: Any, rhs: Any) -> Bool {
        guard let lhs = lhs as? T, let rhs = rhs as? T else { return false }

        return lhs == rhs
    }
    
    public static func == (lhs: Metric, rhs: Metric) -> Bool {
        if lhs.namespace == rhs.namespace &&
            lhs.resource == rhs.resource &&
            lhs.instrumentationScopeInfo == rhs.instrumentationScopeInfo &&
            lhs.name == rhs.name &&
            lhs.description == rhs.description &&
            lhs.aggregationType == rhs.aggregationType {
            
            switch lhs.aggregationType {
            case .doubleGauge:
                return isEqual(type: [SumData<Double>].self, lhs: lhs.data, rhs: rhs.data)
            case .intGauge:
                return isEqual(type: [SumData<Int>].self, lhs: lhs.data, rhs: rhs.data)
            case .doubleSum:
                return isEqual(type: [SumData<Double>].self, lhs: lhs.data, rhs: rhs.data)
            case .doubleSummary:
                return isEqual(type: [SummaryData<Double>].self, lhs: lhs.data, rhs: rhs.data)
            case .intSum:
                return isEqual(type: [SumData<Int>].self, lhs: lhs.data, rhs: rhs.data)
            case .intSummary:
                return isEqual(type: [SummaryData<Int>].self, lhs: lhs.data, rhs: rhs.data)
            case .doubleHistogram:
                return isEqual(type: [HistogramData<Double>].self, lhs: lhs.data, rhs: rhs.data)
            case .intHistogram:
                return isEqual(type: [HistogramData<Int>].self, lhs: lhs.data, rhs: rhs.data)
            }
            
        }
        
        return false
    }        
}

// explicit encoding & decoding implementation is needed in order to correctly
// deduce the concrete type of `Metric.data`.
extension Metric: Codable {
    enum CodingKeys: String, CodingKey {
        case namespace
        case resource
        case instrumentationScopeInfo
        case name
        case description
        case aggregationType
        case data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let namespace = try container.decode(String.self, forKey: .namespace)
        let resource = try container.decode(Resource.self, forKey: .resource)
        let instrumentationScopeInfo = try container.decode(InstrumentationScopeInfo.self, forKey: .instrumentationScopeInfo)
        let name = try container.decode(String.self, forKey: .name)
        let description = try container.decode(String.self, forKey: .description)
        let aggregationType = try container.decode(AggregationType.self, forKey: .aggregationType)
        
        self.init(namespace: namespace, name: name, desc: description, type: aggregationType, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)
        
        switch aggregationType {
        case .doubleGauge:
            data = try container.decode([SumData<Double>].self, forKey: .data)
        case .intGauge:
            data = try container.decode([SumData<Int>].self, forKey: .data)
        case .doubleSum:
            data = try container.decode([SumData<Double>].self, forKey: .data)
        case .doubleSummary:
            data = try container.decode([SummaryData<Double>].self, forKey: .data)
        case .intSum:
            data = try container.decode([SumData<Int>].self, forKey: .data)
        case .intSummary:
            data = try container.decode([SummaryData<Int>].self, forKey: .data)
        case .doubleHistogram:
            data = try container.decode([HistogramData<Double>].self, forKey: .data)
        case .intHistogram:
            data = try container.decode([HistogramData<Int>].self, forKey: .data)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(namespace, forKey: .namespace)
        try container.encode(resource, forKey: .resource)
        try container.encode(instrumentationScopeInfo, forKey: .instrumentationScopeInfo)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(aggregationType, forKey: .aggregationType)
        
        switch aggregationType {
        case .doubleGauge:
            guard let gaugeData = data as? [SumData<Double>] else {
                let encodingContext = EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Expected [SumData<Double>] type for doubleGauge aggregationType, but instead found \(type(of: data))"
                )
                
                throw EncodingError.invalidValue(data, encodingContext)
            }
            
            try container.encode(gaugeData, forKey: .data)
        case .intGauge:
            guard let gaugeData = data as? [SumData<Int>] else {
                let encodingContext = EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Expected [SumData<Int>] type for intGauge aggregationType, but instead found \(type(of: data))"
                )
                
                throw EncodingError.invalidValue(data, encodingContext)
            }
            
            try container.encode(gaugeData, forKey: .data)
        case .doubleSum:
            guard let sumData = data as? [SumData<Double>] else {
                let encodingContext = EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Expected [SumData<Double>] type for doubleSum aggregationType, but instead found \(type(of: data))"
                )
                
                throw EncodingError.invalidValue(data, encodingContext)
            }
            
            try container.encode(sumData, forKey: .data)
        case .doubleSummary:
            guard let summaryData = data as? [SummaryData<Double>] else {
                let encodingContext = EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Expected [SummaryData<Double>] type for doubleSummary aggregationType, but instead found \(type(of: data))"
                )
                
                throw EncodingError.invalidValue(data, encodingContext)
            }
            
            try container.encode(summaryData, forKey: .data)
        case .intSum:
            guard let sumData = data as? [SumData<Int>] else {
                let encodingContext = EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Expected [SumData<Int>] type for intSum aggregationType, but instead found \(type(of: data))"
                )
                
                throw EncodingError.invalidValue(data, encodingContext)
            }
            
            try container.encode(sumData, forKey: .data)
        case .intSummary:
            guard let summaryData = data as? [SummaryData<Int>] else {
                let encodingContext = EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Expected [SummaryData<Int>] type for intSummary aggregationType, but instead found \(type(of: data))"
                )
                
                throw EncodingError.invalidValue(data, encodingContext)
            }
            
            try container.encode(summaryData, forKey: .data)
        case .doubleHistogram:
            guard let summaryData = data as? [HistogramData<Double>] else {
                let encodingContext = EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Expected [HistogramData<Double>] type for doubleHistogram aggregationType, but instead found \(type(of: data))"
                )
                
                throw EncodingError.invalidValue(data, encodingContext)
            }
            
            try container.encode(summaryData, forKey: .data)
        case .intHistogram:
            guard let summaryData = data as? [HistogramData<Int>] else {
                let encodingContext = EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Expected [HistogramData<Int>] type for intHistogram aggregationType, but instead found \(type(of: data))"
                )
                
                throw EncodingError.invalidValue(data, encodingContext)
            }
            
            try container.encode(summaryData, forKey: .data)
        }
    }
}

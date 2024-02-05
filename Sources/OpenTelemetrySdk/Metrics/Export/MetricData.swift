/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol MetricData {
    var startTimestamp: Date { get set }
    var timestamp: Date { get set }
    var labels: [String: String] { get set }
}

public struct NoopMetricData: MetricData {
    public var startTimestamp =  Date.distantPast
    public var timestamp =  Date.distantPast
    public var labels = [String: String]()
}

public struct SumData<T>: MetricData {
    public init(startTimestamp: Date, timestamp: Date, labels: [String : String] = [String: String](), sum: T) {
        self.startTimestamp = startTimestamp
        self.timestamp = timestamp
        self.labels = labels
        self.sum = sum
    }
    
    public var startTimestamp: Date
    public var timestamp: Date
    public var labels: [String: String] = [String: String]()
    public var sum: T
}

public struct SummaryData<T>: MetricData {
    public init(startTimestamp: Date, timestamp: Date, labels: [String : String] = [String: String](), count: Int, sum: T, min: T, max: T) {
        self.startTimestamp = startTimestamp
        self.timestamp = timestamp
        self.labels = labels
        self.count = count
        self.sum = sum
        self.min = min
        self.max = max
    }
    
    public var startTimestamp: Date
    public var timestamp: Date
    public var labels: [String: String] = [String: String]()
    public var count: Int
    public var sum: T
    public var min: T
    public var max: T
}

public struct HistogramData<T>: MetricData {
    public init(startTimestamp: Date, timestamp: Date, labels: [String : String] = [String: String](), buckets: (boundaries: Array<T>, counts: Array<Int>), count: Int, sum: T) {
        self.startTimestamp = startTimestamp
        self.timestamp = timestamp
        self.labels = labels
        self.buckets = buckets
        self.count = count
        self.sum = sum
    }
    
    public var startTimestamp: Date
    public var timestamp: Date
    public var labels: [String: String] = [String: String]()
    public var buckets: (
      boundaries: Array<T>,
      counts: Array<Int>
    )
    public var count: Int
    public var sum: T
}

extension NoopMetricData: Equatable, Codable {}

extension SumData: Equatable where T: Equatable {}

extension SumData: Codable where T: Codable {}

extension SummaryData: Equatable where T: Equatable {}

extension SummaryData: Codable where T: Codable {}

extension HistogramData: Equatable where T: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.startTimestamp == rhs.startTimestamp &&
            lhs.timestamp == rhs.timestamp &&
            lhs.labels == rhs.labels &&
            lhs.buckets.boundaries == rhs.buckets.boundaries &&
            lhs.buckets.counts == rhs.buckets.counts &&
            lhs.count == rhs.count &&
            lhs.sum == rhs.sum
    }
}

extension HistogramData: Codable where T: Codable {
    enum CodingKeys: String, CodingKey {
        case startTimestamp
        case timestamp
        case labels
        case buckets
        case count
        case sum
    }
    
    enum BucketsCodingKeys: String, CodingKey {
        case boundaries
        case counts        
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let startTimestamp = try container.decode(Date.self, forKey: .startTimestamp)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let labels = try container.decode([String: String].self, forKey: .labels)
        
        let bucketsContainer = try container.nestedContainer(keyedBy: BucketsCodingKeys.self, forKey: .buckets)
        let bucketsBoundaries = try bucketsContainer.decode([T].self, forKey: .boundaries)
        let bucketsCounts = try bucketsContainer.decode([Int].self, forKey: .counts)
        
        let count = try container.decode(Int.self, forKey: .count)
        let sum = try container.decode(T.self, forKey: .sum)
        
        self.init(startTimestamp: startTimestamp, timestamp: timestamp, labels: labels, buckets: (boundaries: bucketsBoundaries, counts: bucketsCounts), count: count, sum: sum)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(startTimestamp, forKey: .startTimestamp)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(labels, forKey: .labels)
        
        var bucketsContainer = container.nestedContainer(keyedBy: BucketsCodingKeys.self, forKey: .buckets)
        try bucketsContainer.encode(buckets.boundaries, forKey: .boundaries)
        try bucketsContainer.encode(buckets.counts, forKey: .counts)
        
        try container.encode(count, forKey: .count)
        try container.encode(sum, forKey: .sum)
    }
}

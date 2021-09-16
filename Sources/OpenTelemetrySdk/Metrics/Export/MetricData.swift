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
    public var startTimestamp: Date
    public var timestamp: Date
    public var labels: [String: String] = [String: String]()
    public var sum: T
}

public struct SummaryData<T>: MetricData {
    public var startTimestamp: Date
    public var timestamp: Date
    public var labels: [String: String] = [String: String]()
    public var count: Int
    public var sum: T
    public var min: T
    public var max: T
}

public struct HistogramData<T>: MetricData {
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

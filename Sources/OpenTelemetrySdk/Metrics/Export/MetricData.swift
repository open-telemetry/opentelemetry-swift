// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

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

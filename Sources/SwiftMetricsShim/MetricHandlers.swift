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

import CoreMetrics
import OpenTelemetryApi

class SwiftCounterMetric: CounterHandler, SwiftMetric {
    
    var metricName: String
    var metricType: MetricType = .counter
    let counter: AnyCounterMetric<Int>
    let labels: [String: String]
    
    required init(name: String, labels: [String: String], meter: Meter) {
        metricName = name
        counter = meter.createIntCounter(name: name, monotonic: true)
        self.labels = labels
    }
    
    func increment(by: Int64) {
        counter.add(value: Int(by), labels: labels)
    }
    
    func reset() {
        
    }
    
}

class SwiftGaugeMetric: RecorderHandler, SwiftMetric {
    
    var metricName: String
    var metricType: MetricType = .gauge
    let counter: AnyCounterMetric<Double>
    let labels: [String: String]
    
    required init(name: String, labels: [String: String], meter: Meter) {
        metricName = name
        counter = meter.createDoubleCounter(name: name, monotonic: false)
        self.labels = labels
    }
    
    func record(_ value: Int64) {
        counter.add(value: Double(value), labels: labels)
    }
    
    func record(_ value: Double) {
        counter.add(value: value, labels: labels)
    }
    
}

class SwiftHistogramMetric: RecorderHandler, SwiftMetric {
    
    var metricName: String
    var metricType: MetricType = .histogram
    let measure: AnyMeasureMetric<Double>
    let labels: [String: String]
    
    required init(name: String, labels: [String: String], meter: Meter) {
        metricName = name
        measure = meter.createDoubleMeasure(name: name)
        self.labels = labels
    }
    
    func record(_ value: Int64) {
        measure.record(value: Double(value), labels: labels)
    }
    
    func record(_ value: Double) {
        measure.record(value: value, labels: labels)
    }
    
}

class SwiftSummaryMetric: TimerHandler, SwiftMetric {
    
    var metricName: String
    var metricType: MetricType = .summary
    let measure: AnyMeasureMetric<Double>
    let labels: [String: String]
    
    required init(name: String, labels: [String: String], meter: Meter) {
        metricName = name
        measure = meter.createDoubleMeasure(name: name)
        self.labels = labels
    }
    
    func recordNanoseconds(_ duration: Int64) {
        measure.record(value: Double(duration), labels: labels)
    }
    
}

protocol SwiftMetric {
    var metricName: String { get }
    var metricType: MetricType { get }
    init(name: String, labels: [String: String], meter: Meter)
}

enum MetricType: String {
    case counter
    case histogram
    case gauge
    case summary
}

struct MetricKey: Hashable {
    let name: String
    let type: MetricType
}

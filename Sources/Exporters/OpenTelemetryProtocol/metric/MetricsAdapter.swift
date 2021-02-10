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
import OpenTelemetryApi
import OpenTelemetrySdk


struct MetricsAdapter {
    static func toProtoResourceMetrics(metricDataList: [Metric]) -> [Opentelemetry_Proto_Metrics_V1_ResourceMetrics] {
        let resourceAndLibraryMap = groupByResouceAndLibrary(metricDataList: metricDataList)
        var resourceMetrics = [Opentelemetry_Proto_Metrics_V1_ResourceMetrics]()
        
        resourceAndLibraryMap.forEach { resMap in
            var instrumentationLibraryMetrics = [Opentelemetry_Proto_Metrics_V1_InstrumentationLibraryMetrics]()
            resMap.value.forEach { instLibrary in
                var protoInst =
                Opentelemetry_Proto_Metrics_V1_InstrumentationLibraryMetrics()
                protoInst.instrumentationLibrary =
                    CommonAdapter.toProtoInstrumentationLibrary(instrumentationLibraryInfo: instLibrary.key)
                instLibrary.value.forEach {
                    protoInst.metrics.append($0)
                }
                instrumentationLibraryMetrics.append(protoInst)
            }
            var resourceMetric = Opentelemetry_Proto_Metrics_V1_ResourceMetrics()
            resourceMetric.resource = ResourceAdapter.toProtoResource(resource: resMap.key)
            resourceMetric.instrumentationLibraryMetrics.append(contentsOf: instrumentationLibraryMetrics)
            resourceMetrics.append(resourceMetric)
            
        }
        
        

        return resourceMetrics
    }
    
    private static func groupByResouceAndLibrary(metricDataList: [Metric]) ->  [Resource :[InstrumentationLibraryInfo : [Opentelemetry_Proto_Metrics_V1_Metric]]] {
        var results =  [Resource : [InstrumentationLibraryInfo : [Opentelemetry_Proto_Metrics_V1_Metric]]]()

        metricDataList.forEach {
            results[$0.resource, default:[InstrumentationLibraryInfo : [Opentelemetry_Proto_Metrics_V1_Metric]]()][$0.instrumentationLibraryInfo,default:[Opentelemetry_Proto_Metrics_V1_Metric]()]
                .append(toProtoMetric(metric: $0))
        }
        
        return results
    }
    
    static func toProtoMetric(metric: Metric) -> Opentelemetry_Proto_Metrics_V1_Metric {
        
        var protoMetric = Opentelemetry_Proto_Metrics_V1_Metric()
        protoMetric.name = metric.name
        protoMetric.description_p = metric.description

    
        metric.data.forEach {
        switch metric.aggregationType {
            case .doubleSum:
                guard let sumData = $0 as? SumData<Double> else {
                    break
                }
                var protoDataPoint = Opentelemetry_Proto_Metrics_V1_DoubleDataPoint()
                protoDataPoint.value = sumData.sum
                sumData.labels.forEach {
                    var kvp = Opentelemetry_Proto_Common_V1_StringKeyValue()
                    kvp.key = $0.key
                    kvp.value = $0.value
                    protoDataPoint.labels.append(kvp)
                }
                
                protoMetric.doubleSum.dataPoints.append(protoDataPoint)
                break
            case .doubleSummary:
                
                guard let summaryData = $0 as? SummaryData<Double> else {
                    break
                }
                var protoDataPoint = Opentelemetry_Proto_Metrics_V1_DoubleHistogramDataPoint()
                protoDataPoint.sum = summaryData.sum
                protoDataPoint.count = UInt64(summaryData.count)
                protoDataPoint.explicitBounds = [summaryData.min, summaryData.max]
                
                protoDataPoint.startTimeUnixNano = summaryData.startTimestamp.timeIntervalSince1970.toNanoseconds
                protoDataPoint.timeUnixNano = summaryData.timestamp.timeIntervalSince1970.toNanoseconds
                
                summaryData.labels.forEach {
                    var kvp = Opentelemetry_Proto_Common_V1_StringKeyValue()
                    kvp.key = $0.key
                    kvp.value = $0.value
                    protoDataPoint.labels.append(kvp)
                }
                
                protoMetric.doubleHistogram.dataPoints.append(protoDataPoint)
                
                break
            case .intSum:
                guard let sumData = $0 as? SumData<Int> else {
                    break;
                }
                var protoDataPoint = Opentelemetry_Proto_Metrics_V1_IntDataPoint()
                protoDataPoint.value = Int64(sumData.sum)
                sumData.labels.forEach {
                    var kvp = Opentelemetry_Proto_Common_V1_StringKeyValue()
                    kvp.key = $0.key
                    kvp.value = $0.value
                    protoDataPoint.labels.append(kvp)
                }
                
                protoMetric.intSum.dataPoints.append(protoDataPoint)
                
                break
            case .intSummary:
                guard let summaryData = $0 as? SummaryData<Int> else {
                    break
                }
                var protoDataPoint = Opentelemetry_Proto_Metrics_V1_IntHistogramDataPoint()
                protoDataPoint.sum = Int64(summaryData.sum)
                protoDataPoint.count = UInt64(summaryData.count)
//                protoDataPoint.explicitBounds = [summaryData.min, summaryData.max]
                
                protoDataPoint.startTimeUnixNano = summaryData.startTimestamp.timeIntervalSince1970.toNanoseconds
                protoDataPoint.timeUnixNano = summaryData.timestamp.timeIntervalSince1970.toNanoseconds
                
                summaryData.labels.forEach {
                    var kvp = Opentelemetry_Proto_Common_V1_StringKeyValue()
                    kvp.key = $0.key
                    kvp.value = $0.value
                    protoDataPoint.labels.append(kvp)
                }
                
                protoMetric.intHistogram.dataPoints.append(protoDataPoint)
                
                break
            }
        }
        return protoMetric
    }
    
}

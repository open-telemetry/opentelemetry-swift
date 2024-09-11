/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public enum MetricsAdapter {
  public static func toProtoResourceMetrics(stableMetricData: [StableMetricData]) -> [Opentelemetry_Proto_Metrics_V1_ResourceMetrics] {
    let resourceAndScopeMap = groupByResourceAndScope(stableMetricData: stableMetricData)
    
    var resourceMetrics = [Opentelemetry_Proto_Metrics_V1_ResourceMetrics]()
    resourceAndScopeMap.forEach { resMap in
      var instrumentationScopeMetrics = [Opentelemetry_Proto_Metrics_V1_ScopeMetrics]()
      resMap.value.forEach { instScope in
        var protoInst = Opentelemetry_Proto_Metrics_V1_ScopeMetrics()
        protoInst.scope =
        CommonAdapter.toProtoInstrumentationScope(instrumentationScopeInfo: instScope.key)
        instScope.value.forEach {
          protoInst.metrics.append($0)
        }
        instrumentationScopeMetrics.append(protoInst)
      }
      var resourceMetric = Opentelemetry_Proto_Metrics_V1_ResourceMetrics()
      resourceMetric.resource = ResourceAdapter.toProtoResource(resource: resMap.key)
      resourceMetric.scopeMetrics.append(contentsOf: instrumentationScopeMetrics)
      resourceMetrics.append(resourceMetric)
    }
    return resourceMetrics
  }
  
  public static func toProtoResourceMetrics(metricDataList: [Metric]) -> [Opentelemetry_Proto_Metrics_V1_ResourceMetrics] {
    let resourceAndScopeMap = groupByResourceAndScope(metricDataList: metricDataList)
    var resourceMetrics = [Opentelemetry_Proto_Metrics_V1_ResourceMetrics]()
    
    resourceAndScopeMap.forEach { resMap in
      var instrumentationScopeMetrics = [Opentelemetry_Proto_Metrics_V1_ScopeMetrics]()
      resMap.value.forEach { instScope in
        var protoInst =
        Opentelemetry_Proto_Metrics_V1_ScopeMetrics()
        protoInst.scope =
        CommonAdapter.toProtoInstrumentationScope(instrumentationScopeInfo: instScope.key)
        instScope.value.forEach {
          protoInst.metrics.append($0)
        }
        instrumentationScopeMetrics.append(protoInst)
      }
      var resourceMetric = Opentelemetry_Proto_Metrics_V1_ResourceMetrics()
      resourceMetric.resource = ResourceAdapter.toProtoResource(resource: resMap.key)
      resourceMetric.scopeMetrics.append(contentsOf: instrumentationScopeMetrics)
      resourceMetrics.append(resourceMetric)
    }
    
    return resourceMetrics
  }
  
  private static func groupByResourceAndScope(stableMetricData: [StableMetricData]) -> [Resource: [InstrumentationScopeInfo: [Opentelemetry_Proto_Metrics_V1_Metric]]] {
    var results = [Resource: [InstrumentationScopeInfo: [Opentelemetry_Proto_Metrics_V1_Metric]]]()
    
    stableMetricData.forEach {
      if let metric = toProtoMetric(stableMetric: $0) {
        results[$0.resource, default: [InstrumentationScopeInfo: [Opentelemetry_Proto_Metrics_V1_Metric]]()][$0.instrumentationScopeInfo, default: [Opentelemetry_Proto_Metrics_V1_Metric]()].append(metric)
      }
    }
    return results
  }
  
  private static func groupByResourceAndScope(metricDataList: [Metric]) -> [Resource: [InstrumentationScopeInfo: [Opentelemetry_Proto_Metrics_V1_Metric]]] {
    var results = [Resource: [InstrumentationScopeInfo: [Opentelemetry_Proto_Metrics_V1_Metric]]]()
    
    metricDataList.forEach {
      if let metric = toProtoMetric(metric: $0) {
        results[$0.resource, default: [InstrumentationScopeInfo: [Opentelemetry_Proto_Metrics_V1_Metric]]()][$0.instrumentationScopeInfo, default: [Opentelemetry_Proto_Metrics_V1_Metric]()]
          .append(metric)
      }
    }
    
    return results
  }
  
  public static func toProtoMetric(stableMetric: StableMetricData) -> Opentelemetry_Proto_Metrics_V1_Metric? {
    var protoMetric = Opentelemetry_Proto_Metrics_V1_Metric()
    protoMetric.name = stableMetric.name
    protoMetric.unit = stableMetric.unit
    protoMetric.description_p = stableMetric.description
    if stableMetric.data.points.isEmpty { return nil }
    
    stableMetric.data.points.forEach {
      switch stableMetric.type {
      case .LongGauge:
        guard let gaugeData = $0 as? LongPointData else {
          break
        }
        var protoDataPoint = Opentelemetry_Proto_Metrics_V1_NumberDataPoint()
        injectPointData(protoNumberPoint: &protoDataPoint, pointData: gaugeData)
        protoDataPoint.value = .asInt(Int64(gaugeData.value))
        protoMetric.gauge.dataPoints.append(protoDataPoint)
      case .LongSum:
        guard let gaugeData = $0 as? LongPointData else {
          break
        }
        var protoDataPoint = Opentelemetry_Proto_Metrics_V1_NumberDataPoint()
        injectPointData(protoNumberPoint: &protoDataPoint, pointData: gaugeData)
        protoDataPoint.value = .asInt(Int64(gaugeData.value))
        protoMetric.sum.aggregationTemporality = stableMetric.data.aggregationTemporality.convertToProtoEnum()
        protoMetric.sum.dataPoints.append(protoDataPoint)
        protoMetric.sum.isMonotonic = stableMetric.isMonotonic
      case .DoubleGauge:
        guard let gaugeData = $0 as? DoublePointData else {
          break
        }
        var protoDataPoint = Opentelemetry_Proto_Metrics_V1_NumberDataPoint()
        injectPointData(protoNumberPoint: &protoDataPoint, pointData: gaugeData)
        protoDataPoint.value = .asDouble(gaugeData.value)
        protoMetric.gauge.dataPoints.append(protoDataPoint)
      case .DoubleSum:
        guard let gaugeData = $0 as? DoublePointData else {
          break
        }
        var protoDataPoint = Opentelemetry_Proto_Metrics_V1_NumberDataPoint()
        injectPointData(protoNumberPoint: &protoDataPoint, pointData: gaugeData)
        protoDataPoint.value = .asDouble(gaugeData.value)
        protoMetric.sum.aggregationTemporality = stableMetric.data.aggregationTemporality.convertToProtoEnum()
        protoMetric.sum.dataPoints.append(protoDataPoint)
        protoMetric.sum.isMonotonic = stableMetric.isMonotonic
      case .Summary:
        guard let summaryData = $0 as? SummaryPointData else {
          break
        }
        var protoDataPoint = Opentelemetry_Proto_Metrics_V1_SummaryDataPoint()
        injectPointData(protoSummaryPoint: &protoDataPoint, pointData: summaryData)
        protoDataPoint.sum = summaryData.sum
        protoDataPoint.count = summaryData.count
        summaryData.values.forEach {
          var quantile = Opentelemetry_Proto_Metrics_V1_SummaryDataPoint.ValueAtQuantile()
          quantile.quantile = $0.quantile()
          quantile.value = $0.value()
          protoDataPoint.quantileValues.append(quantile)
        }
        protoMetric.summary.dataPoints.append(protoDataPoint)
      case .Histogram:
        guard let histogramData = $0 as? HistogramPointData else {
          break
        }
        var protoDataPoint = Opentelemetry_Proto_Metrics_V1_HistogramDataPoint()
        injectPointData(protoHistogramPoint: &protoDataPoint, pointData: histogramData)
        protoDataPoint.sum = Double(histogramData.sum)
        protoDataPoint.count = UInt64(histogramData.count)
        protoDataPoint.max = Double(histogramData.max)
        protoDataPoint.min = Double(histogramData.min)
        protoDataPoint.explicitBounds = histogramData.boundaries.map { Double($0) }
        protoDataPoint.bucketCounts = histogramData.counts.map { UInt64($0) }
        protoMetric.histogram.aggregationTemporality = stableMetric.data.aggregationTemporality.convertToProtoEnum()
        protoMetric.histogram.dataPoints.append(protoDataPoint)
      case .ExponentialHistogram:
        guard let exponentialHistogramData = $0 as? ExponentialHistogramPointData else {
          break
        }
        var protoDataPoint = Opentelemetry_Proto_Metrics_V1_ExponentialHistogramDataPoint()
        injectPointData(protoExponentialHistogramPoint: &protoDataPoint, pointData: exponentialHistogramData)
        protoDataPoint.scale = Int32(exponentialHistogramData.scale)
        protoDataPoint.sum = Double(exponentialHistogramData.sum)
        protoDataPoint.count = UInt64(exponentialHistogramData.count)
        protoDataPoint.zeroCount = UInt64(exponentialHistogramData.zeroCount)
        protoDataPoint.max = exponentialHistogramData.max
        protoDataPoint.min = exponentialHistogramData.min

        var positiveBuckets = Opentelemetry_Proto_Metrics_V1_ExponentialHistogramDataPoint.Buckets()
        positiveBuckets.offset = Int32(exponentialHistogramData.positiveBuckets.offset)
        positiveBuckets.bucketCounts = exponentialHistogramData.positiveBuckets.bucketCounts.map { UInt64($0) }

        var negativeBuckets = Opentelemetry_Proto_Metrics_V1_ExponentialHistogramDataPoint.Buckets()
        negativeBuckets.offset = Int32(exponentialHistogramData.negativeBuckets.offset)
        negativeBuckets.bucketCounts = exponentialHistogramData.negativeBuckets.bucketCounts.map { UInt64($0) }

        protoDataPoint.positive = positiveBuckets
        protoDataPoint.negative = negativeBuckets

        protoMetric.exponentialHistogram.aggregationTemporality = stableMetric.data.aggregationTemporality.convertToProtoEnum()
        protoMetric.exponentialHistogram.dataPoints.append(protoDataPoint)
      }
    }
    return protoMetric
  }
	
  static func injectPointData(protoExponentialHistogramPoint protoPoint: inout Opentelemetry_Proto_Metrics_V1_ExponentialHistogramDataPoint, pointData: PointData) {
    protoPoint.timeUnixNano = pointData.endEpochNanos
    protoPoint.startTimeUnixNano = pointData.startEpochNanos

    pointData.attributes.forEach {
      protoPoint.attributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
    }

    pointData.exemplars.forEach {
      var protoExemplar = Opentelemetry_Proto_Metrics_V1_Exemplar()
      protoExemplar.timeUnixNano = $0.epochNanos

      $0.filteredAttributes.forEach {
        protoExemplar.filteredAttributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
      }
      if let spanContext = $0.spanContext {
        protoExemplar.spanID = TraceProtoUtils.toProtoSpanId(spanId: spanContext.spanId)
        protoExemplar.traceID = TraceProtoUtils.toProtoTraceId(traceId: spanContext.traceId)
      }
    }
  }
  
  static func injectPointData(protoHistogramPoint protoPoint: inout Opentelemetry_Proto_Metrics_V1_HistogramDataPoint, pointData: PointData) {
    protoPoint.timeUnixNano = pointData.endEpochNanos
    protoPoint.startTimeUnixNano = pointData.startEpochNanos
    
    pointData.attributes.forEach {
      protoPoint.attributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
    }
    
    pointData.exemplars.forEach {
      var protoExemplar = Opentelemetry_Proto_Metrics_V1_Exemplar()
      protoExemplar.timeUnixNano = $0.epochNanos
      
      $0.filteredAttributes.forEach {
        protoExemplar.filteredAttributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
      }
      if let spanContext = $0.spanContext {
        protoExemplar.spanID = TraceProtoUtils.toProtoSpanId(spanId: spanContext.spanId)
        protoExemplar.traceID = TraceProtoUtils.toProtoTraceId(traceId: spanContext.traceId)
      }
    }
  }
  
  static func injectPointData(protoSummaryPoint protoPoint: inout Opentelemetry_Proto_Metrics_V1_SummaryDataPoint, pointData: PointData) {
    protoPoint.timeUnixNano = pointData.endEpochNanos
    protoPoint.startTimeUnixNano = pointData.startEpochNanos
    
    pointData.attributes.forEach {
      protoPoint.attributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
    }
    
    pointData.exemplars.forEach {
      var protoExemplar = Opentelemetry_Proto_Metrics_V1_Exemplar()
      protoExemplar.timeUnixNano = $0.epochNanos
      
      $0.filteredAttributes.forEach {
        protoExemplar.filteredAttributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
      }
      if let spanContext = $0.spanContext {
        protoExemplar.spanID = TraceProtoUtils.toProtoSpanId(spanId: spanContext.spanId)
        protoExemplar.traceID = TraceProtoUtils.toProtoTraceId(traceId: spanContext.traceId)
      }
    }
  }
  
  static func injectPointData(protoNumberPoint protoPoint: inout Opentelemetry_Proto_Metrics_V1_NumberDataPoint, pointData: PointData) {
    protoPoint.timeUnixNano = pointData.endEpochNanos
    protoPoint.startTimeUnixNano = pointData.startEpochNanos
    
    pointData.attributes.forEach {
      protoPoint.attributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
    }
    
    pointData.exemplars.forEach {
      var protoExemplar = Opentelemetry_Proto_Metrics_V1_Exemplar()
      protoExemplar.timeUnixNano = $0.epochNanos
      
      $0.filteredAttributes.forEach {
        protoExemplar.filteredAttributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
      }
      if let spanContext = $0.spanContext {
        protoExemplar.spanID = TraceProtoUtils.toProtoSpanId(spanId: spanContext.spanId)
        protoExemplar.traceID = TraceProtoUtils.toProtoTraceId(traceId: spanContext.traceId)
      }
      protoPoint.exemplars.append(protoExemplar)
    }
  }
  
  public static func toProtoMetric(metric: Metric) -> Opentelemetry_Proto_Metrics_V1_Metric? {
    var protoMetric = Opentelemetry_Proto_Metrics_V1_Metric()
    protoMetric.name = metric.name
    protoMetric.unit = "unit"
    protoMetric.description_p = metric.description
    if metric.data.isEmpty { return nil }
    
    metric.data.forEach {
      switch metric.aggregationType {
      case .doubleGauge:
        guard let gaugeData = $0 as? SumData<Double> else {
          break
        }
        var protoDataPoint = Opentelemetry_Proto_Metrics_V1_NumberDataPoint()
        
        protoDataPoint.timeUnixNano = gaugeData.timestamp.timeIntervalSince1970.toNanoseconds
        protoDataPoint.startTimeUnixNano = gaugeData.startTimestamp.timeIntervalSince1970.toNanoseconds
        protoDataPoint.value = .asDouble(gaugeData.sum)
        gaugeData.labels.forEach {
          var kvp = Opentelemetry_Proto_Common_V1_KeyValue()
          kvp.key = $0.key
          kvp.value.stringValue = $0.value
          protoDataPoint.attributes.append(kvp)
        }
        
        protoMetric.gauge.dataPoints.append(protoDataPoint)
      case .intGauge:
        guard let gaugeData = $0 as? SumData<Int> else {
          break
        }
        
        var protoDataPoint = Opentelemetry_Proto_Metrics_V1_NumberDataPoint()
        
        protoDataPoint.value = .asInt(Int64(exactly: gaugeData.sum)!)
        protoDataPoint.timeUnixNano = gaugeData.timestamp.timeIntervalSince1970.toNanoseconds
        protoDataPoint.startTimeUnixNano = gaugeData.startTimestamp.timeIntervalSince1970.toNanoseconds
        gaugeData.labels.forEach {
          var kvp = Opentelemetry_Proto_Common_V1_KeyValue()
          kvp.key = $0.key
          kvp.value.stringValue = $0.value
          protoDataPoint.attributes.append(kvp)
        }
        
        protoMetric.gauge.dataPoints.append(protoDataPoint)
      case .doubleSum:
        guard let sumData = $0 as? SumData<Double> else {
          break
        }
        
        var protoDataPoint = Opentelemetry_Proto_Metrics_V1_NumberDataPoint()
        
        protoDataPoint.value = .asDouble(sumData.sum)
        protoDataPoint.timeUnixNano = sumData.timestamp.timeIntervalSince1970.toNanoseconds
        protoDataPoint.startTimeUnixNano = sumData.startTimestamp.timeIntervalSince1970.toNanoseconds
        sumData.labels.forEach {
          var kvp = Opentelemetry_Proto_Common_V1_KeyValue()
          kvp.key = $0.key
          kvp.value.stringValue = $0.value
          protoDataPoint.attributes.append(kvp)
        }
        
        protoMetric.sum.aggregationTemporality = .cumulative
        protoMetric.sum.dataPoints.append(protoDataPoint)
      case .doubleSummary:
        
        guard let summaryData = $0 as? SummaryData<Double> else {
          break
        }
        var protoDataPoint = Opentelemetry_Proto_Metrics_V1_SummaryDataPoint()
        
        protoDataPoint.sum = summaryData.sum
        protoDataPoint.count = UInt64(summaryData.count)
        
        protoDataPoint.startTimeUnixNano = summaryData.startTimestamp.timeIntervalSince1970.toNanoseconds
        protoDataPoint.timeUnixNano = summaryData.timestamp.timeIntervalSince1970.toNanoseconds
        
        summaryData.labels.forEach {
          var kvp = Opentelemetry_Proto_Common_V1_KeyValue()
          kvp.key = $0.key
          kvp.value.stringValue = $0.value
          protoDataPoint.attributes.append(kvp)
        }
        
        protoMetric.summary.dataPoints.append(protoDataPoint)
      case .intSum:
        guard let sumData = $0 as? SumData<Int> else {
          break
        }
        var protoDataPoint = Opentelemetry_Proto_Metrics_V1_NumberDataPoint()
        
        protoDataPoint.value = .asInt(Int64(sumData.sum))
        protoDataPoint.timeUnixNano = sumData.timestamp.timeIntervalSince1970.toNanoseconds
        protoDataPoint.startTimeUnixNano = sumData.startTimestamp.timeIntervalSince1970.toNanoseconds
        sumData.labels.forEach {
          var kvp = Opentelemetry_Proto_Common_V1_KeyValue()
          
          kvp.key = $0.key
          kvp.value.stringValue = $0.value
          protoDataPoint.attributes.append(kvp)
        }
        
        protoMetric.sum.aggregationTemporality = .cumulative
        protoMetric.sum.dataPoints.append(protoDataPoint)
      case .intSummary:
        guard let summaryData = $0 as? SummaryData<Int> else {
          break
        }
        var protoDataPoint = Opentelemetry_Proto_Metrics_V1_SummaryDataPoint()
        
        protoDataPoint.sum = Double(summaryData.sum)
        protoDataPoint.count = UInt64(summaryData.count)
        protoDataPoint.startTimeUnixNano = summaryData.startTimestamp.timeIntervalSince1970.toNanoseconds
        protoDataPoint.timeUnixNano = summaryData.timestamp.timeIntervalSince1970.toNanoseconds
        
        summaryData.labels.forEach {
          var kvp = Opentelemetry_Proto_Common_V1_KeyValue()
          kvp.key = $0.key
          kvp.value.stringValue = $0.value
          protoDataPoint.attributes.append(kvp)
        }
        
        protoMetric.summary.dataPoints.append(protoDataPoint)
      case .intHistogram:
        guard let histogramData = $0 as? HistogramData<Int> else {
          break
        }
        var protoDataPoint = Opentelemetry_Proto_Metrics_V1_HistogramDataPoint()
        
        protoDataPoint.sum = Double(histogramData.sum)
        protoDataPoint.count = UInt64(histogramData.count)
        protoDataPoint.startTimeUnixNano = histogramData.startTimestamp.timeIntervalSince1970.toNanoseconds
        protoDataPoint.timeUnixNano = histogramData.timestamp.timeIntervalSince1970.toNanoseconds
        protoDataPoint.explicitBounds = histogramData.buckets.boundaries.map { Double($0) }
        protoDataPoint.bucketCounts = histogramData.buckets.counts.map { UInt64($0) }
        
        histogramData.labels.forEach {
          var kvp = Opentelemetry_Proto_Common_V1_KeyValue()
          kvp.key = $0.key
          kvp.value.stringValue = $0.value
          protoDataPoint.attributes.append(kvp)
        }
        
        protoMetric.histogram.aggregationTemporality = .cumulative
        protoMetric.histogram.dataPoints.append(protoDataPoint)
      case .doubleHistogram:
        guard let histogramData = $0 as? HistogramData<Double> else {
          break
        }
        var protoDataPoint = Opentelemetry_Proto_Metrics_V1_HistogramDataPoint()
        protoDataPoint.sum = Double(histogramData.sum)
        protoDataPoint.count = UInt64(histogramData.count)
        protoDataPoint.startTimeUnixNano = histogramData.startTimestamp.timeIntervalSince1970.toNanoseconds
        protoDataPoint.timeUnixNano = histogramData.timestamp.timeIntervalSince1970.toNanoseconds
        protoDataPoint.explicitBounds = histogramData.buckets.boundaries.map { Double($0) }
        protoDataPoint.bucketCounts = histogramData.buckets.counts.map { UInt64($0) }
        
        histogramData.labels.forEach {
          var kvp = Opentelemetry_Proto_Common_V1_KeyValue()
          kvp.key = $0.key
          kvp.value.stringValue = $0.value
          protoDataPoint.attributes.append(kvp)
        }
        
        protoMetric.histogram.aggregationTemporality = .cumulative
        protoMetric.histogram.dataPoints.append(protoDataPoint)
      }
    }
    return protoMetric
  }
}

extension AggregationTemporality {
  func convertToProtoEnum() -> Opentelemetry_Proto_Metrics_V1_AggregationTemporality {
    switch self {
    case .cumulative:
      return .cumulative
    case .delta:
      return .delta
    }
  }
}

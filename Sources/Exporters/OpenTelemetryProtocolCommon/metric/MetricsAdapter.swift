/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public enum MetricsAdapter {
  public static func toProtoResourceMetrics(metricData: [MetricData]) -> [Opentelemetry_Proto_Metrics_V1_ResourceMetrics] {
    let resourceAndScopeMap = groupByResourceAndScope(metricData: metricData)

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

  private static func groupByResourceAndScope(metricData: [MetricData]) -> [Resource: [InstrumentationScopeInfo: [Opentelemetry_Proto_Metrics_V1_Metric]]] {
    var results = [Resource: [InstrumentationScopeInfo: [Opentelemetry_Proto_Metrics_V1_Metric]]]()

    metricData.forEach {
      if let metric = toProtoMetric(metricData: $0) {
        results[$0.resource, default: [InstrumentationScopeInfo: [Opentelemetry_Proto_Metrics_V1_Metric]]()][$0.instrumentationScopeInfo, default: [Opentelemetry_Proto_Metrics_V1_Metric]()].append(metric)
      }
    }
    return results
  }

  public static func toProtoMetric(metricData: MetricData) -> Opentelemetry_Proto_Metrics_V1_Metric? {
    var protoMetric = Opentelemetry_Proto_Metrics_V1_Metric()
    protoMetric.name = metricData.name
    protoMetric.unit = metricData.unit
    protoMetric.description_p = metricData.description
    if metricData.data.points.isEmpty { return nil }

    metricData.data.points.forEach {
      switch metricData.type {
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
        protoMetric.sum.aggregationTemporality = metricData.data.aggregationTemporality.convertToProtoEnum()
        protoMetric.sum.dataPoints.append(protoDataPoint)
        protoMetric.sum.isMonotonic = metricData.isMonotonic
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
        protoMetric.sum.aggregationTemporality = metricData.data.aggregationTemporality.convertToProtoEnum()
        protoMetric.sum.dataPoints.append(protoDataPoint)
        protoMetric.sum.isMonotonic = metricData.isMonotonic
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
          quantile.quantile = $0.quantile
          quantile.value = $0.value
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
        protoMetric.histogram.aggregationTemporality = metricData.data.aggregationTemporality.convertToProtoEnum()
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

        protoMetric.exponentialHistogram.aggregationTemporality = metricData.data.aggregationTemporality.convertToProtoEnum()
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

      if let doubleExemplar = $0 as? DoubleExemplarData {
        protoExemplar.value = .asDouble(doubleExemplar.value)
      }

      if let longExemplar = $0 as? LongExemplarData {
        protoExemplar.value = .asInt(Int64(longExemplar.value))
      }

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

  static func injectPointData(protoHistogramPoint protoPoint: inout Opentelemetry_Proto_Metrics_V1_HistogramDataPoint, pointData: PointData) {
    protoPoint.timeUnixNano = pointData.endEpochNanos
    protoPoint.startTimeUnixNano = pointData.startEpochNanos

    pointData.attributes.forEach {
      protoPoint.attributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
    }

    pointData.exemplars.forEach {
      var protoExemplar = Opentelemetry_Proto_Metrics_V1_Exemplar()
      protoExemplar.timeUnixNano = $0.epochNanos

      if let doubleExemplar = $0 as? DoubleExemplarData {
        protoExemplar.value = .asDouble(doubleExemplar.value)
      }

      if let longExemplar = $0 as? LongExemplarData {
        protoExemplar.value = .asInt(Int64(longExemplar.value))
      }

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

  static func injectPointData(protoSummaryPoint protoPoint: inout Opentelemetry_Proto_Metrics_V1_SummaryDataPoint, pointData: PointData) {
    protoPoint.timeUnixNano = pointData.endEpochNanos
    protoPoint.startTimeUnixNano = pointData.startEpochNanos

    pointData.attributes.forEach {
      protoPoint.attributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
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
		
	  if let doubleExemplar = $0 as? DoubleExemplarData {
		protoExemplar.value = .asDouble(doubleExemplar.value)
	  }

	  if let longExemplar = $0 as? LongExemplarData {
		protoExemplar.value = .asInt(Int64(longExemplar.value))
	  }

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

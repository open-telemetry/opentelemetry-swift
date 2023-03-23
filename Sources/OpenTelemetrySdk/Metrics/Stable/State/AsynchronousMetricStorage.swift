//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class AsynchronousMetricStorage : MetricStorage {
    
    public private(set) var registeredReader : RegisteredReader
    public private(set) var metricDescriptor: MetricDescriptor
    private var aggregationTemporality : AggregationTemporality
    private var aggregator : StableAggregator
    private var attributeProcessor : AttributeProcessor
    private var points = [[String:AttributeValue]: AnyPointData]()
    private var lastPoints = [[String:AttributeValue]: AnyPointData]()

    static func create(registeredReader : RegisteredReader, registeredView : RegisteredView, instrumentDescriptor: InstrumentDescriptor) -> AsynchronousMetricStorage {
        let view = registeredView.view
        let metricDescriptor = MetricDescriptor(view: view, instrument: instrumentDescriptor)
        
        let aggregator = view.aggregation.createAggregator(descriptor: instrumentDescriptor, exemplarFilter: AlwaysOffFilter())
        
        return AsynchronousMetricStorage(registeredReader: registeredReader, metricDescriptor: metricDescriptor, aggregator: aggregator, attributeProcessor: registeredView.attributeProcessor)
    }
    
    init(registeredReader: RegisteredReader,
         metricDescriptor: MetricDescriptor,
         aggregator: StableAggregator,
         attributeProcessor: AttributeProcessor) {
        self.registeredReader = registeredReader
        self.metricDescriptor = metricDescriptor
        self.aggregationTemporality = registeredReader.reader.getAggregationTemporality(for: metricDescriptor.instrument.type)
        self.aggregator = aggregator
        self.attributeProcessor = attributeProcessor
    }
    
    func record(measurement: Measurement) {
        let processedAttributes = attributeProcessor.process(incoming: measurement.attributes)
        let start = aggregationTemporality == AggregationTemporality.delta ? registeredReader.lastCollectedEpochNanos : measurement.startEpochNano
        var newMeasurement = measurement.hasDoubleValue ? Measurement.doubleMeasurement(startEpochNano: start, endEpochNano: measurement.epochNano, value: measurement.doubleValue, attributes: measurement.attributes) : Measurement.longMeasurement(startEpochNano: start, endEpochNano: measurement.epochNano, value: measurement.longValue, attributes: measurement.attributes)
        do {
           try recordPoint(point:aggregator.toPoint(measurement: newMeasurement))
        } catch HistogramAggregatorError.unsupportedOperation(let error) {
            //todo: log error
        } catch {
            // todo : log default error
        }
    }
    
    private func recordPoint(point : AnyPointData) {
        let attributes = point.attributes
        if points.count >= MetricStorageConstants.MAX_CARDINALITY {
            // todo : log error
            return
        }
        if let _ = points[attributes] {
            //todo: error multiple values for same attributes
            return
        }
        points[attributes] = point
    }
    
    public func collect(resource: Resource, scope: InstrumentationScopeInfo, startEpochNanos: UInt64, epochNanos: UInt64) -> StableMetricData {
        var result : [[String: AttributeValue] : AnyPointData]
        if aggregationTemporality == .delta {
            var points = self.points
            var lastPoints = self.lastPoints
            lastPoints = lastPoints.filter { element in
                points[element.key] == nil // remove if points does not contain key
            }
            
            result = Dictionary(uniqueKeysWithValues: points.map { k, v in
                do {
                    if let lastValue = lastPoints[k] {
                        return (k, try aggregator.diff(previousCumulative: lastValue, currentCumulative: v))
                    }
                } catch {
                    // todo log error
                }
                return (k, v)
            })
            self.lastPoints = points
        } else {
            result = points
        }
        points = [[String:AttributeValue] : AnyPointData]()
        return aggregator.toMetricData(resource: resource, scope: scope, descriptor: metricDescriptor, points: Array(result.values), temporality: aggregationTemporality)
    }
    
    public func isEmpty() -> Bool {
        type(of: aggregator) == DropAggregator.self
    }
}

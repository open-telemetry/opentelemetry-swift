//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

enum MetricStoreError: Error {
  case maxCardinality
}

typealias SynchronousMetricStorageProtocol = MetricStorage & WritableMetricStorage

public class SynchronousMetricStorage: SynchronousMetricStorageProtocol {
  let registeredReader: RegisteredReader
  public private(set) var metricDescriptor: MetricDescriptor
  let aggregatorTemporality: AggregationTemporality
  let aggregator: Aggregator
  var aggregatorHandles = [[String: AttributeValue]: AggregatorHandle]()
  let attributeProcessor: AttributeProcessor
  var aggregatorHandlePool = [AggregatorHandle]()
  private let aggregatorHandlesQueue = DispatchQueue(label: "org.opentelemetry.SynchronousMetricStorage.aggregatorHandlesQueue")

  static func empty() -> SynchronousMetricStorageProtocol {
    return EmptyMetricStorage.instance
  }

  static func create(registeredReader: RegisteredReader,
                     registeredView: RegisteredView,
                     descriptor: InstrumentDescriptor,
                     exemplarFilter: ExemplarFilter) -> SynchronousMetricStorageProtocol {
    let metricDescriptor = MetricDescriptor(view: registeredView.view, instrument: descriptor)
    let aggregator = registeredView.view.aggregation.createAggregator(descriptor: descriptor, exemplarFilter: exemplarFilter)
    if type(of: aggregator) == DropAggregator.self {
      return empty()
    }

    return SynchronousMetricStorage(registeredReader: registeredReader, metricDescriptor: metricDescriptor, aggregator: aggregator, attributeProcessor: registeredView.attributeProcessor)
  }

  init(
    registeredReader: RegisteredReader,
    metricDescriptor: MetricDescriptor,
    aggregator: Aggregator,
    attributeProcessor: AttributeProcessor
  ) {
    self.registeredReader = registeredReader
    self.metricDescriptor = metricDescriptor
    aggregatorTemporality = registeredReader.reader.getAggregationTemporality(for: metricDescriptor.instrument.type)
    self.aggregator = aggregator
    self.attributeProcessor = attributeProcessor
  }

  private func getAggregatorHandle(attributes: [String: AttributeValue]) throws -> AggregatorHandle {
    var aggregatorHandle: AggregatorHandle!
    try aggregatorHandlesQueue.sync {
      let processedAttributes = attributeProcessor.process(incoming: attributes)
      if let handle = aggregatorHandles[processedAttributes] {
        aggregatorHandle = handle
        return
      }

      guard aggregatorHandles.count < MetricStorageConstants.MAX_CARDINALITY else {
        throw MetricStoreError.maxCardinality
      }

      let newHandle = aggregatorHandlePool.isEmpty ? aggregator.createHandle() : aggregatorHandlePool.remove(at: 0)
      aggregatorHandles[processedAttributes] = newHandle
      aggregatorHandle = newHandle
    }
    return aggregatorHandle
  }

  public func collect(resource: Resource, scope: InstrumentationScopeInfo, startEpochNanos: UInt64, epochNanos: UInt64) -> MetricData {
    let reset = aggregatorTemporality == .delta
    let start = reset ? registeredReader.lastCollectedEpochNanos : startEpochNanos

    var points = [PointData]()

    aggregatorHandlesQueue.sync {
      aggregatorHandles.forEach { key, value in
        let point = value.aggregateThenMaybeReset(startEpochNano: start, endEpochNano: epochNanos, attributes: key, reset: reset)
        if reset {
          aggregatorHandles.removeValue(forKey: key)
          aggregatorHandlePool.append(value)
        }
        points.append(point)
      }
    }

    if points.isEmpty {
      return MetricData.empty
    }
    return aggregator.toMetricData(resource: resource, scope: scope, descriptor: metricDescriptor, points: points, temporality: aggregatorTemporality)
  }

  public func isEmpty() -> Bool {
    false
  }

  public func recordLong(value: Int, attributes: [String: OpenTelemetryApi.AttributeValue]) {
    do {
      let handle = try getAggregatorHandle(attributes: attributes)
      handle.recordLong(value: value, attributes: attributes)
    } catch MetricStoreError.maxCardinality {
      print("max cardinality (\(MetricStorageConstants.MAX_CARDINALITY)) reached for metric store. Discarding recorded value \"\(value)\" with attributes: \(attributes)")
    } catch {
      // TODO: record error
    }
  }

  public func recordDouble(value: Double, attributes: [String: OpenTelemetryApi.AttributeValue]) {
    do {
      let handle = try getAggregatorHandle(attributes: attributes)
      handle.recordDouble(value: value, attributes: attributes)
    } catch MetricStoreError.maxCardinality {
      print("max cardinality (\(MetricStorageConstants.MAX_CARDINALITY)) reached for metric store. Discarding recorded value \"\(value)\" with attributes: \(attributes)")
    } catch {
      // TODO: error
    }
  }
}

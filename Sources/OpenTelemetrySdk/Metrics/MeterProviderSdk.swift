/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public final class MeterProviderError: Error {}

@available(*, deprecated, renamed: "MeterProviderSdk")
public typealias StableMeterProviderSdk = MeterProviderSdk

public class MeterProviderSdk: MeterProvider {
  private static let defaultMeterName = "unknown"
  private let readerLock = Lock()
  var meterProviderSharedState: MeterProviderSharedState

  var registeredReaders = [RegisteredReader]()
  var registeredViews = [RegisteredView]()

  let componentRegistry: ComponentRegistry<MeterSdk>!

  public func get(name: String) -> MeterSdk {
    meterBuilder(name: name).build()
  }

  public func meterBuilder(name: String) -> MeterBuilderSdk {
    var name = name
    if name.isEmpty {
      name = Self.defaultMeterName
    }

    return MeterBuilderSdk(registry: componentRegistry, instrumentationScopeName: name)
  }

  public static func builder() -> NoopMeterProviderBuilder {
    return NoopMeterProviderBuilder()
  }

  init(registeredViews: [RegisteredView],
       metricReaders: [MetricReader],
       clock: Clock,
       resource: Resource,
       exemplarFilter: ExemplarFilter) {
    let startEpochNano = Date().timeIntervalSince1970.toNanoseconds
    self.registeredViews = registeredViews
    registeredReaders = metricReaders.map { reader in
      RegisteredReader(
        reader: reader,
        registry: ViewRegistry(
          aggregationSelector: reader,
          registeredViews: registeredViews
        )
      )
    }

    meterProviderSharedState = MeterProviderSharedState(clock: clock, resource: resource, startEpochNanos: startEpochNano, exemplarFilter: exemplarFilter)

    componentRegistry = ComponentRegistry { [meterProviderSharedState, registeredReaders] scope in
      MeterSdk(
        meterProviderSharedState: meterProviderSharedState,
        instrumentScope: scope,
        registeredReaders: registeredReaders
      )
    }

    for registeredReader in registeredReaders {
      let producer = LeasedMetricProducer(registry: componentRegistry, sharedState: meterProviderSharedState, registeredReader: registeredReader)
      registeredReader.reader.register(registration: producer)
      registeredReader.lastCollectedEpochNanos = startEpochNano
    }
  }

  public func shutdown() -> ExportResult {
    readerLock.lock()
    defer {
      readerLock.unlock()
    }
    do {
      try registeredReaders.forEach { reader in
        guard reader.reader.shutdown() == .success else {
          // todo throw better error
          throw MeterProviderError()
        }
      }
    } catch {
      return .failure
    }
    return .success
  }

  public func forceFlush() -> ExportResult {
    readerLock.lock()
    defer {
      readerLock.unlock()
    }
    do {
      try registeredReaders.forEach { reader in
        guard reader.reader.forceFlush() == .success else {
          // TODO: throw better error
          throw MeterProviderError()
        }
      }
    } catch {
      return .failure
    }
    return .success
  }

  private class LeasedMetricProducer: MetricProducer {
    private let registry: ComponentRegistry<MeterSdk>
    private var sharedState: MeterProviderSharedState
    private var registeredReader: RegisteredReader

    init(
      registry: ComponentRegistry<MeterSdk>,
      sharedState: MeterProviderSharedState,
      registeredReader: RegisteredReader
    ) {
      self.registry = registry
      self.sharedState = sharedState
      self.registeredReader = registeredReader
    }

    func collectAllMetrics() -> [MetricData] {
      let meters = registry.getComponents()
      var result = [MetricData]()
      let collectTime = sharedState.clock.nanoTime
      for meter in meters {
        result.append(contentsOf: meter.collectAll(registerReader: registeredReader, epochNanos: collectTime))
      }
      registeredReader.lastCollectedEpochNanos = collectTime
      return result
    }
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public class MeterProviderError: Error {}

public class StableMeterProviderSdk: StableMeterProvider {
    private static let defaultMeterName = "unknown"
    private let readerLock = Lock()
    var meterProviderSharedState: MeterProviderSharedState

    var registeredReaders = [RegisteredReader]()
    var registeredViews = [RegisteredView]()
    
    var componentRegistry: ComponentRegistry<StableMeterSdk>!
    
    public func get(name: String) -> StableMeter {
        meterBuilder(name: name).build()
    }
    
    public func meterBuilder(name: String) -> MeterBuilder {
        if registeredReaders.isEmpty {
          return DefaultStableMeterProvider.noop()
        }
        var name = name
        if name.isEmpty {
            name = Self.defaultMeterName
        }
        
        return MeterBuilderSdk(registry: componentRegistry, instrumentationScopeName: name)
    }
    
    public static func builder() -> StableMeterProviderBuilder {
        return StableMeterProviderBuilder()
    }
    
    init(registeredViews: [RegisteredView],
         metricReaders: [StableMetricReader],
         clock: Clock,
         resource: Resource,
         exemplarFilter: ExemplarFilter)
    {
        let startEpochNano = Date().timeIntervalSince1970.toNanoseconds
        self.registeredViews = registeredViews
        self.registeredReaders = metricReaders.map { reader in
            RegisteredReader(reader: reader, registry: StableViewRegistry(aggregationSelector: reader, registeredViews: registeredViews))
        }
        
        meterProviderSharedState = MeterProviderSharedState(clock: clock, resource: resource, startEpochNanos: startEpochNano, exemplarFilter: exemplarFilter)
        
        componentRegistry = ComponentRegistry { scope in
            StableMeterSdk(meterProviderSharedState: &self.meterProviderSharedState, instrumentScope: scope, registeredReaders: &self.registeredReaders)
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
        private let registry: ComponentRegistry<StableMeterSdk>
        private var sharedState: MeterProviderSharedState
        private var registeredReader: RegisteredReader
        
        init(registry: ComponentRegistry<StableMeterSdk>, sharedState: MeterProviderSharedState, registeredReader: RegisteredReader) {
            self.registry = registry
            self.sharedState = sharedState
            self.registeredReader = registeredReader
        }
        
        func collectAllMetrics() -> [StableMetricData] {
            let meters = registry.getComponents()
            var result = [StableMetricData]()
            let collectTime = sharedState.clock.nanoTime
            for meter in meters {
                result.append(contentsOf: meter.collectAll(registerReader: registeredReader, epochNanos: collectTime))
            }
            registeredReader.lastCollectedEpochNanos = collectTime
            return result
        }
    }
}

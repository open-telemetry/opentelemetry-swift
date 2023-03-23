/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public class MeterProviderError : Error {
}

public class StableMeterProviderSdk : StableMeterProvider {
    private static let defaultMeterName = "unknown"
    private let readerLock = Lock()
    var meterProviderSharedState: MeterProviderSharedState

    var registeredReaders = [RegisteredReader]()
    var registeredViews = [RegisteredView]()
    
    var componentRegistery : ComponentRegistry<StableMeterSdk>
    
    public func get(name: String) -> OpenTelemetryApi.StableMeter {
        meterBuilder(name: name).build()
    }
    
    public func meterBuilder(name: String) -> OpenTelemetryApi.MeterBuilder {
        if (registeredReaders.isEmpty) {
            // todo: noop meter provider builder

        }
        var name = name
        if name.isEmpty {
            name = Self.defaultMeterName
        }
        
        return MeterBuilderSdk(registry: componentRegistery, instrumentationScopeName: name)
    }
    
    public static func builder() -> StableMeterProviderBuilder {
        return StableMeterProviderBuilder()
    }
    
    init(registeredViews: [RegisteredView],
         metricReaders: [StableMetricReader],
         clock: Clock,
         resource : Resource,
         exemplarFilter : ExemplarFilter) {
        let startEpochNano = Date().timeIntervalSince1970.toNanoseconds
        self.registeredViews = registeredViews
        self.registeredReaders = metricReaders.map { reader in
            return RegisteredReader(reader: reader, registry: StableViewRegistry(aggregationSelector: reader, registeredViews: registeredViews))
        }
        
        meterProviderSharedState = MeterProviderSharedState(clock: clock, resource: resource, startEpochNanos: startEpochNano, exemplarFilter: exemplarFilter)
        
        weak var weakself : StableMeterProviderSdk?
        componentRegistery = ComponentRegistry {[weakself] scope  in
            StableMeterSdk(meterProviderSharedState: &weakself!.meterProviderSharedState, instrumentScope: scope, registeredReaders: &weakself!.registeredReaders)
        }
        
        weakself = self
        
        for registeredReader in registeredReaders  {
            let producer = LeasedMetricProducer(registry: componentRegistery, sharedState: meterProviderSharedState, registeredReader: registeredReader)
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
           try registeredReaders.forEach() { reader in
             guard reader.reader.shutdown() == .success else {
                    //todo throw better error
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
           try registeredReaders.forEach() { reader in
               guard reader.reader.forceFlush() == .success else {
                   //todo: throw better error
                   throw MeterProviderError()
               }
           }
       } catch {
           return .failure
        }
        return .success
    }

    private class LeasedMetricProducer : MetricProducer {
        private let registry : ComponentRegistry<StableMeterSdk>
        private var sharedState : MeterProviderSharedState
        private var registeredReader : RegisteredReader
        
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


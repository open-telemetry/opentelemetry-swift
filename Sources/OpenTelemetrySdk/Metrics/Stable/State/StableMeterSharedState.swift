/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

class StableMeterSharedState {
    let meterLock = Lock()
    public private(set) var meterRegistry = [StableMeterSdk]()
    public private(set) var readerStorageRegisteries = [RegisteredReader: MetricStorageRegistry]()
    let callbackLock = Lock()
    public private(set) var callbackRegistration = [CallbackRegistration]()
    private let instrumentationScope : InstrumentationScopeInfo
    
    let collectionLock = Lock()
    

    init(instrumentationScope : InstrumentationScopeInfo, registeredReaders : [RegisteredReader]) {
        self.instrumentationScope = instrumentationScope
        readerStorageRegisteries = Dictionary(uniqueKeysWithValues: registeredReaders.map { reader in
            return (reader, MetricStorageRegistry())
        })
    }
    

    func add(meter: StableMeterSdk) {
        meterLock.lock()
        defer{
            meterLock.unlock()
        }
        meterRegistry.append(meter)
    }
    
    func removeCallback(callback: CallbackRegistration) {
        callbackLock.withLockVoid {
            callbackRegistration.removeAll(where: { c in
                c as AnyObject  === callback as AnyObject
            })
        }
    }
    
    func registerCallback(callback: CallbackRegistration) {
        callbackLock.withLockVoid {
            callbackRegistration.append(callback)
        }
    }
    
    func registerSynchronousMetricStorage(instrument: InstrumentDescriptor, meterProviderSharedState: MeterProviderSharedState) -> WritableMetricStorage {
        var registeredStorages = [SynchronousMetricStorage]()
        for (reader, registry) in readerStorageRegisteries {
            for registeredView in reader.registry.findViews(descriptor: instrument, meterScope: instrumentationScope) {
                if type(of: registeredView.view.aggregation) == DropAggregator.self {
                    continue
                }
                registeredStorages.append(registry.register(newStorage: SynchronousMetricStorage.create(registeredReader: reader, registeredView: registeredView, descriptor: instrument, exemplarFilter:  meterProviderSharedState.exemplarFilter)) as! SynchronousMetricStorage)
            }
        }
        if registeredStorages.count == 1 {
            return registeredStorages[0]
        }
        return MultiWritableMetricStorage(storages: registeredStorages)
    }
    
    func registerObservableMeasurement(instrumentDescriptor: InstrumentDescriptor) -> StableObservableMeasurementSdk {
        var registeredStorages = [AsynchronousMetricStorage]()
        for (reader, registry) in readerStorageRegisteries {
            for registeredView in reader.registry.findViews(descriptor: instrumentDescriptor, meterScope: instrumentationScope) {
                if type(of: registeredView.view.aggregation) == DropAggregator.self {
                    continue
                }
                registeredStorages.append(registry.register(newStorage: AsynchronousMetricStorage.create(registeredReader: reader, registeredView: registeredView, instrumentDescriptor: instrumentDescriptor)) as! AsynchronousMetricStorage)
            }
        }
        
        return StableObservableMeasurementSdk(insturmentScope: instrumentationScope, descriptor: instrumentDescriptor, storages: registeredStorages)
    }
    
    
    func collectAll(registeredReader : RegisteredReader, meterProviderSharedState : MeterProviderSharedState, epochNanos : UInt64) -> [StableMetricData] {
        self.callbackLock.lock()
        let currentRegisteredCallbacks = callbackRegistration // todo verify this copies list not references (for concurrency safety)
        self.callbackLock.unlock()
        

        self.collectionLock.lock()
        defer {
            self.collectionLock.unlock()
        }
        for callbackRegistration in currentRegisteredCallbacks {
            callbackRegistration.execute(reader: registeredReader, startEpochNanos: meterProviderSharedState.startEpochNanos, epochNanos: epochNanos)
        }
        var result = [StableMetricData]()

        if let storages = readerStorageRegisteries[registeredReader]?.getStorages() {
            for var storage in storages {
                let metricData = storage.collect(resource: meterProviderSharedState.resource, scope: instrumentationScope, startEpochNanos:     meterProviderSharedState.startEpochNanos, epochNanos:epochNanos)
                if !metricData.isEmpty() {
                    result.append(metricData)
                }
            }
        }
        return result
    }
}

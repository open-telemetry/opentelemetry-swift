/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public class MeterProviderError : Error {
}

public class StableMeterProviderSdk : StableMeterProvider {
    public func get(name: String) -> OpenTelemetryApi.StableMeter {
        meterBuilder(name: name).build()
    }
    
    public func meterBuilder(name: String) -> OpenTelemetryApi.MeterBuilder {
        if (registeredReaders.isEmpty) {
            // todo: noop meter provider builder

        }
        if name.isEmpty {
            // set default name
        }
        
        // todo : return meter builder
    }
    

    private let readerLock = Lock()
    var meterSharedState: StableMeterSharedState

    var defaultMeter : StableMeterSdk
    var registeredReaders = [RegisteredReader]()
    var registeredViews = [RegisteredView]()
    
    var componentRegistery : ComponentRegistry<StableMeterSdk>

    public static func builder() -> StableMeterProviderBuilder {
        return StableMeterProviderBuilder()
    }
    

    init(registeredViews: [RegisteredView], metricReaders: [StableMetricReader], clock: Clock, resource : Resource, exemplarFilter : ExemplarFilter) {
        let startEpochNano = Date().timeIntervalSince1970.toNanoseconds
        self.registeredViews = registeredViews
        self.registeredReaders = metricReaders.map { reader in
            return RegisteredReader(reader: reader, registry: StableViewRegistry(aggregationSelector: reader, registeredViews: registeredViews))
        }
    }



    public func shutdown() -> Bool {
        readerLock.lock()
        defer {
            readerLock.unlock()
        }
        do {
           try registeredReaders.forEach() { reader in
               guard reader.reader.shutdown() else {
                    //todo throw better error
                    throw MeterProviderError()
                }
            }
        } catch {
            return false
        }
        return true
    }

    public func forceFlush() -> Bool {
        readerLock.lock()
        defer {
            readerLock.unlock()
        }
       do {
           try registeredReaders.forEach() { reader in
               guard reader.reader.forceFlush() else {
                   //todo: throw better error
                   throw MeterProviderError()
               }
           }
       } catch {
            return false
        }
        return true
    }
//    public func addMetricReader(reader: StableMetricReaderBuilder) {
//        self.readerLock.lock()
//        defer {
//            self.readerLock.unlock()
//        }
//        registeredReaders.append(reader.build(sharedState: meterSharedState))
//    }


}


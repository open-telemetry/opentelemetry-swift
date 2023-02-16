/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public class MeterProviderError : Error {
}

public class StableMeterProviderSdk : StableMeterProvider {

    private let readerLock = Lock()
    var meterSharedState: StableMeterSharedState

    var defaultMeter : StableMeterSdk
    var registeredReaders = [StableMetricReader]()
    var registeredViews = [RegisteredView]()
    
    var componentRegistery : ComponentRegistry<StableMeterSdk>

    public static func builder() -> StableMeterProviderBuilder {
        return StableMeterProviderBuilder()
    }
    

    init(registeredViews: [RegisteredView], metricReaders: [StableMetricReader], clock: Clock, resource : Resource, exemplarFilter : ExemplarFilter) {
        let startEpochNano = Date().timeIntervalSince1970.toNanoseconds
        self.registeredViews = registeredViews
        self.registeredReaders = metricReaders.map { reader in
            return RegisteredReader(reader: reader, registry: StableViewRegistry(reader, registeredViews))
        }
    }



    public func shutdown() -> Bool {
        readerLock.lock()
        defer {
            readerLock.unlock()
        }
        do {
           try readers.forEach() { reader in
                guard reader.shutdown() else {
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
           try readers.forEach() { reader in
               guard reader.forceFlush() else {
                   //todo: throw better error
                   throw MeterProviderError()
               }
           }
       } catch {
            return false
        }
        return true
    }
    public func addMetricReader(reader: StableMetricReaderBuilder) {
        self.readerLock.lock()
        defer {
            self.readerLock.unlock()
        }
        readers.append(reader.build(sharedState: meterSharedState))
    }


}


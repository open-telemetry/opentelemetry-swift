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
    var readers = [StableMetricReaderSdk]()

    public convenience init() {
        self.init(readers: [])
    }

    public convenience init(reader: StableMetricReaderBuilder, resource: Resource = EnvVarResource.resource) {
        self.init(readers: [reader], resource: resource)
    }

    public init(readers: [StableMetricReaderBuilder], resource: Resource = EnvVarResource.resource) {

        meterSharedState = StableMeterSharedState(resource: resource)
        defaultMeter = StableMeterSdk(instrumentationLibraryInfo: InstrumentationLibraryInfo())
        readers.forEach() { builder in
            self.readers.append(builder.build(sharedState: meterSharedState))
        }
    }


    public func get(name: String, version: String?, schema: String?) -> StableMeter {
        if name.isEmpty {
            return defaultMeter
        }

        readerLock.lock()
        defer {
            readerLock.unlock()
        }
        let instrumentationLibraryInfo = InstrumentationLibraryInfo(name: name, version: version)
        var meter: StableMeterSdk! = meterSharedState.meterRegistry.first { meter in
            meter.instrumentationLibraryInfo == instrumentationLibraryInfo
        }
        if meter == nil {
            meter = StableMeterSdk(instrumentationLibraryInfo: instrumentationLibraryInfo)
            meterSharedState.add(meter: meter!)
        }
        return meter!
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


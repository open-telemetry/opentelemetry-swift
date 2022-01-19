//
// Created by Bryce Buchanan on 1/18/22.
//

import Foundation
import OpenTelemetryApi

public class StableMeterProviderSdk : StableMeterProvider {
    var meterSharedState: StableMeterSharedState

    public convenience init() {
        self.init(readers: [NoopStableMetricReader()])
    }

    public convenience init(reader: StableMetricReader, resource: Resource = EnvVarResource.resource) {
        self.init(readers: [reader], resource: resource)
    }

    public init(readers: [StableMetricReader],
                resource: Resource = EnvVarResource.resource) {
        meterSharedState = StableMeterSharedState(readers: readers, resource: resource)
    }


    public func get(name: String, version: String?, schema: String?) -> StableMeter {

    }

    public func shutdown() -> Bool {
        return false
    }

    public func forceFlush() {

    }
    public func addMetricReader(reader: StableMetricReader) {
        readers.append(reader)
    }


}


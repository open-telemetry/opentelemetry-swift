/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
public class StableMeterProviderBuilder {
    public private(set) var clock : Clock = MillisClock()
    public private(set) var resource : Resource = Resource()
    public private(set) var metricReaders = [StableMetricReader]()
    public private(set) var registeredViews = [RegisteredView]()
    public private(set) var exemplarFilter : ExemplarFilter = AlwaysOnFilter()

    public init() {
        
    }
    
    func setClock(clock : Clock) -> Self {
        self.clock = clock
        return self
    }

    func setResource(resource: Resource) -> Self {
        self.resource = resource
        return self
    }

    func registerView(selector : InstrumentSelector, view: StableView) -> Self {
        registerViews.append(RegisteredView(selector: selector, view: view))
        return self
    }

    func registerMetricReader(reader: StableMetricReader) -> Self {
        metricReaders.append(reader)
        return self
    }

    func build() -> StableMeterProviderSdk {

    }
}

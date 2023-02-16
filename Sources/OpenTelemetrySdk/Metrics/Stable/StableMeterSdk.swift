/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
class StableMeterSdk : StableMeter {
    func counterBuilder(name: String) -> OpenTelemetryApi.LongCounterBuilder {
        
    }
    
    func upDownCounterBuilder(name: String) -> OpenTelemetryApi.LongUpDownCounterBuilder {
        <#code#>
    }
    
    func histogramBuilder(name: String) -> OpenTelemetryApi.DoubleHistogramBuilder {
        <#code#>
    }
    
    func gaugeBuilder(name: String) -> OpenTelemetryApi.DoubleGaugeBuilder {
        <#code#>
    }
    
    fileprivate let collectLock = Lock()
    var instrumentationScopeInfo: InstrumentationScopeInfo

    var intCounters = [String: IntCounterSdk]()
    var doubleCounters = [String: DoubleCounterSdk]()
    var intObservableCounters = [String: IntObservableCounterSdk]()
    var doubleObservableCounter = [String: DoubleObservableCounterSdk]()

    // stub: maybe this doesn't throw, nor return metric data
    func collect() throws -> MetricData {
        return NoopMetricData()
    }

    init(instrumentationScopeInfo: InstrumentationScopeInfo) {
        self.instrumentationScopeInfo = instrumentationScopeInfo
    }

}

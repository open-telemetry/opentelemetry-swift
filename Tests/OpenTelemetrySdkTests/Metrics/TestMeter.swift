/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetrySdk
import XCTest

class TestMeter: MeterSdk {
    let collectAction: () -> Void

    init(meterSharedState: MeterSharedState, instrumentationScopeInfo: InstrumentationScopeInfo, collectAction: @escaping () -> Void) {
        
        self.collectAction = collectAction
        super.init(meterSharedState: meterSharedState, instrumentationScopeInfo: instrumentationScopeInfo)
    }

    override func collect() {
        collectAction()
    }
}

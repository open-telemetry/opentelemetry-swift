/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

class StableMeterSharedState {
    let meterLock = Lock()
    public private(set) var meterRegistry = [StableMeterSdk]()
    public private(set) var viewRegistry = StableViewRegistry()
    var resource: Resource

    init(resource: Resource) {
        self.resource = resource
    }

    func add(meter: StableMeterSdk) {
        meterLock.lock()
        defer{
            meterLock.unlock()
        }
        meterRegistry.append(meter)
    }
}
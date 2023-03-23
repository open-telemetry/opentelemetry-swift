/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public struct StablePeriodicMetricReaderBuilder {
    var exporter : StableMetricExporter
    var exporterInterval : TimeInterval  = 1.0
    var exportTimeout : TimeInterval

    func build(sharedState: StableMeterSharedState) -> StablePeriodicMetricReaderSdk {
        return StablePeriodicMetricReaderSdk(exporter: exporter,
                sharedState: sharedState,
                exportInterval: exporterInterval)
    }
}

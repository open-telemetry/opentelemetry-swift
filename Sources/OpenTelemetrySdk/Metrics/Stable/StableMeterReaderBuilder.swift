/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public struct StableMetricReaderBuilder {
    var exporter : MetricExporter
    var exporterInterval : TimeInterval
    var exportTimeout : TimeInterval

    func build(sharedState: StableMeterSharedState) -> StableMetricReaderSdk {
        return StableMetricReaderSdk(exporter: exporter,
                sharedState: sharedState,
                exportInterval: exporterInterval,
                exportTimeout: exportTimeout)
    }
}

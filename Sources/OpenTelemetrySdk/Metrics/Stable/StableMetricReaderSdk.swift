/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
class StableMetricReaderSdk : StableMetricReader{
    init(exporter: MetricExporter, exportInterval: TimeInterval = 60.0, exportTimeout: TimeInterval = 30.0) {

    }

    func collect() -> Bool {
        fatalError("collect() has not been implemented")
    }

    func shutdown() -> Bool {
        fatalError("shutdown() has not been implemented")
    }
}



/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class StableView {
    private var name : String
    private var description : String
    private var aggregationType : AggregationType
    init(name: String, description: String, aggregation: AggregationType) {
        self.name = name
        self.description = description
        self.aggregationType = aggregation
    }

}

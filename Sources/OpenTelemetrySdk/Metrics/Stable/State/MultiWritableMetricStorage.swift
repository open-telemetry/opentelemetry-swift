//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

struct MultiWritableMetricStorage : WritableMetricStorage {
    
    var storages : [WritableMetricStorage]
    
    init(storages: [WritableMetricStorage]) {
        self.storages = storages
    }
    
    mutating func recordLong(value: Int, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        for var storage in storages {
            storage.recordLong(value: value, attributes: attributes)
        }
    }
    
    mutating func recordDouble(value: Double, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        for var storage in storages {
            storage.recordDouble(value: value, attributes: attributes)
        }
    }
    
    
}

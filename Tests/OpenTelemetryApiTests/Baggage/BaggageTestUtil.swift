/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
@testable import OpenTelemetryApi

struct BaggageTestUtil {
    static func listToBaggage(entries: [Entry]) -> DefaultBaggage {
        let builder = DefaultBaggage.baggageBuilder()
        for entry in entries {
            builder.put(key: entry.key, value: entry.value, metadata: entry.metadata)
        }
        return builder.build() as! DefaultBaggage
    }
}

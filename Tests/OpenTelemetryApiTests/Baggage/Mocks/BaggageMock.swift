/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
@testable import OpenTelemetryApi

class BaggageMock: Baggage {
    static func baggageBuilder() -> BaggageBuilder {
        return EmptyBaggageBuilder()
    }

    func getEntries() -> [Entry] {
        return [Entry]()
    }

    func getEntryValue(key: EntryKey) -> EntryValue? {
        return nil
    }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

class EmptyBaggageBuilder: BaggageBuilder {
    func setParent(_ parent: Baggage?) -> Self {
        return self
    }

    func setNoParent() -> Self {
        return self
    }

    func put(key: EntryKey, value: EntryValue, metadata: EntryMetadata?) -> Self {
        return self
    }

    func remove(key: EntryKey) -> Self {
        return self
    }

    func build() -> Baggage {
        return EmptyBaggage.instance
    }

    init() {}
}

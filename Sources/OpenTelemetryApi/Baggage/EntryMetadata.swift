/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public struct EntryMetadata: Equatable {
    public var metadata: String

    public init?(metadata: String?) {
        guard let metadata = metadata?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
              metadata.count > 0 else {
            return nil
        }
        self.metadata = metadata
    }
}

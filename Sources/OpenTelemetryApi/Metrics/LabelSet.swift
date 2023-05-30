/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Normalized name value pairs of metric labels.
// Phase 2
//@available(*, deprecated, message: "LabelSet removed from Metric API in OTEP-90")
open class LabelSet: Hashable {
    public private(set) var labels: [String: String]

    /// Empty LabelSet.
    public static var empty = LabelSet()

    private init() {
        labels = [String: String]()
    }

    public required init(labels: [String: String]) {
        self.labels = labels
    }

    public static func == (lhs: LabelSet, rhs: LabelSet) -> Bool {
        return lhs.labels == rhs.labels
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(labels)
    }
}

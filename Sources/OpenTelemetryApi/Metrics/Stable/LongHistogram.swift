/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongHistogram {
    func record(value: Int)
    func record(value: Int, attributes: [String: AttributeValue])
}

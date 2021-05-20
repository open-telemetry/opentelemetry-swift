/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct ZipkinAnnotation: Encodable {
    var timestamp: UInt64
    var value: String
}

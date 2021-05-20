/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol ITelemetryDataSource {
    var version: String? { get }
    var name: String { get }
    var language: String { get }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol IOperatingSystemDataSource {
    var type: String { get }
    var description: String { get }
    var name: String { get }
    var version: String { get }
}

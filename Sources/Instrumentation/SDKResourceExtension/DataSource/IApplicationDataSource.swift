/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol IApplicationDataSource {
    var name: String? { get }
    var identifier: String? { get }
    var version: String? { get }
    var build: String? { get }
}

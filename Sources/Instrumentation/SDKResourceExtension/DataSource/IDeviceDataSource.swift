/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol IDeviceDataSource {
    var identifier: String? { get }
    var model: String? { get }
}

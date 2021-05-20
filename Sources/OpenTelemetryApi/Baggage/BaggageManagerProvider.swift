/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol BaggageManagerProvider {
    func create() -> BaggageManager
}

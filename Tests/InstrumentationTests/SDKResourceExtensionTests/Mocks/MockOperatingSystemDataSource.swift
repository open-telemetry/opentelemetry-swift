/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
@testable import ResourceExtension

class MockOperatingSystemDataSource: IOperatingSystemDataSource {
    private(set) var type: String
    private(set) var description: String

    init(type: String, description: String) {
        self.type = type
        self.description = description
    }
}

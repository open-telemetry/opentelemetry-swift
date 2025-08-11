/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
@testable import ResourceExtension

class MockOperatingSystemDataSource: IOperatingSystemDataSource {
  private(set) var type: String
  private(set) var description: String
  private(set) var name: String
  private(set) var version: String

  init(type: String, description: String, name: String, version: String) {
    self.type = type
    self.description = description
    self.name = name
    self.version = version
  }
}

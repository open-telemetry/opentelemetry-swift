/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
@testable import ResourceExtension

class MockTelemetryDataSource: ITelemetryDataSource {
  var version: String?
  var name: String
  var language: String

  init(name: String, language: String, version: String?) {
    self.version = version
    self.name = name
    self.language = language
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
@testable import ResourceExtension

class mockApplicationData: IApplicationDataSource {
  var name: String?
  var identifier: String?
  var version: String?
  var build: String?

  init(name: String? = nil, identifier: String? = nil, version: String? = nil, build: String? = nil) {
    self.name = name
    self.identifier = identifier
    self.version = version
    self.build = build
  }
}

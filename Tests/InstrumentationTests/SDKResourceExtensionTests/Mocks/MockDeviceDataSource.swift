/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
@testable import ResourceExtension

class MockDeviceDataSource: IDeviceDataSource {
  var identifier: String?
  var model: String?

  init(identifier: String?, model: String?) {
    self.identifier = identifier
    self.model = model
  }
}

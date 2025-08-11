/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import CoreMetrics

extension [(String, String)] {
  var dictionary: [String: String] {
    Dictionary(self, uniquingKeysWith: { lhs, _ in lhs })
  }
}

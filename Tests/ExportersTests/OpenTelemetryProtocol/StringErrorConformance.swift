/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

extension String: @retroactive Error {}
extension Swift.String: @retroactive LocalizedError {
  public var errorDescription: String? { return self }
}

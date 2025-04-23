/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Configuration for connecting to a Faro collector endpoint
struct FaroEndpointConfiguration {
  /// URL of the Faro collector endpoint
  let collectorUrl: URL

  /// API key for authentication with the Faro backend
  let apiKey: String

  /// Creates a new endpoint configuration
  /// - Parameters:
  ///   - collectorUrl: URL of the Faro collector endpoint
  ///   - apiKey: API key for authentication with the Faro backend
  init(collectorUrl: URL, apiKey: String) {
    self.collectorUrl = collectorUrl
    self.apiKey = apiKey
  }
}

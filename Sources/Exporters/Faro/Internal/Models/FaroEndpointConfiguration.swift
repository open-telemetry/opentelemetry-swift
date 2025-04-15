/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Configuration for connecting to a Faro backend endpoint
public struct FaroEndpointConfiguration {
    /// URL of the Faro collector endpoint
    public let collectorUrl: URL
    
    /// API key for authentication with the Faro backend
    public let apiKey: String
    
    /// Creates a new endpoint configuration
    /// - Parameters:
    ///   - collectorUrl: URL of the Faro collector endpoint
    ///   - apiKey: API key for authentication with the Faro backend
    public init(collectorUrl: URL, apiKey: String) {
        self.collectorUrl = collectorUrl
        self.apiKey = apiKey
    }
} 
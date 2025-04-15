/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

extension FaroEndpointConfiguration {
    /// Creates a FaroEndpointConfiguration instance from FaroExporterOptions
    /// - Parameter options: The exporter options containing endpoint information
    /// - Returns: A configured FaroEndpointConfiguration instance
    /// - Throws: An error if the API key cannot be extracted from the URL
    static func create(from options: FaroExporterOptions) throws -> FaroEndpointConfiguration {
        guard let url = URL(string: options.collectorUrl) else {
            throw FaroExporterError.invalidCollectorUrl
        }
        
        // The API key should be the last non-empty path component
        let pathComponents = url.pathComponents
            .filter { !$0.isEmpty && $0 != "/" }
        
        // Ensure we have at least one path component and it's not just "collect"
        guard !pathComponents.isEmpty,
              let apiKey = pathComponents.last,
              apiKey != "collect" else {
            throw FaroExporterError.missingApiKey
        }
        
        return FaroEndpointConfiguration(
            collectorUrl: url,
            apiKey: apiKey
        )
    }
} 
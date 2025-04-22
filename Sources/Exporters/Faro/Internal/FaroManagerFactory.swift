/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

/// Factory class responsible for creating and managing instances of FaroManager per unique configuration
final class FaroManagerFactory {
  // Dictionary to store FaroManager instances by their options
  private static var managers: [FaroExporterOptions: FaroManager] = [:]

  private init() {}

  /// Creates or returns a FaroManager instance for the provided options
  /// - Parameter options: Configuration options for the FaroManager
  /// - Returns: The FaroManager instance for these options
  /// - Throws: FaroExporterError if configuration is invalid
  static func getInstance(options: FaroExporterOptions) throws -> FaroManager {
    if let existingManager = managers[options] {
      return existingManager
    }

    // Create and validate endpoint configuration
    let endpointConfiguration = try FaroEndpointConfiguration.create(from: options)

    let sessionManager = FaroSessionManagerFactory.getInstance()
    let appInfo = FaroAppInfo.create(from: options)
    let transport = FaroTransport(endpointConfiguration: endpointConfiguration, sessionManager: sessionManager)

    let faroManager = FaroManager(appInfo: appInfo, transport: transport, sessionManager: sessionManager)
    managers[options] = faroManager
    return faroManager
  }
}

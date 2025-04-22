/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

/// Factory class responsible for creating and managing the singleton instance of FaroManager
final class FaroManagerFactory {
  private static var shared: FaroManager?

  private init() {}

  /// Creates or returns the shared instance of FaroManager
  /// - Parameter options: Configuration options for the FaroManager
  /// - Returns: The shared FaroManager instance
  /// - Throws: FaroExporterError if configuration is invalid
  static func getInstance(options: FaroExporterOptions) throws -> FaroManager {
    if let existingManager = shared {
      return existingManager
    }

    // Create and validate endpoint configuration
    let endpointConfiguration = try FaroEndpointConfiguration.create(from: options)

    let sessionManager = FaroSessionManagerFactory.getInstance()
    let appInfo = FaroAppInfo.create(from: options)
    let transport = FaroTransport(endpointConfiguration: endpointConfiguration, sessionManager: sessionManager)

    let faroManager = FaroManager(appInfo: appInfo, transport: transport, sessionManager: sessionManager)
    shared = faroManager
    return faroManager
  }
}

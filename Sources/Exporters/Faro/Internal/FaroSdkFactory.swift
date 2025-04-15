/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Factory class responsible for creating and managing the singleton instance of FaroSdk
final class FaroSdkFactory {
  private static var shared: FaroSdk?

  private init() {}

  /// Creates or returns the shared instance of FaroSdk
  /// - Parameter options: Configuration options for the FaroSdk
  /// - Returns: The shared FaroSdk instance
  /// - Throws: FaroExporterError if the collector URL is invalid or missing an API key
  static func getInstance(options: FaroExporterOptions) throws -> FaroSdk {
    if let existingSdk = shared {
      return existingSdk
    }

    // Create and validate endpoint configuration
    let endpointConfiguration = try FaroEndpointConfiguration.create(from: options)

    let appInfo = FaroAppInfo.create(from: options)
    let sessionManager = FaroSessionManager(dateProvider: DateProvider())
    let transport = FaroTransport(endpointConfiguration: endpointConfiguration, sessionManager: sessionManager)

    let sdk = FaroSdk(appInfo: appInfo, transport: transport)
    shared = sdk
    return sdk
  }
}

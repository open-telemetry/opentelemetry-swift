/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

extension FaroAppInfo {
  /// Creates a FaroAppInfo instance from FaroExporterOptions
  /// - Parameter options: The exporter options containing app information
  /// - Returns: A configured FaroAppInfo instance
  static func create(from options: FaroExporterOptions) -> FaroAppInfo {
    return FaroAppInfo(
      name: options.appName,
      namespace: nil,
      version: options.appVersion,
      environment: options.appEnvironment,
      bundleId: nil,
      release: nil
    )
  }
}

//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Configuration options for the Faro exporter
public struct FaroExporterOptions: Hashable {
  public let collectorUrl: String
  public let appName: String?
  public let appVersion: String?
  public let appEnvironment: String?
  public let namespace: String?

  public init(collectorUrl: String,
              appName: String? = nil,
              appVersion: String? = nil,
              appEnvironment: String? = nil,
              namespace: String? = nil) {
    self.collectorUrl = collectorUrl
    self.appName = appName
    self.appVersion = appVersion
    self.appEnvironment = appEnvironment
    self.namespace = namespace
  }
}

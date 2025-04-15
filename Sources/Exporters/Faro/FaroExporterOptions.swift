//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Configuration options for the Faro exporter
public struct FaroExporterOptions {
  public let collectorUrl: String
  public let appName: String?
  public let appVersion: String?
  public let appEnvironment: String?
  public let maxBatchSize: Int
  public let maxQueueSize: Int
  public let batchTimeout: TimeInterval

  public init(collectorUrl: String,
              appName: String? = nil,
              appVersion: String? = nil,
              appEnvironment: String? = nil,
              maxBatchSize: Int = 100,
              maxQueueSize: Int = 1000,
              batchTimeout: TimeInterval = 30.0) {
    self.collectorUrl = collectorUrl
    self.appName = appName
    self.appVersion = appVersion
    self.appEnvironment = appEnvironment
    self.maxBatchSize = maxBatchSize
    self.maxQueueSize = maxQueueSize
    self.batchTimeout = batchTimeout
  }
}

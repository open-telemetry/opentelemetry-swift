/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public enum CompressionType: Sendable {
  case gzip
  case deflate
  case none
}

public struct OtlpConfiguration: Sendable {
  public static let DefaultTimeoutInterval: TimeInterval = .init(10)

  /*
   * This is a first pass addition to satisfy the OTLP Configuration specification:
   * https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/protocol/exporter.md
   * It's possible to satisfy a few of these configuration options through the configuration of the GRPC channel
   * It's worth considering re-factoring the initialization of the OTLP exporters to collect all the configuration
   * in one locations.
   *
   * I've left several of the configuration options stubbed in comments, so that may be implemented in the future.
   */
  // let endpoint : URL? = URL(string: "https://localhost:4317")
  // let certificateFile
  // let compression
  /// Static headers included with every export when `headersProvider` is not set.
  public let headers: [(String, String)]?
  /// Returns the current headers immediately before each export.
  ///
  /// This callback is invoked synchronously and may be called concurrently. It should return
  /// cached credentials quickly rather than perform I/O. Callers must synchronize any mutable
  /// state captured by the callback. When set, it takes precedence over `headers`. Headers
  /// supplied through an exporter's `envVarHeaders` parameter retain their existing precedence.
  public let headersProvider: (@Sendable () -> [(String, String)]?)?
  public let timeout: TimeInterval
  public let compression: CompressionType
  public let exportAsJson: Bool
  public init(timeout: TimeInterval = OtlpConfiguration.DefaultTimeoutInterval,
              compression: CompressionType = .gzip,
              headers: [(String, String)]? = nil,
              exportAsJson: Bool = true,
              headersProvider: (@Sendable () -> [(String, String)]?)? = nil) {
    self.headers = headers
    self.headersProvider = headersProvider
    self.timeout = timeout
    self.compression = compression
    self.exportAsJson = exportAsJson
  }

  /// Returns the headers to include in the next export.
  ///
  /// When a provider is configured, its result takes precedence over static headers, including
  /// when the provider returns `nil`.
  public func headersForExport() -> [(String, String)]? {
    if let headersProvider {
      return headersProvider()
    }
    return headers
  }
}

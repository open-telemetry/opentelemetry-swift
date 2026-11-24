/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if OTLPGRPC

import Foundation
import GRPCCore
import OpenTelemetryProtocolExporterCommon

let maximumDeadlineSeconds = TimeInterval(Int32.max)

/// Builds the metadata for an export call, reading dynamic headers immediately before the call.
///
/// Header names are lowercased because HTTP/2 requires lowercase names.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
func makeOtlpGrpcMetadata(config: OtlpConfiguration,
                          envVarHeaders: [(String, String)]?) -> Metadata {
  var metadata = Metadata()
  for (name, value) in envVarHeaders ?? config.headersForExport() ?? [] {
    metadata.addString(value, forKey: name.lowercased())
  }
  metadata.replaceOrAddString(Headers.getUserAgentHeader(), forKey: Constants.HTTP.userAgent.lowercased())
  return metadata
}

/// The timeout of an export call, or `nil` to set no deadline of its own.
///
/// A timeout that is zero or negative sets no exporter deadline, so only a timeout the
/// transport configures applies.
func otlpGrpcExportTimeout(config: OtlpConfiguration, explicitTimeout: TimeInterval?) -> TimeInterval? {
  let timeout = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, config.timeout)
  guard timeout > 0, timeout < maximumDeadlineSeconds else {
    return nil
  }
  return timeout
}

/// Builds the call options for an export call.
///
/// A timeout that is zero or negative sets no exporter deadline, so only a timeout the
/// transport configures applies.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
func makeOtlpGrpcCallOptions(config: OtlpConfiguration,
                             explicitTimeout: TimeInterval?) -> CallOptions {
  var options = CallOptions.defaults
  if let timeout = otlpGrpcExportTimeout(config: config, explicitTimeout: explicitTimeout) {
    options.timeout = .seconds(timeout)
  }
  switch config.compression {
  case .gzip:
    options.compression = .gzip
  case .deflate:
    options.compression = .deflate
  case .none:
    options.compression = CompressionAlgorithm.none
  }
  return options
}

#endif

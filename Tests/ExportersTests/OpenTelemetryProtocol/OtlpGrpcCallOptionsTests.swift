/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if OTLPGRPC

import Foundation
import GRPCCore
import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetryProtocolExporterGrpc
import XCTest

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
final class OtlpGrpcCallOptionsTests: XCTestCase {
  func testMetadataUsesEnvVarHeadersFirst() {
    let metadata = makeOtlpGrpcMetadata(
      config: OtlpConfiguration(headers: [("x-k", "c")]),
      envVarHeaders: [("x-k", "env")]
    )

    XCTAssertEqual(Array(metadata[stringValues: "x-k"]), ["env"])
    XCTAssertEqual(Array(metadata[stringValues: "user-agent"]), [Headers.getUserAgentHeader()])
  }

  func testMetadataEvaluatesHeadersProvider() {
    let metadata = makeOtlpGrpcMetadata(
      config: OtlpConfiguration(headersProvider: { [("authorization", "Bearer a")] }),
      envVarHeaders: nil
    )

    XCTAssertEqual(Array(metadata[stringValues: "authorization"]), ["Bearer a"])
  }

  func testNilHeadersProviderSendsOnlyUserAgent() {
    let metadata = makeOtlpGrpcMetadata(
      config: OtlpConfiguration(headersProvider: { nil }),
      envVarHeaders: nil
    )

    XCTAssertEqual(metadata.count, 1)
    XCTAssertEqual(metadata[metadata.startIndex].key, "user-agent")
  }

  func testCallOptionsTimeoutIsMinOfExplicitAndConfig() {
    let options = makeOtlpGrpcCallOptions(
      config: OtlpConfiguration(timeout: 10),
      explicitTimeout: 2
    )

    XCTAssertEqual(options.timeout, .seconds(2))
  }

  func testZeroTimeoutSetsNoDeadline() {
    let options = makeOtlpGrpcCallOptions(
      config: OtlpConfiguration(timeout: 0),
      explicitTimeout: nil
    )

    XCTAssertNil(options.timeout)
  }

  func testCompressionMapping() {
    XCTAssertEqual(
      makeOtlpGrpcCallOptions(config: OtlpConfiguration(compression: .gzip), explicitTimeout: nil).compression,
      .gzip
    )
    XCTAssertEqual(
      makeOtlpGrpcCallOptions(config: OtlpConfiguration(compression: .deflate), explicitTimeout: nil).compression,
      .deflate
    )
    XCTAssertEqual(
      makeOtlpGrpcCallOptions(config: OtlpConfiguration(compression: .none), explicitTimeout: nil).compression,
      CompressionAlgorithm.none
    )
  }
}

#endif

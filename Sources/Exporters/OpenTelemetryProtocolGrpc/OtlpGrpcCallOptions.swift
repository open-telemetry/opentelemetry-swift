/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import GRPC
import NIOHPACK
import OpenTelemetryProtocolExporterCommon

/// Rebuilds export metadata while preserving the other base call options.
///
/// The base options' `customMetadata` is intentionally replaced so dynamic headers are read
/// immediately before each export.
func makeOtlpGrpcCallOptions(from baseCallOptions: CallOptions,
                             config: OtlpConfiguration,
                             envVarHeaders: [(String, String)]?,
                             additionalHeaders: [(String, String)] = []) -> CallOptions {
  var callOptions = baseCallOptions
  var headers = envVarHeaders ?? config.headersForExport() ?? []
  headers.append(contentsOf: additionalHeaders)
  callOptions.customMetadata = HPACKHeaders(headers)
  return callOptions
}

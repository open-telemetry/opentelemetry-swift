/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import GRPC
import NIOHPACK
import OpenTelemetryProtocolExporterCommon

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

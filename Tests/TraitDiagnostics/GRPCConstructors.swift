/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryProtocolExporterGrpc

/// The disabled trait must explain how to enable gRPC without requiring GRPCClient.
func checkExporters() {
  _ = OtlpTraceExporter(client: 0)
  _ = OtlpMetricExporter(transport: 0)
  _ = OtlpLogExporter(client: 0)
}

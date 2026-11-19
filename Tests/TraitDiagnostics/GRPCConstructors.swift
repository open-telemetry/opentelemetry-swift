/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryProtocolExporterGrpc

/// The disabled trait must explain how to enable gRPC without requiring GRPCChannel.
func checkExporters(channel: Any) {
  _ = OtlpTraceExporter(channel: channel)
  _ = OtlpMetricExporter(channel: channel)
  _ = OtlpLogExporter(channel: channel)
}

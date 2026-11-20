#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
unset OTEL_SWIFT_ENABLE_ALL_TRAITS

swift build --disable-default-traits --target OpenTelemetryProtocolExporterGrpcSwift1
BUILD_PATH="$(swift build --disable-default-traits --show-bin-path)"
DIAGNOSTICS="$(mktemp)"
trap 'rm -f "$DIAGNOSTICS"' EXIT

if swiftc -typecheck -I "$BUILD_PATH/Modules" -I "$BUILD_PATH" \
  Tests/TraitDiagnostics/GRPCConstructors.swift >"$DIAGNOSTICS" 2>&1; then
  echo "error: gRPC exporters compiled without the OTLPGRPCSwift1 trait" >&2
  exit 1
fi

for exporter in OtlpTraceExporter OtlpMetricExporter OtlpLogExporter; do
  if ! grep -Fq "error: '$exporter' is unavailable: OpenTelemetryProtocolExporterGrpcSwift1 requires the \`OTLPGRPCSwift1\` package trait." "$DIAGNOSTICS"; then
    cat "$DIAGNOSTICS" >&2
    echo "error: $exporter(channel:) did not explain the missing trait" >&2
    exit 1
  fi
done

echo "gRPC constructor diagnostics passed"

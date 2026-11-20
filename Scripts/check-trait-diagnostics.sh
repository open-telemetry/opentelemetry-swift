#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
unset OTEL_SWIFT_ENABLE_ALL_TRAITS

DIAGNOSTICS="$(mktemp)"
trap 'rm -f "$DIAGNOSTICS"' EXIT

# check_diagnostics <module> <product> <trait> <source> <label>
check_diagnostics() {
  local module="$1" product="$2" trait="$3" source="$4" label="$5"

  swift build --disable-default-traits --target "$module"
  local build_path
  build_path="$(swift build --disable-default-traits --show-bin-path)"

  if swiftc -typecheck -I "$build_path/Modules" -I "$build_path" \
    "$source" >"$DIAGNOSTICS" 2>&1; then
    echo "error: gRPC exporters compiled without the $trait trait" >&2
    exit 1
  fi

  for exporter in OtlpTraceExporter OtlpMetricExporter OtlpLogExporter; do
    if ! grep -Fq "error: '$exporter' is unavailable: $product requires the \`$trait\` package trait." "$DIAGNOSTICS"; then
      cat "$DIAGNOSTICS" >&2
      echo "error: $exporter($label) did not explain the missing trait" >&2
      exit 1
    fi
  done
}

check_diagnostics OpenTelemetryProtocolExporterGrpc OpenTelemetryProtocolExporter OTLPGRPC \
  Tests/TraitDiagnostics/GRPCConstructors.swift "client: or transport:"
check_diagnostics OpenTelemetryProtocolExporterGrpcSwift1 OpenTelemetryProtocolExporterGrpcSwift1 OTLPGRPCSwift1 \
  Tests/TraitDiagnostics/GRPCSwift1Constructors.swift "channel:"

echo "gRPC constructor diagnostics passed"

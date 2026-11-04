#!/bin/bash
set -euo pipefail

# Checks that SwiftPM leaves out the dependencies of disabled package traits.
#
# Tests/TraitPruning is a consumer package that depends on this package by path and
# only uses OpenTelemetryProtocolExporterHTTP. For each mode below, the script builds
# it and reads the resolved package identities from `swift package show-dependencies`:
#
# - default traits: none of the optional integrations' packages may appear;
# - only the Prometheus trait: swift-nio appears, the other traits' packages don't.
#
# Usage: Scripts/check-trait-pruning.sh

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$PROJECT_ROOT/Tests/TraitPruning"

log() { echo "==> $*"; }

identities() {
  swift package --package-path "$FIXTURE" show-dependencies --format json \
    | grep -o '"identity" *: *"[^"]*"' \
    | sed 's/.*"\([^"]*\)"$/\1/' \
    | sort -u
}

# check_mode <label> <must-be-absent> <must-be-present>; both lists are space-separated.
check_mode() {
  local label="$1" absent="$2" present="$3"
  log "Building Tests/TraitPruning ($label)"
  swift build --package-path "$FIXTURE"

  local found failed=0
  found="$(identities)"
  for identity in $absent; do
    if grep -qx "$identity" <<<"$found"; then
      echo "error: $label: '$identity' is resolved but its trait is disabled" >&2
      failed=1
    fi
  done
  for identity in $present; do
    if ! grep -qx "$identity" <<<"$found"; then
      echo "error: $label: '$identity' is missing" >&2
      failed=1
    fi
  done
  if [[ $failed -ne 0 ]]; then
    echo "Resolved packages ($label):" >&2
    echo "$found" >&2
    exit 1
  fi
  log "$label: OK"
}

unset TRAIT_PRUNING_TRAITS
check_mode "default traits" \
  "grpc-swift swift-nio swift-nio-http2 swift-nio-ssl swift-nio-transport-services swift-nio-extras thrift-swift opentracing-objc kscrash swift-log swift-metrics swift-distributed-tracing" \
  "swift-protobuf"

export TRAIT_PRUNING_TRAITS=Prometheus
check_mode "Prometheus trait" \
  "grpc-swift thrift-swift kscrash" \
  "swift-nio"

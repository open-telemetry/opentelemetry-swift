#!/bin/bash
set -euo pipefail

# Builds the package with every package trait configuration that matters:
#
# 1. no traits (also the default set): build with tests and run the tests;
# 2. all traits: build with tests (the regular CI jobs run these tests);
# 3. each trait on its own: build with tests.
#
# The trait list comes from the manifest, so new traits are covered automatically.
# Adapted from swift-configuration's Scripts/test-traits.sh.
#
# Usage: Scripts/test-traits.sh

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

log() { echo "==> $*"; }

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required" >&2
  exit 1
fi

# The manifest enables every trait by default when this is set; the matrix needs the real default set.
unset OTEL_SWIFT_ENABLE_ALL_TRAITS

TRAITS=()
while IFS= read -r trait; do
  TRAITS+=("$trait")
done < <(swift package dump-package | jq -r '[.traits[] | select(.name != "default") | .name] | sort[]')

if [[ ${#TRAITS[@]} -eq 0 ]]; then
  echo "error: no traits found in the manifest" >&2
  exit 1
fi
log "Traits: ${TRAITS[*]}"

log "No traits: build with tests"
swift build --build-tests --disable-default-traits
log "No traits: test"
swift test --disable-default-traits

log "All traits: build with tests"
swift build --build-tests --enable-all-traits

for trait in "${TRAITS[@]}"; do
  log "Trait $trait: build with tests"
  swift build --build-tests --disable-default-traits --traits "$trait"
done

log "All trait configurations passed"

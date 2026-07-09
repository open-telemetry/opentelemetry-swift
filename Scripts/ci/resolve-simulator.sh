#!/bin/bash
set -euo pipefail

# Resolves the UDID of an available simulator for a given platform.
# Picks the first device from the newest available runtime.
#
# Usage: ./Scripts/ci/resolve-simulator.sh <platform>
#   platform: iOS, tvOS, watchOS, visionOS
#
# Output: prints the UDID to stdout

PLATFORM="${1:?Usage: $0 <platform> (iOS|tvOS|watchOS|visionOS)}"

UDID=$(xcrun simctl list devices "$PLATFORM" available -j \
  | jq -r '.devices | to_entries | sort_by(.key) | reverse | map(select(.value | length > 0)) | first | .value | first | .udid')

if [[ -z "$UDID" || "$UDID" == "null" ]]; then
  echo "Error: no available $PLATFORM simulator found" >&2
  exit 1
fi

echo "$UDID"

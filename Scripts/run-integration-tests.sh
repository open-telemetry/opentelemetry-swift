#!/bin/bash
set -euo pipefail

# Integration test runner.
#
# 1. Starts a local OTLP/HTTP collector that dumps everything it receives to
#    Tests/IntegrationTests/out/{traces,logs}.jsonl. By default this is the
#    Swift OTLPMockCollector from Tests/IntegrationTests; pass --collector docker
#    to use the OpenTelemetry Collector via Tests/IntegrationTests/compose.yaml
#    instead.
# 2. Builds Examples/HackerNewsDemo for the iOS simulator, installs it and
#    launches it with --integrationTestMode so it emits a fixed telemetry set.
# 3. Waits for the completion marker to reach the collector.
# 4. Runs the assertions in Tests/IntegrationTests against the dumped files.
#
# Usage: Scripts/run-integration-tests.sh [--simulator <udid>] [--collector swift|docker]
#                                         [--port <port>] [--timeout <seconds>] [--skip-build]

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTEGRATION_DIR="$PROJECT_ROOT/Tests/IntegrationTests"
OUTPUT_DIR="$INTEGRATION_DIR/out"
DERIVED_DATA="${DERIVED_DATA:-$INTEGRATION_DIR/.derivedData}"
APP_PROJECT="$PROJECT_ROOT/Examples/HackerNewsDemo/HackerNewsDemo.xcodeproj"
APP_SCHEME="HackerNewsDemo"
APP_BUNDLE_ID="io.opentelemetry.HackerNewsDemo"
COMPLETION_MARKER="integration.test.complete"

SIMULATOR_UDID=""
COLLECTOR="swift"
PORT=4318
TIMEOUT=120
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --simulator) SIMULATOR_UDID="$2"; shift 2 ;;
    --collector) COLLECTOR="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --skip-build) SKIP_BUILD=true; shift ;;
    -h|--help)
      sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option $1" >&2; exit 1 ;;
  esac
done

if [[ "$COLLECTOR" != "swift" && "$COLLECTOR" != "docker" ]]; then
  echo "--collector must be 'swift' or 'docker'" >&2
  exit 1
fi

log() { echo "==> $*"; }

pipe_output() {
  if command -v xcbeautify >/dev/null 2>&1; then xcbeautify; else cat; fi
}

COLLECTOR_PID=""
cleanup() {
  log "Cleaning up"
  xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  if [[ -n "$COLLECTOR_PID" ]]; then
    kill "$COLLECTOR_PID" >/dev/null 2>&1 || true
  fi
  if [[ "$COLLECTOR" == "docker" ]]; then
    docker compose -f "$INTEGRATION_DIR/compose.yaml" down >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID="$("$PROJECT_ROOT/Scripts/ci/resolve-simulator.sh" iOS)"
fi
log "Using simulator $SIMULATOR_UDID"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

if [[ "$COLLECTOR" == "swift" ]]; then
  log "Building OTLPMockCollector"
  swift build --package-path "$INTEGRATION_DIR" --product OTLPMockCollector 2>&1 | grep -v "warning:" || true
  COLLECTOR_BIN="$(swift build --package-path "$INTEGRATION_DIR" --product OTLPMockCollector --show-bin-path)/OTLPMockCollector"
  log "Starting OTLPMockCollector on port $PORT"
  "$COLLECTOR_BIN" --port "$PORT" --output-dir "$OUTPUT_DIR" &
  COLLECTOR_PID=$!
else
  log "Starting OpenTelemetry Collector via docker compose"
  OTEL_INTEGRATION_OUTPUT_DIR="$OUTPUT_DIR" OTEL_INTEGRATION_PORT="$PORT" \
    docker compose -f "$INTEGRATION_DIR/compose.yaml" up -d
fi

log "Waiting for collector"
for _ in $(seq 1 30); do
  if curl -fs "http://localhost:$PORT/health" >/dev/null 2>&1 \
     || curl -s -o /dev/null -w '%{http_code}' -X POST "http://localhost:$PORT/v1/traces" -H 'Content-Type: application/json' -d '{}' | grep -q 200; then
    break
  fi
  sleep 1
done

if [[ "$SKIP_BUILD" == false ]]; then
  log "Building $APP_SCHEME for the simulator"
  set -o pipefail
  xcodebuild \
    -project "$APP_PROJECT" \
    -scheme "$APP_SCHEME" \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    build | pipe_output
fi
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/$APP_SCHEME.app"
[[ -d "$APP_PATH" ]] || { echo "App not found at $APP_PATH" >&2; exit 1; }

log "Booting simulator"
xcrun simctl boot "$SIMULATOR_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIMULATOR_UDID" -b

log "Installing and launching $APP_BUNDLE_ID"
xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
SIMCTL_CHILD_OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:$PORT" \
  xcrun simctl launch "$SIMULATOR_UDID" "$APP_BUNDLE_ID" --integrationTestMode

log "Waiting up to ${TIMEOUT}s for telemetry"
deadline=$((SECONDS + TIMEOUT))
until grep -qs "$COMPLETION_MARKER" "$OUTPUT_DIR/traces.jsonl" && [[ -s "$OUTPUT_DIR/logs.jsonl" ]]; do
  if (( SECONDS >= deadline )); then
    echo "Timed out waiting for '$COMPLETION_MARKER' in $OUTPUT_DIR/traces.jsonl" >&2
    ls -la "$OUTPUT_DIR" >&2 || true
    exit 1
  fi
  sleep 1
done
# Logs are batched on a fixed 5s schedule; give the last batch time to land.
sleep 6

log "Collected files"
ls -la "$OUTPUT_DIR"

log "Running assertions"
OTEL_INTEGRATION_OUTPUT_DIR="$OUTPUT_DIR" swift test --package-path "$INTEGRATION_DIR" 2>&1 | grep -v "warning:"

log "Integration tests passed"

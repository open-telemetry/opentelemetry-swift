#!/bin/bash
set -euo pipefail

# Integration test runner.
#
# 1. Downloads a pinned OpenTelemetry Collector release (the core `otelcol`
#    distribution, ~30 MB) into Tests/IntegrationTests/.collector, verifying
#    its sha256, and builds the small status server from Tests/IntegrationTests.
# 2. Builds Examples/HackerNewsDemo for the iOS simulator and installs it.
# 3. Launches the app once per session-config case with --integrationTestMode
#    (see IntegrationTestScenario.Launch). For each launch the collector is
#    started with Tests/IntegrationTests/collector.yaml, receiving OTLP/HTTP on
#    $PORT and writing length-prefixed OTLP protobuf to Tests/IntegrationTests/out/<launch>/.
#    The status server on $STATUS_PORT answers the app's GET /status/<code>
#    requests so the URLSession spans have predictable status codes.
# 4. Runs the assertions in Tests/IntegrationTests against the dumped files.
#
# Usage: Scripts/run-integration-tests.sh [--simulator <udid>] [--port <port>]
#                                         [--status-port <port>] [--timeout <seconds>]
#                                         [--build-only | --skip-build]
#
# --build-only builds the demo app into $DERIVED_DATA and exits; --skip-build
# reuses that build. CI runs them as two steps so the DerivedData can be cached.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTEGRATION_DIR="$PROJECT_ROOT/Tests/IntegrationTests"
OUTPUT_DIR="$INTEGRATION_DIR/out"
DERIVED_DATA="${DERIVED_DATA:-$INTEGRATION_DIR/.derivedData}"
APP_PROJECT="$PROJECT_ROOT/Examples/HackerNewsDemo/HackerNewsDemo.xcodeproj"
APP_SCHEME="HackerNewsDemo"
APP_BUNDLE_ID="io.opentelemetry.HackerNewsDemo"
COMPLETION_MARKER="integration.test.complete"

# Pinned collector release. Bump the version and both checksums together; the
# checksums are the published <asset>.sha256 files from
# https://github.com/open-telemetry/opentelemetry-collector-releases/releases
COLLECTOR_VERSION="0.160.0"
COLLECTOR_SHA256_ARM64="a56143a40a2c205cdd63da4af0249f2534691785c14cdd2a0c532becb4335521"
COLLECTOR_SHA256_AMD64="480fcb29a9fc3f54da661166f7eb40677d4230198123759220255acc5cf35130"
COLLECTOR_CACHE_DIR="${OTEL_INTEGRATION_COLLECTOR_DIR:-$INTEGRATION_DIR/.collector}"

SIMULATOR_UDID=""
PORT=4318
STATUS_PORT=4319
TIMEOUT=120
SKIP_BUILD=false
BUILD_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --simulator) SIMULATOR_UDID="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --status-port) STATUS_PORT="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --skip-build) SKIP_BUILD=true; shift ;;
    --build-only) BUILD_ONLY=true; shift ;;
    -h|--help)
      sed -n '3,23p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option $1" >&2; exit 1 ;;
  esac
done

log() { echo "==> $*"; }

pipe_output() {
  if command -v xcbeautify >/dev/null 2>&1; then xcbeautify; else cat; fi
}

COLLECTOR_PID=""
STATUS_PID=""
cleanup() {
  log "Cleaning up"
  xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  for pid in "$COLLECTOR_PID" "$STATUS_PID"; do
    if [[ -n "$pid" ]]; then
      kill "$pid" >/dev/null 2>&1 || true
    fi
  done
}
trap cleanup EXIT

if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID="$("$PROJECT_ROOT/Scripts/ci/resolve-simulator.sh" iOS)"
fi
log "Using simulator $SIMULATOR_UDID"

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
if [[ "$BUILD_ONLY" == true ]]; then
  log "Built $APP_PATH"
  exit 0
fi

# Fetches the pinned otelcol release for this machine's architecture into the
# cache dir (idempotent) and prints the binary path.
ensure_collector() {
  local arch sha
  case "$(uname -m)" in
    arm64|aarch64) arch="arm64"; sha="$COLLECTOR_SHA256_ARM64" ;;
    x86_64) arch="amd64"; sha="$COLLECTOR_SHA256_AMD64" ;;
    *) echo "Unsupported architecture $(uname -m)" >&2; exit 1 ;;
  esac
  local dir="$COLLECTOR_CACHE_DIR/$COLLECTOR_VERSION-darwin-$arch"
  local bin="$dir/otelcol"
  if [[ ! -x "$bin" ]]; then
    local asset="otelcol_${COLLECTOR_VERSION}_darwin_${arch}.tar.gz"
    local url="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${COLLECTOR_VERSION}/${asset}"
    log "Downloading OpenTelemetry Collector $COLLECTOR_VERSION ($arch)" >&2
    mkdir -p "$dir"
    curl -fsSL --retry 3 -o "$dir/$asset" "$url"
    if ! echo "$sha  $dir/$asset" | shasum -a 256 -c - >/dev/null; then
      echo "Checksum mismatch for $asset" >&2
      rm -f "$dir/$asset"
      exit 1
    fi
    tar -xzf "$dir/$asset" -C "$dir" otelcol
    rm -f "$dir/$asset"
  fi
  echo "$bin"
}

wait_for_http() {
  local url="$1" expected="$2"
  for _ in $(seq 1 30); do
    if [[ "$(curl -s -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)" == "$expected" ]]; then
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for $url to return $expected" >&2
  exit 1
}

COLLECTOR_BIN="$(ensure_collector)"
log "Using $("$COLLECTOR_BIN" --version)"

log "Building IntegrationStatusServer"
swift build --package-path "$INTEGRATION_DIR" --product IntegrationStatusServer 2>&1 | grep -v "warning:" || true
STATUS_BIN="$(swift build --package-path "$INTEGRATION_DIR" --product IntegrationStatusServer --show-bin-path)/IntegrationStatusServer"
"$STATUS_BIN" --port "$STATUS_PORT" &
STATUS_PID=$!
wait_for_http "http://localhost:$STATUS_PORT/health" 200

# Each app launch gets its own output directory, so the collector is restarted
# per launch pointing at that directory.
start_collector() {
  local dir="$1"
  mkdir -p "$dir"
  OTEL_INTEGRATION_OUTPUT_DIR="$dir" OTEL_INTEGRATION_PORT="$PORT" \
    "$COLLECTOR_BIN" --config "$INTEGRATION_DIR/collector.yaml" >"$dir/collector.log" 2>&1 &
  COLLECTOR_PID=$!
  # The OTLP receiver answers GET on its POST-only route with 405 once it is up.
  wait_for_http "http://localhost:$PORT/v1/traces" 405
}

stop_collector() {
  if [[ -n "$COLLECTOR_PID" ]]; then
    kill "$COLLECTOR_PID" >/dev/null 2>&1 || true
    wait "$COLLECTOR_PID" 2>/dev/null || true
    COLLECTOR_PID=""
  fi
}

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

log "Booting simulator"
xcrun simctl boot "$SIMULATOR_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIMULATOR_UDID" -b

log "Installing $APP_BUNDLE_ID"
xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"

# run_launch <tag> [extra launch arguments...]
# Launches the app once with --integrationLaunch <tag>, collecting into
# $OUTPUT_DIR/<tag>. The app stays installed between launches so persisted
# session state carries over, which the restore launches depend on.
run_launch() {
  local tag="$1"; shift
  local dir="$OUTPUT_DIR/$tag"
  start_collector "$dir"
  log "Launch '$tag' ($*)"
  SIMCTL_CHILD_OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:$PORT" \
  SIMCTL_CHILD_INTEGRATION_STATUS_BASE_URL="http://localhost:$STATUS_PORT" \
    xcrun simctl launch "$SIMULATOR_UDID" "$APP_BUNDLE_ID" --integrationTestMode --integrationLaunch "$tag" "$@"

  local deadline=$((SECONDS + TIMEOUT))
  until grep -aqs "$COMPLETION_MARKER" "$dir/traces.pb"; do
    if (( SECONDS >= deadline )); then
      echo "Timed out waiting for '$COMPLETION_MARKER' in $dir/traces.pb" >&2
      ls -la "$dir" >&2 || true
      cat "$dir/collector.log" >&2 || true
      exit 1
    fi
    sleep 1
  done
  # Logs are batched on a fixed 5s schedule; give the last batch time to land.
  sleep 6
  xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  stop_collector
}

# Keep the tags and session configs in sync with IntegrationTestScenario.Launch
# and Tests/IntegrationTests/Assertions/SessionConfigTests.swift.
run_launch main
run_launch max-lifetime --sessionTimeout 60 --maxLifetime 3
run_launch restore-first --sessionTimeout 60 --restorePersistedSession true
run_launch restore-second --sessionTimeout 60 --restorePersistedSession true
run_launch no-restore --sessionTimeout 60 --restorePersistedSession false

log "Collected files"
ls -la "$OUTPUT_DIR"/*

log "Running assertions"
OTEL_INTEGRATION_OUTPUT_DIR="$OUTPUT_DIR" swift test --package-path "$INTEGRATION_DIR" 2>&1 | grep -v "warning:"

log "Integration tests passed"

#!/bin/bash
set -euo pipefail

# Starts the collector stack in this directory: an OpenTelemetry Collector
# receiving OTLP on 4317/4318, forwarding to grafana/otel-lgtm (Grafana on
# http://localhost:3000 with the HackerNewsDemo dashboard).
#
# Usage: Examples/GrafanaDashboard/run.sh [up | down | logs | reset]
#
# up (the default) starts the stack in the background and opens Grafana. down
# stops it, logs follows the Grafana container's output, and reset stops it and
# deletes the stored telemetry.

DASHBOARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$DASHBOARD_DIR/docker-compose.yaml"
GRAFANA_URL="http://localhost:3000"

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

case "${1:-up}" in
  up)
    compose up -d
    echo "Grafana: $GRAFANA_URL (first start can take a minute while plugins install)"
    if command -v open >/dev/null 2>&1; then
      open "$GRAFANA_URL"
    fi
    ;;
  down)
    compose down
    ;;
  logs)
    compose logs -f lgtm
    ;;
  reset)
    compose down --volumes
    ;;
  *)
    echo "Usage: $0 [up | down | logs | reset]" >&2
    exit 1
    ;;
esac

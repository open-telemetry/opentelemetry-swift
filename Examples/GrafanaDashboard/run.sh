#!/bin/bash
set -euo pipefail

# Starts the collector stack in this directory: an OpenTelemetry Collector
# receiving OTLP on 4317/4318, forwarding to grafana/otel-lgtm (Grafana on
# http://localhost:3000 with the HackerNewsDemo dashboard).
#
# Usage: Examples/GrafanaDashboard/run.sh [up | down | logs]
#
# up (the default) creates the external signoz-network if it is missing, starts
# the stack in the background and opens Grafana. down stops it, logs follows
# the Grafana container's output.

DASHBOARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$DASHBOARD_DIR/docker-compose.yaml"
GRAFANA_URL="http://localhost:3000"

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

case "${1:-up}" in
  up)
    docker network inspect signoz-network >/dev/null 2>&1 \
      || docker network create signoz-network >/dev/null
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
  *)
    echo "Usage: $0 [up | down | logs]" >&2
    exit 1
    ;;
esac

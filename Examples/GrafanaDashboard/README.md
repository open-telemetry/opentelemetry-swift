# Grafana Dashboard

A local Grafana view for the telemetry sent by [`HackerNewsDemo`](../HackerNewsDemo). It runs with Docker Compose:

- `collector`: an OpenTelemetry Collector that receives OTLP on `4317` (gRPC) and `4318` (HTTP), which is where the demo app exports. It forwards everything to `lgtm`, and also to SigNoz's ingester on the external `signoz-network`.
- `lgtm`: [`grafana/otel-lgtm`](https://github.com/grafana/docker-otel-lgtm) (Grafana with Tempo, Loki and Prometheus). Grafana is on http://localhost:3000.

## Usage

From the repo root:

```sh
Examples/GrafanaDashboard/run.sh          # start the stack and open Grafana
Examples/GrafanaDashboard/run.sh logs     # follow Grafana's logs
Examples/GrafanaDashboard/run.sh down     # stop the stack
```

Or from this directory: `make` (same as `make up`), `make logs`, `make down`.

Then run the `HackerNewsDemo` app and open the **HackerNewsDemo** dashboard. The first start can take a minute while Grafana installs the echarts panel plugin.

## Files

- `docker-compose.yaml`: the two services.
- `collector-config.yaml`: the collector's OTLP receivers and exporters.
- `otelcol-event-name.yaml`: merged over `otel-lgtm`'s built-in collector config. It copies each log record's `event_name` into the `event.name` attribute, because Loki drops the OTLP field.
- `grafana/hackernews-demo.json`: the HackerNewsDemo dashboard.
- `grafana/dashboards.yaml`: provisions the dashboard alongside the image's own.
- `grafana/datasources.yaml`: replaces the image's data source provisioning (adds `timeRangeForTags` on Tempo).

Dashboard edits made in the UI aren't saved back to the repo. To keep them, export the dashboard as JSON and replace `grafana/hackernews-demo.json`.

# Integration tests

End-to-end check that the SDK, instrumentations and OTLP/HTTP exporters in this
repo work together inside a real iOS app. The flow is:

1. A local collector is started that dumps everything it receives to
   `Tests/IntegrationTests/out/{traces,logs}.jsonl`.
2. `Examples/HackerNewsDemo` is built and launched in the iOS simulator with
   `--integrationTestMode`. `IntegrationTestScenario` in the app then emits a
   fixed set of telemetry: custom spans and a log record, three `URLSession`
   requests against the collector's `/status/{200,404,500}` endpoints, plus
   whatever the `Sessions` and `ResourceExtension` instrumentations add.
3. Once the `integration.test.complete` marker span arrives, the assertions in
   `Assertions/` are run with `swift test` against the dumped files.

This is a standalone SwiftPM package so the root `swift test` never runs it.

## Running locally

```shell
make integ-tests-ios
# or, with options
Scripts/run-integration-tests.sh --simulator <udid> --collector docker --port 4319
```

Requirements: Xcode with an iOS simulator, and `jq` (used to resolve the
simulator). `xcbeautify` is optional. Run `Scripts/run-integration-tests.sh --help`
for the full list of flags. The collected files stay in `out/` after a run,
so the assertions can be re-run on their own:

```shell
swift test --package-path Tests/IntegrationTests
```

## Collector backends

- **swift** (default): `MockCollector/`, a small swift-nio server built from
  this package. No Docker or Node required. Accepts OTLP/HTTP protobuf or JSON
  with gzip/deflate encoding, and serves `GET /status/<code>` for the app's
  network requests. Handy on its own when you want to see what an app exports:
  `swift run --package-path Tests/IntegrationTests OTLPMockCollector --output-dir /tmp/otlp`.
- **docker**: `compose.yaml` + `collector.yaml`, the OpenTelemetry Collector
  with the `file` exporter. Same output layout, which is why the assertions
  use a lenient hand-written model instead of the generated proto types.

## GitHub Actions

`.github/workflows/IntegrationTests.yml` runs the same `make` target on
pull requests that touch `Sources/`, the demo app, or these tests, on every
push to `main`, nightly at 00:00 UTC, and on manual dispatch. Pull request runs
are bound to the `integration-tests` environment: add required reviewers to
that environment in the repository settings and every PR run has to be
approved by a maintainer before it starts. Runs on `main`, the nightly and
manual runs use the unprotected `integration-tests-main` environment instead.
The collected telemetry is uploaded as a workflow artifact for debugging.

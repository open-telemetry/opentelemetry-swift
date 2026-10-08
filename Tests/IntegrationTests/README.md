# Integration tests

End-to-end check that the SDK, instrumentations and OTLP/HTTP exporters in this
repo work together inside a real iOS app. The flow is:

1. `Examples/HackerNewsDemo` is built and installed in the iOS simulator.
2. The app is launched several times with `--integrationTestMode` and an
   `--integrationLaunch <tag>`. For each launch the OpenTelemetry Collector
   dumps everything it receives to `Tests/IntegrationTests/out/<tag>/{traces,logs}.pb`,
   and the runner waits for the `integration.test.complete` marker span.
   `IntegrationTestScenario` in the app decides what each launch emits:
   - `main`: custom spans and a log record, three `URLSession` requests
     against the status server's `/status/{200,404,500}` endpoints, and a session
     expiry via a 2s session timeout, plus whatever the `Sessions` and
     `ResourceExtension` instrumentations add.
   - `max-lifetime`: continuous spans with `maxLifetime: 3`, so the session
     must roll over without ever going idle.
   - `restore-first` / `restore-second`: `restorePersistedSession: true`, so
     the second launch must resume the first one's session.
   - `no-restore`: `restorePersistedSession: false`, so a new session starts
     with the persisted one as its previous session.
   Session config is passed as launch arguments because `SessionConfig` is
   only read when a `SessionManager` is created. The app stays installed
   between launches so persisted session state carries over.
3. The assertions in `Assertions/` are run with `swift test` against the
   dumped files. `OTLPOutput.main` is the main launch and
   `OTLPOutput.launch(...)` selects the others.

This is a standalone SwiftPM package so the root `swift test` never runs it.

## Running locally

```shell
make integ-tests-ios
# or, with options
Scripts/run-integration-tests.sh --simulator <udid> --port 4318 --status-port 4319
```

`make integ-build-ios` builds the demo app on its own and
`make integ-tests-without-building-ios` runs the rest against that build, which
is how CI splits the job so the app's DerivedData can be cached.

Requirements: Xcode with an iOS simulator, and `jq` (used to resolve the
simulator). `xcbeautify` is optional. Run `Scripts/run-integration-tests.sh --help`
for the full list of flags. The collected files stay in `out/` after a run,
so the assertions can be re-run on their own:

```shell
swift test --package-path Tests/IntegrationTests
```

## Local endpoint

Telemetry goes to the real thing: the OpenTelemetry Collector, `otelcol`
core distribution, pinned by version and sha256 in
`Scripts/run-integration-tests.sh`. The runner downloads the ~30 MB macOS
binary once into `.collector/` (cached in CI) and starts it per launch with
`collector.yaml`: an `otlp` receiver on port 4318 and `file` exporters in
`proto` format, a stream of length-prefixed `Export<Signal>ServiceRequest`
messages. No Docker needed, so the same flow runs on GitHub's
macOS runners. Bump `COLLECTOR_VERSION` and both checksums together.

`StatusServer/` is a tiny swift-nio server on port 4319 that only answers
`GET /status/<code>` and `GET /health`. The app's integration scenario sends
its `URLSession` requests there so the network spans have deterministic
status codes without the public internet. It carries no OTLP code.

The assertions decode those files with the generated `Opentelemetry_Proto_*`
structs from this repo's `OpenTelemetryProtocolExporterCommon`, the same
types the exporters serialize, so there is no hand-written wire model. JSON
was ruled out because OTLP/JSON hex-encodes ids, which SwiftProtobuf's JSON
decoder rejects.

## GitHub Actions

`.github/workflows/IntegrationTests.yml` runs the same `make` target on
pull requests that touch `Sources/`, the demo app, or these tests, on every
push to `main`, nightly at 00:00 UTC, and on manual dispatch. Pull request runs
are bound to the `integration-tests` environment: add required reviewers to
that environment in the repository settings and every PR run has to be
approved by a maintainer before it starts. Runs on `main`, the nightly and
manual runs use the unprotected `integration-tests-main` environment instead.
The collected telemetry is uploaded as a workflow artifact for debugging.

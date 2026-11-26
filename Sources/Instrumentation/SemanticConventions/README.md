# Federated Semantic Conventions

Status: development

This module contains semantic convention definitions used by opentelemetry-swift instrumentations that aren't currently defined by the upstream [`open-telemetry/semantic-conventions`](https://github.com/open-telemetry/semantic-conventions) repository, along with the Swift constants generated from them.

The conventions are modeled as a federated semantic convention registry, the same way as [OpenTelemetry Android's `semconv` module](https://github.com/open-telemetry/opentelemetry-android/tree/main/semconv). The registry manifest declares the upstream semantic conventions as a dependency, so definitions here can reference upstream attributes without redefining them. Names that upstream already defines don't belong here; use `SemanticConventions` from `OpenTelemetryApi` for those.

| Path | Contents |
| --- | --- |
| `model/manifest.yaml` | The registry manifest, including the upstream semantic conventions version it depends on |
| `model/swift/registry.yaml` | The attributes defined by this registry |
| `model/swift/spans.yaml` | The spans and metrics defined by this registry, including their start and end timestamps |
| `templates/registry/swift/` | The [weaver](https://github.com/open-telemetry/weaver) templates that generate the Swift constants |
| `Attributes/` | The generated Swift constants. Don't edit these by hand. |

## Spans

| Span | Group | Used by |
| --- | --- | --- |
| `app.start` | `span.app_start` | `MincoreLaunchInstrumentation` |
| `app.resume` | `span.app_resume` | `MincoreLaunchInstrumentation` |

The span definitions are the authoritative description of when each span starts and ends for every `app.start.type` and `app.resume.type`.

## Attributes

The attributes are in the `app.start` and `app.resume` namespaces, and there are the `app.start.duration` and `app.resume.duration` metrics, in `model/swift/`. See [App Launch](../AppLaunch/README.md#appstart-and-appresume).

`app.start.type` uses the same `cold` and `warm` values as the `start.type` attribute in OpenTelemetry Android's registry, but its values follow Apple's definitions, and a resume is its own span instead of Android's `hot`. See the [App Launch README](../AppLaunch/README.md#start-types).

## Usage

The constants follow the same shape as `SemanticConventions` in `OpenTelemetryApi`, under the `FederatedSemanticConventions` namespace:

```swift
import InstrumentationSemanticConventions

spanBuilder.setAttribute(
  key: FederatedSemanticConventions.App.startType.rawValue,
  value: FederatedSemanticConventions.App.StartTypeValues.cold.description
)
```

## Generating the Swift constants

After changing the registry or the templates, regenerate the constants and commit the result:

```sh
Sources/Instrumentation/SemanticConventions/generate.sh
```

The script runs the `otel/weaver` Docker image, so it needs Docker. It downloads the upstream semantic conventions version declared in `model/manifest.yaml`.

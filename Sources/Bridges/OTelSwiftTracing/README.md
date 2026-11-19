# OTelSwiftTracing

This module requires the `SwiftObservabilityAPIBridges` package trait:

```swift
.package(url: "https://github.com/open-telemetry/opentelemetry-swift.git", from: "3.0.0", traits: ["SwiftObservabilityAPIBridges"])
```

Bridges `swift-distributed-tracing` (`Tracing`) into OpenTelemetry Swift.

## Usage

Bootstrapping the global `InstrumentationSystem`:

```swift

import OTelSwiftTracing
import Tracing

let tracer = OTelTracer()

InstrumentationSystem.bootstrap(tracer)
```

## Log correlation

With an OpenTelemetry tracer provider configured, continue the setup above to
include the current span's identifiers in application logs:

```swift
import OTelSwiftTracing
import OpenTelemetryApi
import Tracing

tracer.withSpan("handleRequest") { _ in
    if let context = ServiceContext.current?.otelSpanContext, context.isValid {
        let traceId = context.traceId.hexString
        let spanId = context.spanId.hexString
        let traceFlags = context.traceFlags.hexString
        print("Handling request trace_id=\(traceId) span_id=\(spanId) trace_flags=\(traceFlags)")
    }
}
```

The accessor is read-only and returns `nil` when the service context has no
OpenTelemetry span context. It does not add metadata to your logger automatically.

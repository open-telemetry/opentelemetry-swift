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

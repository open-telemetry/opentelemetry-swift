# OTelSwiftTracing

Bridges `swift-distributed-tracing` (`Tracing`) into OpenTelemetry Swift.

## Usage

Bootstrapping the global `InstrumentationSystem`:

```swift

import OTelSwiftTracing
import Tracing

let tracer = OTelTracer()

OTelSwiftTracing.bootstrap(tracer)
```

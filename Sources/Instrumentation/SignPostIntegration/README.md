# SignPost Integration

This package creates `os_signpost` `begin` and `end` calls when spans are started or ended. It allows automatic integration of applications
instrumented with opentelemetry to show their spans in a profiling app like `Instruments`. It also exports the `OSLog` it uses for posting so the user can add extra signpost events. This functionality is shown in `Simple Exporter` example


## Usage 

Just add SignpostIntegration as any other Span Processor:

```
OpenTelemetry.instance.tracerProvider.addSpanProcessor(SignPostIntegration())`
```



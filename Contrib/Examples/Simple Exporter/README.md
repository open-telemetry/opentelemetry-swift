### Simple Exporter

This example shows the Jaeger and Stdout exporters in action using a MultiSpanExporter. It also adds support for SignPostIntegration, so running this app in `Instruments` will show the span creation and duration

The sample expects a local Jaeger installation as explained in [Jaeger docs](https://www.jaegertracing.io/docs/1.41/getting-started/#all-in-one):

```
docker run -d --name jaeger \
  -e COLLECTOR_ZIPKIN_HOST_PORT=:9411 \
  -e COLLECTOR_OTLP_ENABLED=true \
  -p 6831:6831/udp \
  -p 6832:6832/udp \
  -p 5778:5778 \
  -p 16686:16686 \
  -p 4317:4317 \
  -p 4318:4318 \
  -p 14250:14250 \
  -p 14268:14268 \
  -p 14269:14269 \
  -p 9411:9411 \
  jaegertracing/all-in-one:1.41
```


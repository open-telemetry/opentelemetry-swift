### Simple Exporter

This example shows the Jaeger an Stdout exporters in action using a MultiSpanExporter

The sample expects a local Jaeger installation as explained in [Jaeger docs](https://www.jaegertracing.io/docs/1.16/getting-started/#all-in-one):

```
docker run -d --name jaeger \
 -e COLLECTOR_ZIPKIN_HTTP_PORT=9411 \
 -p 5775:5775/udp \
 -p 6831:6831/udp \
 -p 6832:6832/udp \
 -p 5778:5778 \
 -p 16686:16686 \
 -p 14268:14268 \
 -p 9411:9411 \
 jaegertracing/all-in-one:1.16
```


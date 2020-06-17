### Prometheus Sample

This example shows the Prometheus exporter returning data in a web server

The sample expects a Prometheus instance scraping data from a specific local port ,you can  run it like: 

```
docker run -p 9090:9090 -p 9184:9184 -v /Users/nacho/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
```

with a prometheus.yml with the content:

```
--- 
alerting: 
  alertmanagers: 
    - 
      api_version: v1
      scheme: http
      static_configs: 
        - 
          targets: []
      timeout: 10s
global: 
  evaluation_interval: 15s
  scrape_interval: 15s
  scrape_timeout: 10s
scrape_configs: 
  - 
    honor_timestamps: true
    job_name: Example code
    metrics_path: /metrics
    scheme: http
    scrape_interval: 15s
    scrape_timeout: 10s
    static_configs: 
      - 
        targets: 
          - "localhost:9184"
```

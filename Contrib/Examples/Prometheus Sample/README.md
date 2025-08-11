### Prometheus Sample

This example shows the Prometheus exporter returning data in a web server.
Modify your local ip address in the main file an the prometheus.yml file

The sample expects a Prometheus instance scraping data from a specific local port ,you can  run it like: 

```
docker run -p 9090:9090 -p 9184:9184 -v $HOME/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
```

with a prometheus.yml with the content (use your local ip address at the bottom):

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
          - "192.168.1.28:9184"
```

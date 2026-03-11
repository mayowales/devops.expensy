# Monitoring & Logging Documentation

## Overview

The Expensy application uses **Prometheus** for metrics collection and **Grafana** for visualization. The backend exposes a Prometheus-compatible metrics endpoint at `GET /metrics`.

---

## Metrics Exposed

The backend exposes the following custom metrics:

| Metric | Type | Description |
|---|---|---|
| `mongo_connection_status` | Gauge | MongoDB connection health: 1 = connected, 0 = disconnected |
| `expenses_total` | Gauge | Total number of expense documents in the database (updated every 60s) |
| `http_requests_overall_total` | Counter | Total HTTP request count across all routes |
| `http_requests_total` | Counter | HTTP requests broken down by method, route, and status code |

In addition, the default Node.js process metrics are exposed (CPU usage, memory, event loop lag, etc.) via `prom-client`'s `collectDefaultMetrics()`.

---

## Architecture

```
Backend Pod (:8706/metrics)
        |
        v
Prometheus (scrapes every 15s)
        |
        v
Grafana (visualizes metrics)
```

Prometheus and Grafana run as deployments inside the `wale-expensy-ns` namespace.

---

## Prometheus Configuration

Prometheus is configured via a ConfigMap (`prometheus-config`) mounted at `/etc/prometheus/prometheus.yml`.

**Scrape config** (`monitoring/prometheus.yml`):

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'expensy-backend'
    metrics_path: /metrics
    static_configs:
      - targets: ['backend:8706']
```

- **`scrape_interval: 15s`**: Prometheus pulls metrics from the backend every 15 seconds.
- **`targets: ['backend:8706']`**: Uses Kubernetes DNS to reach the backend service.

---

## Grafana Dashboard

The pre-configured dashboard (`monitoring/grafana-dashboard.json`) includes 7 panels:

1. **MongoDB Connection Status** (Stat) — Shows "Connected" (green) or "Disconnected" (red).
2. **Total Expenses** (Stat) — Current count of expenses in the database.
3. **HTTP Requests Total** (Stat) — Cumulative request count since the backend started.
4. **HTTP Requests Rate** (Time series) — Requests per minute over time.
5. **HTTP Requests by Route & Method** (Time series) — Breakdown showing which endpoints are hit most.
6. **Process CPU Usage** (Time series) — Backend Node.js process CPU consumption.
7. **Process Memory** (Time series) — Backend memory usage in MB.

### Importing the Dashboard

1. Open Grafana.
2. Click **Dashboards** → **New** → **Import**.
3. Upload `monitoring/grafana-dashboard.json` or paste its contents.
4. Select **Prometheus** as the data source.
5. Click **Import**.

---

## Accessing the Services

### Grafana

```bash
# If using LoadBalancer (current setup):
kubectl get svc grafana -n wale-expensy-ns
# Access via http://<EXTERNAL-IP>:3000
# Login: admin / expensy123

# If using port-forward:
kubectl port-forward svc/grafana -n wale-expensy-ns 3001:3000
# Access via http://localhost:3001
```

### Prometheus

```bash
# Port-forward to access the Prometheus UI:
kubectl port-forward svc/prometheus -n wale-expensy-ns 9090:9090
# Access via http://localhost:9090

# Check scrape targets:
# http://localhost:9090/targets
```

---

## Verifying Metrics

```bash
# Verify the backend exposes metrics:
kubectl exec -it deployment/backend -n wale-expensy-ns -- \
  sh -c "wget -qO- http://localhost:8706/metrics" | head -20

# Verify Prometheus can reach the backend:
kubectl exec -it deployment/prometheus -n wale-expensy-ns -- \
  wget -qO- http://backend:8706/metrics | head -5

# Check Prometheus targets are UP:
kubectl port-forward svc/prometheus -n wale-expensy-ns 9090:9090
# Then visit http://localhost:9090/targets
```

---

## Logging

All container logs are written to stdout, which Kubernetes captures automatically.

### Viewing Logs

```bash
# Backend logs
kubectl logs deployment/backend -n wale-expensy-ns

# Frontend logs
kubectl logs deployment/frontend -n wale-expensy-ns

# MongoDB logs
kubectl logs statefulset/mongo -n wale-expensy-ns

# Redis logs
kubectl logs statefulset/redis -n wale-expensy-ns

# Follow logs in real-time (add -f)
kubectl logs -f deployment/backend -n wale-expensy-ns

# View logs from all backend pods
kubectl logs -l app=backend -n wale-expensy-ns

# View previous container logs (if pod restarted)
kubectl logs deployment/backend -n wale-expensy-ns --previous
```

### Log Retention

Kubernetes retains logs as long as the pod exists. When a pod is deleted, its logs are lost. For persistent log storage, consider:

- **Azure Monitor**: Centralized log aggregation built into AKS. Enable via Azure portal under the AKS cluster's Monitoring settings.
- **ELK Stack**: Deploy Elasticsearch, Logstash, and Kibana for self-managed log aggregation and search.

---

## Useful Prometheus Queries

| Query | Description |
|---|---|
| `mongo_connection_status` | Current MongoDB connection state |
| `expenses_total` | Total expenses in the database |
| `http_requests_overall_total` | Total requests served |
| `rate(http_requests_overall_total[5m]) * 60` | Requests per minute |
| `http_requests_total` | Requests broken down by method, route, status |
| `rate(process_cpu_user_seconds_total[5m])` | CPU usage rate |
| `process_resident_memory_bytes / 1024 / 1024` | Memory usage in MB |
| `nodejs_active_handles_total` | Active Node.js handles |
| `nodejs_eventloop_lag_seconds` | Event loop lag |

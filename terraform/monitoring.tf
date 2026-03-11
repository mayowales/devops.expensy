# ============================================================
# PROMETHEUS — lightweight instance in your namespace
# ============================================================
# Since we can't create ServiceMonitors on the shared cluster,
# we run our own Prometheus that scrapes the backend directly.

# ConfigMap with Prometheus scrape configuration
resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace.expensy.metadata[0].name
  }

  data = {
    "prometheus.yml" = <<-EOT
      global:
        scrape_interval: 15s
        evaluation_interval: 15s

      scrape_configs:
        - job_name: 'expensy-backend'
          metrics_path: /metrics
          static_configs:
            - targets: ['backend:8706']
              labels:
                app: backend
                namespace: wale-expensy-ns
    EOT
  }
}

# Prometheus Deployment
resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.expensy.metadata[0].name
    labels    = { app = "prometheus" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "prometheus" }
    }

    template {
      metadata {
        labels = { app = "prometheus" }
      }

      spec {
        container {
          name  = "prometheus"
          image = "prom/prometheus:latest"

          port {
            container_port = 9090
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/prometheus"
          }

          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "250m", memory = "256Mi" }
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.prometheus_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.expensy.metadata[0].name
  }

  spec {
    type     = "ClusterIP"
    selector = { app = "prometheus" }
    port {
      name        = "http"
      port        = 9090
      target_port = 9090
    }
  }
}

# ============================================================
# GRAFANA — visualization dashboard
# ============================================================

# Grafana datasource config — points to our Prometheus
resource "kubernetes_config_map" "grafana_datasource" {
  metadata {
    name      = "grafana-datasources"
    namespace = kubernetes_namespace.expensy.metadata[0].name
  }

  data = {
    "datasources.yaml" = <<-EOT
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          access: proxy
          url: http://prometheus:9090
          isDefault: true
    EOT
  }
}

# Grafana dashboard JSON — pre-configured for your metrics
resource "kubernetes_config_map" "grafana_dashboard" {
  metadata {
    name      = "grafana-dashboards"
    namespace = kubernetes_namespace.expensy.metadata[0].name
  }

  data = {
    "dashboard.yaml" = <<-EOT
      apiVersion: 1
      providers:
        - name: 'default'
          folder: 'Expensy'
          type: file
          options:
            path: /var/lib/grafana/dashboards
    EOT

    "expensy-dashboard.json" = <<-EOT
      {
        "dashboard": {
          "title": "Expensy Monitoring",
          "uid": "expensy-main",
          "panels": [
            {
              "title": "MongoDB Connection Status",
              "type": "stat",
              "gridPos": { "h": 6, "w": 6, "x": 0, "y": 0 },
              "targets": [{ "expr": "mongo_connection_status", "legendFormat": "Status" }],
              "fieldConfig": {
                "defaults": {
                  "mappings": [
                    { "type": "value", "options": { "0": { "text": "Disconnected", "color": "red" }, "1": { "text": "Connected", "color": "green" } } }
                  ]
                }
              }
            },
            {
              "title": "Total Expenses",
              "type": "stat",
              "gridPos": { "h": 6, "w": 6, "x": 6, "y": 0 },
              "targets": [{ "expr": "expenses_total", "legendFormat": "Count" }]
            },
            {
              "title": "HTTP Requests Total",
              "type": "stat",
              "gridPos": { "h": 6, "w": 6, "x": 12, "y": 0 },
              "targets": [{ "expr": "http_requests_overall_total", "legendFormat": "Total" }]
            },
            {
              "title": "HTTP Requests Rate (per minute)",
              "type": "timeseries",
              "gridPos": { "h": 8, "w": 18, "x": 0, "y": 6 },
              "targets": [{ "expr": "rate(http_requests_overall_total[5m]) * 60", "legendFormat": "Requests/min" }]
            },
            {
              "title": "HTTP Requests by Route & Method",
              "type": "timeseries",
              "gridPos": { "h": 8, "w": 18, "x": 0, "y": 14 },
              "targets": [{ "expr": "rate(http_requests_total[5m]) * 60", "legendFormat": "{{method}} {{route}} ({{status_code}})" }]
            },
            {
              "title": "Process CPU Usage",
              "type": "timeseries",
              "gridPos": { "h": 8, "w": 9, "x": 0, "y": 22 },
              "targets": [{ "expr": "rate(process_cpu_user_seconds_total[5m])", "legendFormat": "CPU Usage" }]
            },
            {
              "title": "Process Memory (MB)",
              "type": "timeseries",
              "gridPos": { "h": 8, "w": 9, "x": 9, "y": 22 },
              "targets": [{ "expr": "process_resident_memory_bytes / 1024 / 1024", "legendFormat": "Memory (MB)" }]
            }
          ],
          "time": { "from": "now-1h", "to": "now" },
          "refresh": "10s"
        }
      }
    EOT
  }
}

resource "kubernetes_deployment" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.expensy.metadata[0].name
    labels    = { app = "grafana" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "grafana" }
    }

    template {
      metadata {
        labels = { app = "grafana" }
      }

      spec {
        container {
          name  = "grafana"
          image = "grafana/grafana:latest"

          port {
            container_port = 3000
          }

          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = "expensy123"
          }

          # Datasource config
          volume_mount {
            name       = "datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
          }

          # Dashboard provisioning config
          volume_mount {
            name       = "dashboard-config"
            mount_path = "/etc/grafana/provisioning/dashboards"
          }

          # Dashboard JSON files
          volume_mount {
            name       = "dashboard-json"
            mount_path = "/var/lib/grafana/dashboards"
          }

          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "250m", memory = "256Mi" }
          }
        }

        volume {
          name = "datasources"
          config_map {
            name = kubernetes_config_map.grafana_datasource.metadata[0].name
          }
        }

        volume {
          name = "dashboard-config"
          config_map {
            name = kubernetes_config_map.grafana_dashboard.metadata[0].name
            items {
              key  = "dashboard.yaml"
              path = "dashboard.yaml"
            }
          }
        }

        volume {
          name = "dashboard-json"
          config_map {
            name = kubernetes_config_map.grafana_dashboard.metadata[0].name
            items {
              key  = "expensy-dashboard.json"
              path = "expensy-dashboard.json"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.expensy.metadata[0].name
  }

  spec {
    type     = "LoadBalancer"
    selector = { app = "grafana" }
    port {
      name        = "http"
      port        = 3000
      target_port = 3000
    }
  }
}

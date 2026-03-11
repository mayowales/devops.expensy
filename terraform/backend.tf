resource "kubernetes_deployment" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.expensy.metadata[0].name
    labels    = { app = "backend" }
  }

  spec {
    replicas = 2

    selector {
      match_labels = { app = "backend" }
    }

    template {
      metadata {
        labels = { app = "backend" }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "8706"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        container {
          name  = "backend"
          image = var.backend_image
          image_pull_policy = "Always"

          port {
            container_port = 8706
          }

          env {
            name = "PORT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.expensy.metadata[0].name
                key  = "PORT"
              }
            }
          }

          env {
            name = "REDIS_HOST"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.expensy.metadata[0].name
                key  = "REDIS_HOST"
              }
            }
          }

          env {
            name = "REDIS_PORT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.expensy.metadata[0].name
                key  = "REDIS_PORT"
              }
            }
          }

          env {
            name = "DATABASE_URI"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.expensy.metadata[0].name
                key  = "DATABASE_URI"
              }
            }
          }

          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.expensy.metadata[0].name
                key  = "REDIS_PASSWORD"
              }
            }
          }

          resources {
            requests = { cpu = "250m", memory = "256Mi" }
            limits   = { cpu = "500m", memory = "512Mi" }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_stateful_set.mongo,
    kubernetes_stateful_set.redis,
  ]
}

resource "kubernetes_service" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.expensy.metadata[0].name
  }

  spec {
    type     = "ClusterIP"
    selector = { app = "backend" }
    port {
      name        = "http"
      port        = 8706
      target_port = 8706
    }
  }
}

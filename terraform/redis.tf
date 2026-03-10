resource "kubernetes_stateful_set" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.expensy.metadata[0].name
    labels    = { app = "redis" }
  }

  spec {
    service_name = "redis"
    replicas     = 1

    selector {
      match_labels = { app = "redis" }
    }

    template {
      metadata {
        labels = { app = "redis" }
      }

      spec {
        container {
          name    = "redis"
          image   = "redis:7-alpine"
          command = ["redis-server"]
          args    = ["--requirepass", "$(REDIS_PASSWORD)"]

          port {
            container_port = 6379
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

          volume_mount {
            name       = "redis-data"
            mount_path = "/data"
          }

          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "250m", memory = "256Mi" }
          }
        }
      }
    }

    volume_claim_template {
      metadata { name = "redis-data" }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "managed-csi"
        resources {
          requests = { storage = "2Gi" }
        }
      }
    }
  }
}

resource "kubernetes_service" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.expensy.metadata[0].name
  }

  spec {
    cluster_ip = "None"
    selector   = { app = "redis" }
    port {
      port        = 6379
      target_port = 6379
    }
  }
}

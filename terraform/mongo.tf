resource "kubernetes_stateful_set" "mongo" {
  metadata {
    name      = "mongo"
    namespace = kubernetes_namespace.expensy.metadata[0].name
    labels    = { app = "mongo" }
  }

  spec {
    service_name = "mongo"
    replicas     = 1

    selector {
      match_labels = { app = "mongo" }
    }

    template {
      metadata {
        labels = { app = "mongo" }
      }

      spec {
        container {
          name  = "mongo"
          image = "mongo:7"

          port {
            container_port = 27017
          }

          env {
            name = "MONGO_INITDB_ROOT_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.expensy.metadata[0].name
                key  = "MONGO_ROOT_USERNAME"
              }
            }
          }

          env {
            name = "MONGO_INITDB_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.expensy.metadata[0].name
                key  = "MONGO_ROOT_PASSWORD"
              }
            }
          }

          volume_mount {
            name       = "mongo-data"
            mount_path = "/data/db"
          }

          resources {
            requests = { cpu = "250m", memory = "256Mi" }
            limits   = { cpu = "500m", memory = "512Mi" }
          }
        }
      }
    }

    volume_claim_template {
      metadata { name = "mongo-data" }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "managed-csi"
        resources {
          requests = { storage = "10Gi" }
        }
      }
    }
  }
}

resource "kubernetes_service" "mongo" {
  metadata {
    name      = "mongo"
    namespace = kubernetes_namespace.expensy.metadata[0].name
  }

  spec {
    cluster_ip = "None"
    selector   = { app = "mongo" }
    port {
      port        = 27017
      target_port = 27017
    }
  }
}

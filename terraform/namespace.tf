resource "kubernetes_namespace" "expensy" {
  metadata {
    name = var.namespace

    labels = {
      app        = "expensy"
      managed-by = "terraform"
      owner      = "wale"
    }
  }
}

resource "kubernetes_config_map" "expensy" {
  metadata {
    name      = "expensy-config"
    namespace = kubernetes_namespace.expensy.metadata[0].name
  }

  data = {
    PORT       = "8706"
    REDIS_HOST = "redis"
    REDIS_PORT = "6379"
  }
}

resource "kubernetes_secret" "expensy" {
  metadata {
    name      = "expensy-secrets"
    namespace = kubernetes_namespace.expensy.metadata[0].name
  }

  type = "Opaque"

  data = {
    MONGO_ROOT_USERNAME = var.mongo_root_username
    MONGO_ROOT_PASSWORD = var.mongo_root_password
    DATABASE_URI        = "mongodb://${var.mongo_root_username}:${var.mongo_root_password}@mongo:27017/expensy?authSource=admin"
    REDIS_PASSWORD      = var.redis_password
  }
}

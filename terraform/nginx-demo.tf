# ============================================================
# NGINX DEMO — Simple Nginx deployment to serve static content
# ============================================================

resource "kubernetes_deployment" "nginx_demo" {
  metadata {
    name      = "nginx-demo"
    namespace = kubernetes_namespace.expensy.metadata[0].name
    labels    = { app = "nginx-demo" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "nginx-demo" }
    }

    template {
      metadata {
        labels = { app = "nginx-demo" }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:alpine"

          port {
            container_port = 80
          }

          resources {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { cpu = "100m", memory = "128Mi" }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx_demo" {
  metadata {
    name      = "nginx-demo"
    namespace = kubernetes_namespace.expensy.metadata[0].name
  }

  spec {
    type     = "ClusterIP"
    selector = { app = "nginx-demo" }
    port {
      port        = 80
      target_port = 80
    }
  }
}

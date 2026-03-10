resource "kubernetes_ingress_v1" "expensy" {
  metadata {
    name      = "expensy-ingress"
    namespace = kubernetes_namespace.expensy.metadata[0].name

    annotations = {
      "cert-manager.io/cluster-issuer"           = "letsencrypt-production"
      "nginx.ingress.kubernetes.io/use-regex"     = "true"
      "nginx.ingress.kubernetes.io/ssl-redirect"  = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = ["wale-expensy-safe.duckdns.org"]
      secret_name = "wale-expensy-safe-tls"
    }

    rule {
      host = "wale-expensy-safe.duckdns.org"

      http {
        path {
          path      = "/api"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.backend.metadata[0].name
              port { number = 8706 }
            }
          }
        }

        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.frontend.metadata[0].name
              port { number = 3000 }
            }
          }
        }
      }
    }
  }
}


# ============================================================
# INGRESS 2 — Expensy app HTTP only (unsafe, no TLS)
# ============================================================

resource "kubernetes_ingress_v1" "expensy_unsafe" {
  metadata {
    name      = "expensy-ingress-unsafe"
    namespace = kubernetes_namespace.expensy.metadata[0].name

    annotations = {
      "nginx.ingress.kubernetes.io/use-regex"    = "true"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "false"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "wale-expensy-unsafe.duckdns.org"

      http {
        path {
          path      = "/api"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.backend.metadata[0].name
              port { number = 8706 }
            }
          }
        }

        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.frontend.metadata[0].name
              port { number = 3000 }
            }
          }
        }
      }
    }
  }
}

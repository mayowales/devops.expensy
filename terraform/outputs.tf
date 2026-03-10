output "namespace" {
  value = kubernetes_namespace.expensy.metadata[0].name
}

output "kube_context" {
  value = var.kube_context
}

output "backend_image" {
  value = var.backend_image
}

output "frontend_image" {
  value = var.frontend_image
}

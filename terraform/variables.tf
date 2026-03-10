variable "kube_context" {
  description = "The kubectl context for the shared cluster"
  type        = string
}

variable "namespace" {
  description = "Your isolated namespace on the shared cluster"
  type        = string
  default     = "wale-expensy-ns"
}

variable "backend_image" {
  description = "Tag for the backend image"
  type        = string
}

variable "frontend_image" {
  description = "Tag for the frontend image"
  type        = string
}


variable "mongo_root_username" {
  description = "MongoDB root username"
  type        = string
  default     = "root"
  sensitive   = true
}

variable "mongo_root_password" {
  description = "MongoDB root password"
  type        = string
  default     = "example"
  sensitive   = true
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  default     = "someredispassword"
  sensitive   = true
}

variable "kubeconfig" {
  description = "Шлях до kubeconfig файлу"
  type        = string
}

variable "cluster_name" {
  description = "Назва Kubernetes кластера"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN OIDC provider для EKS"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL OIDC provider для EKS"
  type        = string
}
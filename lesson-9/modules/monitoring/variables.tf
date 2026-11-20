variable "namespace" {
  description = "Kubernetes namespace для Prometheus і Grafana."
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "Зафіксована версія kube-prometheus-stack Helm chart."
  type        = string
}

variable "grafana_admin_password" {
  description = "Пароль адміністратора Grafana."
  type        = string
  sensitive   = true
}

variable "storage_class_name" {
  description = "StorageClass EBS CSI для постійного зберігання даних."
  type        = string
  default     = "ebs-sc"
}
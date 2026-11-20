resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version
  namespace  = var.namespace

  create_namespace = true
  atomic           = true
  timeout          = 900

  values = [
    yamlencode({
      # Ці control-plane endpoints керуються AWS і недоступні для звичайного
      # scrape з EKS.
      kubeEtcd              = { enabled = false }
      kubeControllerManager = { enabled = false }
      kubeScheduler         = { enabled = false }

      grafana = {
        enabled       = true
        adminPassword = var.grafana_admin_password

        service = {
          type = "ClusterIP"
        }

        persistence = {
          enabled          = true
          storageClassName = var.storage_class_name
          size             = "5Gi"
        }
      }

      prometheus = {
        prometheusSpec = {
          retention = "7d"

          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class_name
                accessModes      = ["ReadWriteOnce"]

                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }
        }
      }
    })
  ]
}
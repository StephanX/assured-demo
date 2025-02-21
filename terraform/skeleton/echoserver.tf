# # example helm deployment to validate external-dns and cert-manager.  To test via port-forward:
# > ku port-forward -n echoserver svc/echoserver-echo-server 8080:80
# > curl localhost:8080

# it's a bad idea to let helm create namespaces from within terraform, explicitely manage with terraform directly.
resource "kubernetes_namespace" "echoserver" {
  metadata {
    name = "echoserver"
    labels = {
      notice = "Managed_by_terraform.DO_NOT_EDIT_BY_HAND"
    }
  }
}

resource "helm_release" "echoserver" {
  name             = "echoserver"
  repository       = "https://ealenn.github.io/charts"
  chart            = "echo-server"
  namespace        = "echoserver"
}

resource "kubernetes_ingress_v1" "echoserver" {
  metadata {
    name = "echoserver"
    namespace = "echoserver"
    annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        "external-dns.alpha.kubernetes.io/hostname" = "echo.${var.root_domain}"
        "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
        "traefik.ingress.kubernetes.io/router.tls" = "true"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "echo.${var.root_domain}"
      http {
        path {
          backend {
            service {
              name = "echoserver-echo-server"
              port {
                number = 80
              }
            }
          }
          path = "/"
          path_type = "ImplementationSpecific"
        }
      }
    }

    tls {
      secret_name = "echo.${var.root_domain}-tls"
      hosts = [
        "echo.${var.root_domain}"
      ]
    }
  }
}

resource "kubernetes_namespace" "vaultwarden" {
  metadata {
    name = "vaultwarden"
  }
}

resource "helm_release" "vaultwarden" {
  name             = "vaultwarden"
  repository       = "https://constin.github.io/vaultwarden-helm"
  chart            = "vaultwarden"
  namespace        = "vaultwarden"

  set {
    name = "ingress.hosts[0]"
    value = "vw.${var.root_domain}"
  }
  set {
    name = "image.pullPolicy"
    value = "Always"
  }
  set {
    name = "image.repository"
    value = "vaultwarden/server"
  }
  set {
    name = "persistence.enabled"
    value = "true"
  }
  set {
    name = "persistence.size"
    value = "1Gi"
  }
  set {
    name = "persistence.storageClass"
    value = "do-block-storage"
  }
  set {
    name = "env.SIGNUPS_ALLOWED"
    value = "false"
  }
  set {
    name = "env.INVITATIONS_ALLOWED"
    value = "true"
  }
  set {
    name = "env.ADMIN_TOKEN"
    value = "CHANGEMEASFASTASYOUCAN"
  }
  set {
    name = "env.DOMAIN"
    # value = "https://vw.domain.tld:8443"
    value = "https://vw.${var.root_domain}"
  }
  set {
    name = "ingress.tls[0].hosts[0]"
    value = "vw.${var.root_domain}"
  }
  set {
    name = "ingress.tls[0].secretName"
    value = "bitwarden-tls-secret"
  }
  set {
    name = "ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = "letsencrypt-prod" # must match cert-manager 's clusterissuer name
  }
}

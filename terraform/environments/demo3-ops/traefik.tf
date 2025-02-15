resource "kubernetes_namespace" "traefik" {
  metadata {
    name = "traefik"
  }
}

data "template_file" "traefik-helm-values" {
  template = <<-EOF
    service:
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-proxy-protocol: "*" # required to show real client IP address.  Proxy Protocol info here: https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/enable-proxy-protocol.html
    ports:
      web:
        redirections:
          entryPoint:
            to: websecure
            scheme: https
            permanent: true
      websecure:
        forwardedHeaders:
          trustedIPs:
          - "${module.vpc.vpc_cidr_block}"
        proxyProtocol:
          trustedIPs:
          - "${module.vpc.vpc_cidr_block}"
    providers:
      kubernetesIngress:
        publishedService:
          enabled: true
    logs:
      access:
        enabled: true
  EOF
}

resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  namespace        = "traefik"
  version          = "v34.3.0" # https://github.com/traefik/traefik-helm-chart/releases

  values = [
    data.template_file.traefik-helm-values.rendered
  ]

}
resource "aws_route53_zone" "primary" {
  name         = var.root_domain
  # private_zone = false
}

# IAM user and policies for both cert-manager and external-dns

resource "aws_iam_user" "cert-manager" {
  name = "cert-manager"
  tags = {
    purpose = "cert-manager route53 management"
  }
}

resource "aws_iam_access_key" "cert-manager" {
  user = aws_iam_user.cert-manager.name
}

resource "aws_iam_user_policy" "cert-manager" {
  name = aws_iam_user.cert-manager.name
  user = aws_iam_user.cert-manager.name
  policy =  jsonencode(
    {
      "Version": "2012-10-17",
      "Id": "certbot-dns-route53 policy",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "route53:ListHostedZones",
                  "route53:ListHostedZonesByName",
                  "route53:ListResourceRecordSets",
                  "route53:GetChange",
                  "route53:ChangeResourceRecordSets"
              ],
              "Resource": [
                  "*"
              ]
          }
      ]
    }
  )
}

resource "kubernetes_namespace" "cert-manager" {
  metadata {
    name = "cert-manager"
    labels = {
      notice = "Managed_by_terraform.DO_NOT_EDIT_BY_HAND"
    }
  }
}

resource "kubernetes_secret" "external-dns-aws-credentials" {
  metadata {
    name      = "external-dns-aws-credentials"
    namespace = kubernetes_namespace.cert-manager.metadata[0].name
  }
  data = {
    credentials = "[default]\naws_access_key_id=\"${aws_iam_access_key.cert-manager.id}\"\naws_secret_access_key=\"${aws_iam_access_key.cert-manager.secret}\"\n"
  }
}

data "template_file" "external-dns-values" {
  template = <<-EOF
    provider: aws
    env:
    - name: AWS_DEFAULT_REGION
      value: ${var.region}
    - name: AWS_SHARED_CREDENTIALS_FILE
      value: "/.aws/credentials"
    extraVolumes:
    - name: aws-credentials
      secret:
        secretName: ${kubernetes_secret.external-dns-aws-credentials.metadata[0].name}
    extraVolumeMounts:
    - name: aws-credentials
      mountPath: /.aws
      readOnly: true
  EOF
}

resource "helm_release" "external-dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  namespace        = kubernetes_namespace.cert-manager.metadata[0].name
  version          = "1.15.2" # https://github.com/kubernetes-sigs/external-dns/releases
  values = [
    data.template_file.external-dns-values.rendered
  ]
}

resource "kubernetes_secret" "cert-manager-aws-credentials" {
  metadata {
    name      = "cert-manager-aws-credentials"
    namespace = kubernetes_namespace.cert-manager.metadata[0].name
  }
  data = {
    secret-access-key = aws_iam_access_key.cert-manager.secret
  }
}

resource "helm_release" "cert-manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = kubernetes_namespace.cert-manager.metadata[0].name
  version          = "v1.17.1" # https://artifacthub.io/packages/helm/cert-manager/cert-manager

  set {
    name = "installCRDs"
    value = "true"
  }
  set {
    name = "ingressShim.defaultIssuerName"
    value = "letsencrypt-prod"
  }
  set {
    name = "ingressShim.defaultIssuerKind"
    value = "ClusterIssuer"
  }
  set {
    name = "ingressShim.defaultIssuerGroup"
    value = "cert-manager.io"
  }

}

resource "kubectl_manifest" "cert-manager-cluster-issuer" {
  # kubernetes_manifest requires the CRD to exist before hand.  kubectl_manifest doesn't bother checking. https://github.com/hashicorp/terraform-provider-kubernetes/issues/1380#issuecomment-967022975
  depends_on = [helm_release.cert-manager]
  yaml_body = <<YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        email: ${var.letsencrypt_email}
        privateKeySecretRef:
          name: letsencrypt-prod
        server: https://acme-v02.api.letsencrypt.org/directory
        solvers:
        - dns01:
            route53:
              region: ${var.region}
              accessKeyID: ${aws_iam_access_key.cert-manager.id}
              secretAccessKeySecretRef:
                name: ${kubernetes_secret.cert-manager-aws-credentials.metadata[0].name}
                key: secret-access-key
            selector:
              dnsZones: ${jsonencode(var.cert_manager_domains)}
    YAML
}


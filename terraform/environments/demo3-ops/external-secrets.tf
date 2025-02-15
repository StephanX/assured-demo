# helpful? https://blog.container-solutions.com/tutorialexternal-secrets-with-hashicorp-vault
# https://computingforgeeks.com/how-to-integrate-multiple-kubernetes-clusters-to-vault-server/
# https://hackmd.io/@maelvls/vault-audience-kubernetes-auth

provider "vault" {
  address = "https://vault.${var.root_domain}"
}

data "vault_policy_document" "cluster" {
  rule {
    path = "secrets/data/clusters/${var.environment}-${var.root_name}/*"
    capabilities = ["read"]
  }
  rule {
    path = "secrets/data/clusters/common/*"
    capabilities = ["read"]
  }
}

resource "vault_policy" "cluster" {
  name = "cluster.${var.environment}-${var.root_name}"
  policy = data.vault_policy_document.cluster.hcl
}

resource "kubernetes_namespace" "external-secrets" {
  metadata {
    name = "external-secrets"
    labels = {
      notice = "Managed_by_terraform.DO_NOT_EDIT_BY_HAND"
    }
  }
}

# service accounts in terraform are in a bad spot right now.  https://github.com/hashicorp/terraform-provider-kubernetes/pull/1833 has a lame fix
resource "kubernetes_service_account" "external-secrets" {
  metadata {
    name = "external-secrets"
    namespace = "external-secrets"
  }
  secret {
    name = "external-secrets-token"
  }
  automount_service_account_token = true

  lifecycle {
    ignore_changes = [
      image_pull_secret,
      secret
    ]
  }
}

resource "kubernetes_secret" "external-secrets" {
  metadata {
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.external-secrets.metadata[0].name
    }
    name = "external-secrets-token"
    namespace = "external-secrets"
  }
  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_cluster_role_binding" "external-secrets" {
  metadata {
    name = "role-tokenreview-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "external-secrets"
    namespace = "external-secrets"
  }
}

resource "vault_auth_backend" "cluster" {
  type = "kubernetes"
  path = "${var.environment}-${var.root_name}"
}

resource "vault_kubernetes_auth_backend_config" "cluster" {
  backend                = vault_auth_backend.cluster.path
  kubernetes_host        = module.eks_cluster.eks_cluster_endpoint
  kubernetes_ca_cert     = base64decode(module.eks_cluster.eks_cluster_certificate_authority_data)
  token_reviewer_jwt     = kubernetes_secret.external-secrets.data.token
  disable_iss_validation = "true"
}

resource "vault_kubernetes_auth_backend_role" "cluster" {
  backend                          = vault_auth_backend.cluster.path
  role_name                        = "external-secrets"
  bound_service_account_names      = ["external-secrets"]
  bound_service_account_namespaces = ["external-secrets"]
  token_ttl                        = 4320
  token_policies                   = ["default", vault_policy.cluster.name]
  # audience                         = "vault" #
}

resource "helm_release" "external-secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  set {
    name = "installCRDs"
    value = "true"
  }
  set {
    name = "serviceAccount.create"
    value = "false"
  }
}

resource "kubectl_manifest" "external_secrets_cluster_store" {
  yaml_body  = <<-EOF
    apiVersion: external-secrets.io/v1beta1
    kind: ClusterSecretStore
    metadata:
      name: vault-backend
    spec:
      provider:
        vault:
          server: "https://vault.${var.root_domain}"
          path: "secrets"
          version: "v2"
          auth:
            kubernetes:
              mountPath: "${var.environment}-${var.root_name}"
              role: "external-secrets"
              serviceAccountRef:
                name: "external-secrets"
                namespace: "external-secrets"
    EOF
  depends_on = [
    helm_release.external-secrets
  ]
}

# will generate a secret within the vault directly
resource "vault_generic_secret" "example_external_secret" {
  path = "secrets/clusters/${var.environment}-${var.root_name}/stephan"

  data_json = <<EOT
{
  "user": "stephan",
  "pass": "wuzhere"
}
EOT
}

# will create an externalsecret object in kubernetes that references the named secret in vault
resource "kubectl_manifest" "stephan_test" {
  yaml_body  = <<-EOF
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: stephan
      namespace: external-secrets
    spec:
      secretStoreRef:
        name: vault-backend
        kind: ClusterSecretStore
      refreshInterval: 60m
      target:
        name: stephan
      # `key:` needs to match exactly as one would reference from, say, the vault cli.  In this case, the root 'secrets/' prefix matches the kv2 secrets engine `secrets` defined when the vault was originally provisioned, and matches spec.provider.vault.path from ClusterSecretStore
      dataFrom:
        - extract:
            key: "secrets/clusters/${var.environment}-${var.root_name}/stephan"
      # data:
      # - secretKey: stephan
      #   remoteRef:
      #     key: secrets/stephan
      #     property: wuzhere
    EOF
  depends_on = [
    helm_release.external-secrets
  ]
}

resource "kubectl_manifest" "stephan_boring_test" {
  yaml_body  = <<-EOF
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: stephan-boring
      namespace: external-secrets
    spec:
      secretStoreRef:
        name: vault-backend
        kind: ClusterSecretStore
      refreshInterval: 60m
      target:
        name: stephan-boring
      # `key:` needs to match exactly as one would reference from, say, the vault cli.  In this case, the root 'secrets/' prefix matches the kv2 secrets engine `secrets` defined when the vault was originally provisioned, and matches spec.provider.vault.path from ClusterSecretStore
      dataFrom:
        - extract:
            key: "secrets/clusters/${var.environment}-${var.root_name}/stephan"
      data:
      - secretKey: stephan-boring
        remoteRef:
          key: secrets/stephan-boring
          property: wuzhere
    EOF
  depends_on = [
    helm_release.external-secrets
  ]
}

###### WARNING!!!!!  WARNING!!!!!  WARNING!!!!!  WARNING!!!!!  WARNING!!!!!   ###########
## This is NOT A SECURE SET UP!!!! The Vault ingress endpoint is OPEN TO THE PUBLIC!!!!!!!!!
## In any sort of production environment, THIS ENDPOINT should be shielded by some sort of additional restriction, like an IP whitelist for a VPN, or *ideally* with NO public IP access like a VPC peer.  DO NOT USE THIS IF YOU CARE ABOUT THE CONTENTS OF YOUR VAULT!!!!!!!!
## You have been warned.
### I wrote this in a hurry, to get things bootstrapped. This task deserves a lot more attention, but is outside of the scope of my current objective -Stephan

### TODO: configure auto-unseal: https://developer.hashicorp.com/vault/tutorials/auto-unseal/autounseal-aws-kms
### TODO: add VPN gating, understanding that configuration of a brand new VPN solution requires manual configuration of keys
### TODO: configure letsencrypt to generate a TLS cert for vault to use directly instead of relying on ingress to decrypt the requests.

resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault"
    labels = {
      notice = "Managed_by_terraform.DO_NOT_EDIT_BY_HAND"
    }
  }
}

# consul helm values
data "template_file" "consul-values" {
  template = <<-EOF
    global:
      name: consul
    server:
      storageClass: gp2-retain
      # replicas: 3
    client:
      enabled: false

  EOF
}

# vault consul
resource "helm_release" "consul" {
  name             = "consul"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "consul"
  # version          = "1.6.2" # https://github.com/hashicorp/consul-k8s/blob/main/CHANGELOG.md #  helm search repo hashicorp/consul #
  version          = "1.1.18"  # TODO: I used this version and need to revisit
  namespace        = "vault"
  values = [
    data.template_file.consul-values.rendered
  ]
}

# vault helm values
data "template_file" "vault-values" {
  template = <<-EOF
    ui:
      enabled: true
      externalPort: 8200
    server:
      affinity: |
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app.kubernetes.io/name: {{ template "vault.name" . }}
                  app.kubernetes.io/instance: "{{ .Release.Name }}"
                  component: server
              topologyKey: kubernetes.io/hostname
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: purpose
                    operator: In
                    values:
                      - vault
      tolerations:
      - key: node_role
        value: vault
        effect: "NoSchedule"
      ingress:
        enabled: true
        annotations: |
          traefik.ingress.kubernetes.io/router.entrypoints: websecure
          traefik.ingress.kubernetes.io/router.tls: "true"
          cert-manager.io/cluster-issuer: letsencrypt-prod
          external-dns.alpha.kubernetes.io/hostname: vault.${var.root_domain}
          app.kubernetes.io/managed-by: "Helm"

        ingressClassName: traefik
        hosts:
          - host: vault.${var.root_domain}
            http:
              paths:
                - path: /*
                  backend:
                    service:
                      name: vault
                      port:
                        number: 8200
        tls:
          - secretName: vault-active-tls
            hosts:
              - vault.${var.root_domain}

      ha:
        enabled: true
        replicas: 3
        config: |
          ui = true
          listener "tcp" {
            tls_disable = 1
            address = "[::]:8200"
            cluster_address = "[::]:8201"
          }
          storage "consul" {
            path = "vault"
            address = "consul-server:8500"
          }
          service_registration "kubernetes" {}
  EOF
}

# helm install vault hashicorp/vault vault -v vault-values.yaml
resource "helm_release" "vault" {
  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  namespace        = "vault"
  version          = "0.29.1" # https://github.com/hashicorp/vault-helm/releases
  values = [
    data.template_file.vault-values.rendered
  ]
  depends_on = [
    helm_release.vault
  ]
}

# # vault init
# port-forward -n vault svc/vault 8200:8200
# export VAULT_ADDR=http://127.0.0.1:8200
# vault operator init \
#     -key-shares=1 \
#     -key-threshold=1

# # rekey
# vault operator rekey \
#     -init \
#     -key-shares=1 \
#     -key-threshold=1

# # export VAULT_UNSEAL_KEY='SOMETHINGOESHERE'
# for i in $(kubectl get po -l app.kubernetes.io/instance=vault,component=server | awk '{ print $1 }') ; do
#   kshell $i vault operator unseal ${VAULT_UNSEAL_KEY}
# done

# # TODO: all engines, auth mechanisms, policies, and admin users.

# #  only needs to be run once, will error out if the engine or auth method, though we configure this in terraform so don't!
# vault secrets enable -version=2 -path=secrets kv
# vault write sys/auth/userpass type=userpass


# #### TO DO ######
# # The following resources will only work once the vault has been initialized, keyed, and unsealed.  Another day, code this up.
# # If secrets and auth were done manually above, import like so:
# # `tfi vault_auth_backend.userpass "userpass"` ; `tfi vault_mount.kvv2 "secrets"`

# export VAULT_TOKEN='SOMETOKEN'

resource "vault_mount" "kvv2" {
  path        = "secrets"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}

resource "vault_auth_backend" "userpass" {
  type = "userpass"
  path = "userpass"
}

# Once the operator unseal and token tasks have been completed and the VAULT authorization
resource "vault_policy" "admin" {
  name = "admin"
  # lifted from https://developer.hashicorp.com/vault/tutorials/policies/policies#write-a-policy
  policy = <<EOT
    # Read system health check
    path "sys/health"
    {
      capabilities = ["read", "sudo"]
    }

    # Create and manage ACL policies broadly across Vault

    # List existing policies
    path "sys/policies/acl"
    {
      capabilities = ["list"]
    }

    # Create and manage ACL policies
    path "sys/policies/acl/*"
    {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }

    # Enable and manage authentication methods broadly across Vault

    # Manage auth methods broadly across Vault
    path "auth/*"
    {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }

    # Create, update, and delete auth methods
    path "sys/auth/*"
    {
      capabilities = ["create", "update", "delete", "sudo"]
    }

    # List auth methods
    path "sys/auth"
    {
      capabilities = ["read"]
    }

    # Enable and manage the key/value secrets engine at `secrets/` path

    # List, create, update, and delete key/value secrets
    path "secrets/*"
    {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }

    # Manage secrets engines
    path "sys/mounts/*"
    {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }

    # List existing secrets engines.
    path "sys/mounts"
    {
      capabilities = ["read"]
    }
EOT
}

# create admin users.  Users must manually change their passwords after creation.  Note that terraform will ignore updates to the password, since no mechanism to read that password exists.
resource "vault_generic_endpoint" "stephan" {
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/stephan"
  ignore_absent_fields = true

  data_json = <<EOT
    {
      "policies": ["admin"],
      "password": "PUTSOMETHINGSECUREHERE"
    }
  EOT
  lifecycle {
    ignore_changes = [
      data_json
    ]
  }
}

resource "vault_generic_endpoint" "argocd" {
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/argocd"
  ignore_absent_fields = true

  data_json = <<EOT
    {
      "policies": ["admin"],
      "password": "PUTSOMETHINGSECUREHERE"
    }
  EOT
  lifecycle {
    ignore_changes = [
      data_json
    ]
  }
}



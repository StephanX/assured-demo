# idea shamelessly stolen from https://github.com/hashicorp/terraform-provider-kubernetes/issues/723#issuecomment-1130887972

# creates a service account and simple job that deletes the eks auto-generated default storage class 'gp2' (which is unencrypted) permitting terraform to re-create it as an encrypted storage class.  The variable 'cluster_bootstrap' toggles this behavior.

# properly executed with `terraform apply $(for i in $(ls fixtures*) ; do echo -n "-var-file=${i} " ; done) -var='cluster_bootstrap=true' -auto-approve`
resource "kubernetes_service_account" "replace_storage_class_gp2" {
  metadata {
    name      = "replace-storage-class-gp2"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role" "replace_storage_class_gp2" {
  metadata {
    name = "replace-storage-class-gp2"
  }

  rule {
    api_groups     = ["storage.k8s.io" ]
    resources      = ["storageclasses"]
    resource_names = ["gp2"]
    verbs          = ["get", "delete"]
  }
}

resource "kubernetes_cluster_role_binding" "replace_storage_class_gp2" {
  metadata {
    name      = "replace-storage-class-gp2"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.replace_storage_class_gp2.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.replace_storage_class_gp2.metadata[0].name
    namespace = "kube-system"
  }

}

resource "kubernetes_job" "replace_storage_class_gp2" {
  count = var.cluster_bootstrap ? 1 : 0
  depends_on = [
    kubernetes_cluster_role_binding.replace_storage_class_gp2
  ]
  metadata {
    name      = "replace-storage-class-gp2"
    namespace = "kube-system"
  }
  spec {
    template {
      metadata {}
      spec {
        service_account_name = kubernetes_service_account.replace_storage_class_gp2.metadata[0].name
        container {
          name    = "replace-storage-class-gp2"
          image   = "bitnami/kubectl:latest"
          command = ["/bin/sh", "-c", "kubectl delete storageclass gp2"]
        }
        restart_policy = "Never"
      }
    }
  }
  wait_for_completion = true
  timeouts {
    create = "5m"
  }
}

resource "kubernetes_storage_class" "gp2" {
  metadata {
    name = "gp2"
  }
  storage_provisioner = "kubernetes.io/aws-ebs"
  reclaim_policy      = "Delete"
  parameters = {
    encrypted = "true"
    fsType = "ext4"
    type = "gp2"
    allow_volume_expansion = "true"
  }
  depends_on = [
    kubernetes_job.replace_storage_class_gp2
  ]
}

resource "kubernetes_storage_class" "gp2-encrypted" {
  metadata {
    name = "gp2-encrypted"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "kubernetes.io/aws-ebs"
  reclaim_policy      = "Delete"
  parameters = {
    encrypted = "true"
    fsType = "ext4"
    type = "gp2"
    allow_volume_expansion = "true"
  }
}

resource "kubernetes_storage_class" "gp2-retain" {
  metadata {
    name = "gp2-retain"
  }
  storage_provisioner = "kubernetes.io/aws-ebs"
  reclaim_policy      = "Retain"
  parameters = {
    encrypted = "true"
    fsType = "ext4"
    type = "gp2"
  }
}
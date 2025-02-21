# resource "kubernetes_namespace" "argo" {
#   metadata {
#     name = "argo"
#     labels = {
#       notice = "Managed_by_terraform.DO_NOT_EDIT_BY_HAND"
#     }
#   }
# }

# # All versions derived from https://github.com/argoproj/argo-helm/releases

# data "template_file" "argo-cd-helm-values" {
#   template = <<-EOF
#     workflow:
#       serviceAccount:
#         create: true
#         name: "argo-workflow"
#       rbac:
#         create: true
#     controller:
#       workflowNamespaces:
#         - default
#         - foo
#         - bar
#   EOF
# }

# resource "helm_release" "argo-cd" {
#   name        = "argo-cd"
#   repository  = "https://argoproj.github.io"
#   chart       = "argo-cd"
#   namespace   = "argo-cd"
#   version     = "v7.8.2"
#   values = [
#     data.template_file.argo-cd-helm-values.rendered
#   ]
# }


# # data "template_file" "argo-workflows" {
# #   template = <<-EOF
# #     workflow:
# #       serviceAccount:
# #         create: true
# #         name: "argo-workflow"
# #       rbac:
# #         create: true
# #     controller:
# #       workflowNamespaces:
# #         - default
# #         - foo
# #         - bar
# #   EOF
# # }

# # # https://github.com/argoproj/argo-helm
# # resource "helm_release" "argo-events" {
# #   name             = "argo-events"
# #   repository       = "https://argoproj.github.io"
# #   chart            = "argo-events"
# #   namespace        = "argo-events"
# #   values = [
# #     data.template_file.traefik-helm-values.rendered
# #   ]
# # }

# # data "template_file" "traefik-helm-values" {
# #   template = <<-EOF
# #     service:
# #       annotations:
# #   EOF
# # }

# # # https://github.com/argoproj/argo-helm
# # resource "helm_release" "argo-events" {
# #   name             = "argo-events"
# #   repository       = "https://argoproj.github.io"
# #   chart            = "argo-events"
# #   namespace        = "argo-events"
# #   values = [
# #     data.template_file.traefik-helm-values.rendered
# #   ]
# # }
module "label" {
  source  = "cloudposse/label/null"
  version = "~> 0.25.0"

  attributes = ["cluster"]

  context = module.this.context
}

locals {

  # public_access_cidrs = var.public_access_cidrs
  # kubeconfig_path_enabled = var.kubeconfig_path_enabled
  # kubeconfig_path = var.kubeconfig_path
  # endpoint_private_access = var.endpoint_private_access

  # The usage of the specific kubernetes.io/cluster/* resource tags below are required
  # for EKS and Kubernetes to discover and manage networking resources
  # https://www.terraform.io/docs/providers/aws/guides/eks-getting-started.html#base-vpc-networking
  tags = { "kubernetes.io/cluster/${module.label.id}" = "shared" }

  # Unfortunately, most_recent (https://github.com/cloudposse/terraform-aws-eks-workers/blob/34a43c25624a6efb3ba5d2770a601d7cb3c0d391/main.tf#L141)
  # variable does not work as expected, if you are not going to use custom ami you should
  # enforce usage of eks_worker_ami_name_filter variable to set the right kubernetes version for EKS workers,
  # otherwise will be used the first version of Kubernetes supported by AWS (v1.11) for EKS workers but
  # EKS control plane will use the version specified by kubernetes_version variable.
  eks_worker_ami_name_filter = "amazon-eks-node-${var.kubernetes_version}*"

  # Define user access map, permits kubectl access for users
  access_entry_map = {
    ("arn:aws:iam::968770163483:user/stephan") = {
      access_policy_associations = {
        ClusterAdmin = {}
      }
    },
    ("arn:aws:iam::968770163483:user/robot") = {
      access_policy_associations = {
        ClusterAdmin = {}
      }
    }
  }

  # required tags to make ALB ingress work https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html
  public_subnets_additional_tags = {
    "kubernetes.io/role/elb" : 1
  }
  private_subnets_additional_tags = {
    "kubernetes.io/role/internal-elb" : 1
  }
}

# https://github.com/cloudposse/terraform-aws-vpc
module "vpc" {
  source  = "cloudposse/vpc/aws"
  version = "2.2.0"

  ipv4_primary_cidr_block = var.vpc_cidr
  assign_generated_ipv6_cidr_block = false
  tags                    = local.tags
  context                 = module.this.context
}

module "subnets" {
  source  = "cloudposse/dynamic-subnets/aws"
  version = "2.4.2"

  availability_zones              = var.availability_zones
  vpc_id                          = module.vpc.vpc_id
  igw_id                          = [module.vpc.igw_id]
  ipv4_cidr_block                 = [module.vpc.vpc_cidr_block]
  nat_gateway_enabled             = true
  nat_instance_enabled            = false
  tags                            = local.tags
  public_subnets_additional_tags  = local.public_subnets_additional_tags
  private_subnets_additional_tags = local.private_subnets_additional_tags

  context = module.this.context
}

output "kubernetes-vpc-id" {
  value = module.vpc.vpc_id
}

module "eks_cluster" {
  source  = "cloudposse/eks-cluster/aws"
  version = "4.6.0"

  region                       = var.region
  subnet_ids                   = concat(module.subnets.private_subnet_ids, module.subnets.public_subnet_ids)
  kubernetes_version           = var.kubernetes_version
  oidc_provider_enabled        = var.oidc_provider_enabled

  # additional work roles to permit additional node groups access:
    # access_entries_for_nodes = {
    #   EC2_LINUX = [module.eks_workers.workers_role_arn, module.eks_workers_2.workers_role_arn]
    # }


  enabled_cluster_log_types    = var.enabled_cluster_log_types
  cluster_log_retention_period = var.cluster_log_retention_period

  # kubernetes_config_map_ignore_role_changes = true
  # apply_config_map_aws_auth = false

  cluster_encryption_config_enabled                         = var.cluster_encryption_config_enabled
  cluster_encryption_config_kms_key_id                      = var.cluster_encryption_config_kms_key_id
  cluster_encryption_config_kms_key_enable_key_rotation     = var.cluster_encryption_config_kms_key_enable_key_rotation
  cluster_encryption_config_kms_key_deletion_window_in_days = var.cluster_encryption_config_kms_key_deletion_window_in_days
  cluster_encryption_config_kms_key_policy                  = var.cluster_encryption_config_kms_key_policy
  cluster_encryption_config_resources                       = var.cluster_encryption_config_resources

  # lock down kubernetes API to our VPN
  public_access_cidrs = var.public_access_cidrs
  endpoint_private_access = var.endpoint_private_access

  addons = var.addons

  access_entry_map = local.access_entry_map
  access_config = {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  # We need to create a new Security Group only if the EKS cluster is used with unmanaged worker nodes.
  # EKS creates a managed Security Group for the cluster automatically, places the control plane and managed nodes into the security group,
  # and allows all communications between the control plane and the managed worker nodes
  # (EKS applies it to ENIs that are attached to EKS Control Plane master nodes and to any managed workloads).
  # If only Managed Node Groups are used, we don't need to create a separate Security Group;
  # otherwise we place the cluster in two SGs - one that is created by EKS, the other one that the module creates.
  # See https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html for more details.
  # create_security_group = false

  # This is to test `allowed_security_group_ids` and `allowed_cidr_blocks`
  # In a real cluster, these should be some other (existing) Security Groups and CIDR blocks to allow access to the cluster
  # allowed_security_group_ids = [module.vpc.vpc_default_security_group_id]
  # allowed_security_group_ids = concat(aws_security_group.bastion_eks_ssh.*.id) # enable with bastion ssh host identified
  allowed_cidr_blocks        = [module.vpc.vpc_cidr_block]

  context = module.this.context
}

module "eks_node_group" {
  # https://github.com/cloudposse/terraform-aws-eks-node-group
  source  = "cloudposse/eks-node-group/aws"
  version = "3.3.0"

  # name = "default"
  block_device_mappings = [
    {
      "device_name": "/dev/xvda"
      "delete_on_termination" = true
      "encrypted": true,
      "volume_size": 100,
      "volume_type": "gp2"
    }
  ]

  subnet_ids                    = module.subnets.private_subnet_ids
  cluster_name                  = module.eks_cluster.eks_cluster_id
  instance_types                = var.instance_types
  desired_size                  = var.desired_size
  min_size                      = var.min_size
  max_size                      = var.max_size
  kubernetes_labels             = var.kubernetes_labels
  # ec2_ssh_key_name              = var.ec2_ssh_key_name
  # ec2_ssh_key_name              = ["${var.name}-eks-worker-ssh"]
  # ec2_ssh_key_name              = [aws_key_pair.eks-worker.key_name]
  # ssh_access_security_group_ids = aws_security_group.bastion_eks_ssh[0].id # Open ssh to the bastion
  # ssh_access_security_group_ids = aws_security_group.bastion_eks_ssh.*.id # Open ssh to the bastion
  # Prevent the node groups from being created before the Kubernetes aws-auth ConfigMap

  module_depends_on = module.eks_cluster.eks_cluster_id

  context = module.this.context

  # # update the worker node, then bounce after the node has joined the cluster
  before_cluster_joining_userdata = [
    "yum update -y"
  ]

  after_cluster_joining_userdata = [
    "reboot"
  ]


}

module "eks_node_group_vault" {
  # https://github.com/cloudposse/terraform-aws-eks-node-group
  source  = "cloudposse/eks-node-group/aws"
  version = "3.3.0"

  name = "vault"


  block_device_mappings = [
    {
      "device_name": "/dev/xvda"
      "delete_on_termination" = true
      "encrypted": true,
      "volume_size": 100,
      "volume_type": "gp2"
    }
  ]

  subnet_ids                    = module.subnets.private_subnet_ids
  cluster_name                  = module.eks_cluster.eks_cluster_id
  instance_types                = ["t3.small"]
  desired_size                  = var.desired_size
  min_size                      = var.min_size
  max_size                      = var.max_size
  kubernetes_labels             = merge(var.kubernetes_labels,
                                    { purpose = "vault" }
                                  )
  kubernetes_taints             = [{
                                  key = "node_role"
                                  value  = "vault"
                                  effect = "NO_SCHEDULE"
                                }]
  # kubernetes_labels             = var.kubernetes_labels
  # ec2_ssh_key_name              = var.ec2_ssh_key_name
  # ec2_ssh_key_name              = ["${var.name}-eks-worker-ssh"]
  # ec2_ssh_key_name              = [aws_key_pair.eks-worker.key_name]
  # ssh_access_security_group_ids = aws_security_group.bastion_eks_ssh[0].id # Open ssh to the bastion
  # ssh_access_security_group_ids = aws_security_group.bastion_eks_ssh.*.id # Open ssh to the bastion
  # Prevent the node groups from being created before the Kubernetes aws-auth ConfigMap

  module_depends_on = module.eks_cluster.eks_cluster_id

  context = module.this.context

  # # update the worker node, then bounce after the node has joined the cluster
  # before_cluster_joining_userdata = [
  #   "yum update -y"
  # ]

  # after_cluster_joining_userdata = [
  #   "reboot"
  # ]

}

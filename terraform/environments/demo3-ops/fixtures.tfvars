root_name = "demo3"
company = "assured"
environment = "ops"

# kube_cluster_name = "mcp"
kubernetes_version = "1.32" # handy checker: https://endoflife.date/amazon-eks

root_domain = "deadmanshour.com"

letsencrypt_email = "certs@stephanx.net"
cert_manager_domains = [
  "deadmanshour.com"
]

region = "us-west-2"
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
vpc_cidr = "10.255.240.0/20"

# public_access_cidrs = ["1.2.3.4/32"] # VPN placeholder
public_access_cidrs = [ "0.0.0.0/0"]

endpoint_private_access = true # must be true, if public_access_cidrs is set to just about anything except 0.0.0.0, or the worker nodes will not be able to talk to the masters.

# instance type and count for initial cluster creation
instance_types = ["t3.small"]
# instance_types = ["m5.large"]
desired_size = 3
max_size = 3
min_size = 3

// Demo subnets for our resources.
vpc_public_subnets = [
    "10.255.250.0/23",
    "10.255.252.0/23",
    "10.255.254.0/23"
  ]

# 'namespace' is only used to add additional naming to the cluster
namespace = ""

# 'stage' again, only used to add additional naming to the cluster
stage = ""

attributes = ["cluster"]

oidc_provider_enabled = true

enabled_cluster_log_types = ["audit"]

cluster_log_retention_period = 1

kubernetes_labels = {}

cluster_encryption_config_enabled = true

addons = [
  {
    addon_name               = "vpc-cni"
    addon_version            = null
    resolve_conflicts        = "NONE"
    service_account_role_arn = null
  }
]
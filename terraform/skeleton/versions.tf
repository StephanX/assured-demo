terraform {
  required_providers {
    # https://registry.terraform.io/providers/hashicorp/aws/latest
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.35.1"
    }
    helm = {
      source = "hashicorp/helm"
      version = ">= 2.17.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.19.0" # https://github.com/gavinbunney/terraform-provider-kubectl
    }
    vault = {
      source = "hashicorp/vault"
      # version = ">=3.12.0"
    }
  }

  # declare version of terraform to be used
  # `curl -s  "https://api.github.com/repos/hashicorp/terraform/releases/latest" | jq .name -r`
  required_version = "~> 1.10"
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}




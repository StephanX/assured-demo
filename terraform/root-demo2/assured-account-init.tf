# loosely referenced from https://cloudly.engineer/2020/create-new-aws-accounts-with-organizations-and-terraform/aws/

# import existing org: `terraform import aws_organizations_organization.stephanx "o-m2ph2ajkpk"`

# Provides a resource to create an AWS organization.
resource "aws_organizations_organization" "stephanx" {

  # List of AWS service principal names for which
  # you want to enable integration with your organization

  aws_service_access_principals = [
    "account.amazonaws.com"
  ]

  feature_set = "ALL"
}

resource "aws_organizations_organizational_unit" "assured-demo2" {
  name      = "assured-demo2"
  parent_id = aws_organizations_organization.stephanx.roots[0].id
}

resource "aws_organizations_account" "assured-demo2" {
  name  = "assured-demo2"
  email = "stephan+assured-demo2@stephanx.net"

  tags = {
    Name  = "assured-demo2"
    Role  = "demo project"
  }

  parent_id = aws_organizations_organizational_unit.assured-demo2.id
}

provider "aws" {
  region  = "us-west-2"  # Replace with your region
}

output "organizations_account_arn" {
  value       = "${join("", aws_organizations_account.assured-demo2.*.arn)}"
  description = "The ARN for this account."
}

output "organizations_account_id" {
  value       = "${join("", aws_organizations_account.assured-demo2.*.id)}"
  description = "The AWS account id."
}

output "organizations_account_name" {
  value       = "${join("", aws_organizations_account.assured-demo2.*.name)}"
  description = "The AWS account name."
}


# loosely referenced from https://cloudly.engineer/2020/create-new-aws-accounts-with-organizations-and-terraform/aws/

# Provides a resource to create an AWS organization.
resource "aws_organizations_organization" "stephanx" {

  # List of AWS service principal names for which
  # you want to enable integration with your organization

  aws_service_access_principals = [
    "account.amazonaws.com"
  ]

  feature_set = "ALL"
}

resource "aws_organizations_organizational_unit" "assured-demo1" {
  name      = "assured-demo1"
  parent_id = aws_organizations_organization.stephanx.roots[0].id
}

resource "aws_organizations_account" "assured-demo1" {
  name  = "assured-demo1"
  email = "stephan+assured-demo1@stephanx.net"

  tags = {
    Name  = "assured-demo1"
    Role  = "demo project"
  }

  parent_id = aws_organizations_organizational_unit.assured-demo1.id
}

provider "aws" {
  region  = "us-west-2"  # Replace with your region
}

output "organizations_account_arn" {
  value       = "${join("", aws_organizations_account.assured-demo1.*.arn)}"
  description = "The ARN for this account."
}

output "organizations_account_id" {
  value       = "${join("", aws_organizations_account.assured-demo2.*.id)}"
  description = "The AWS account id."
}

output "organizations_account_name" {
  value       = "${join("", aws_organizations_account.assured-demo3.*.name)}"
  description = "The AWS account name."
}


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


# ### initial security groups

# resource "aws_iam_group" "sre" {
#   name = "SRE"
# }

# resource "aws_iam_policy_attachment" "SRE" {
#   name       = "SRE"
#   groups     = ["SRE"]
#   policy_arn = aws_iam_policy.SRE.arn
# }


# resource "aws_iam_policy" "SRE" {
#   name = "SRE"
#   description = "Policy for SRE related activities"
#   tags = {
#     purpose = "Initial SRE permissions",
#     creator = "sedge"
#   }

#   policy = <<EOF
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Effect": "Allow",
#             "Action": "*",
#             "Resource": "*"
#         }
#     ]
# }
# EOF
# }

# ### bootstrap user

# resource "aws_iam_user" "bootstrap" {
#   name = "assured-bootstrap"
#   tags = {
#     purpose = "bootstrap IAM account"
#   }
# }

# resource "aws_iam_access_key" "bootstrap" {
#   user = aws_iam_user.bootstrap.name
# }

# resource "aws_iam_user_group_membership" "bootstrap" {
#   user       = aws_iam_user.bootstrap.name
#   groups     = ["SRE"]
# }

# output "bootstrap_user_name" {
#   value     = aws_iam_user.bootstrap.name
# }

# output "bootstrap_id" {
#   value = aws_iam_access_key.bootstrap.id
# }

# data "template_file" "bootstrap_iam_secret" {
#   template = aws_iam_access_key.bootstrap.encrypted_secret
# }

# output "bootstrap_secret" {
#   value     = data.template_file.bootstrap_iam_secret.rendered
#   sensitive = false
# }


# output "bootstrap_secretkey" {
#   value = "${aws_iam_access_key.bootstrap.encrypted_secret}"
# }




output "organizations_account_arn" {
  value       = "${join("", aws_organizations_account.assured-demo1.*.arn)}"
  description = "The ARN for this account."
}

output "organizations_account_id" {
  value       = "${join("", aws_organizations_account.assured-demo1.*.id)}"
  description = "The AWS account id."
}

output "organizations_account_name" {
  value       = "${join("", aws_organizations_account.assured-demo1.*.name)}"
  description = "The AWS account name."
}


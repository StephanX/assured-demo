# stolen from https://mohitgoyal.co/2020/09/30/upload-terraform-state-files-to-remote-backend-amazon-s3-and-azure-storage-account/

locals {
  root_name = var.root_name
  company = var.company
  region = var.region
}

resource "aws_s3_bucket" "terraform-state" {
    bucket = "${local.company}-${local.root_name}-terraform-state"

    # lifecycle {
    #     prevent_destroy = true # prevent the state bucket from accidental deletion.  Comment the entire lifecycle block to destroy
    # }

}

resource "aws_s3_bucket_versioning" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform-locks" {
    name         = "${local.company}-${local.root_name}-terraform-locks"
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "LockID"

    attribute {
        name = "LockID"
        type = "S"
    }
}

output "region" {
  value =  var.region
}

# Terraform doesn't permit variables in backend configurations.  Declaratively write this file.  It will need to be added to source control after creation and removed from source control if/when the teardown.sh script is used.
resource "local_file" "backend_file_test" {
  filename = "terraform-s3-backend-config.tf"
  content = <<-EOT
    terraform {
      backend "s3" {
        bucket = "${local.company}-${local.root_name}-terraform-state"
        key = "${local.company}-${local.root_name}/terraform.tfstate"
        region = "${local.region}"
        dynamodb_table = "${local.company}-${local.root_name}-terraform-locks"
        encrypt = true
      }
    }
  EOT
}


terraform {
  backend "s3" {
    bucket = "assured-demo2-terraform-state"
    key = "assured-demo2/terraform.tfstate"
    region = "us-west-2"
    dynamodb_table = "assured-demo2-terraform-locks"
    encrypt = true
  }
}

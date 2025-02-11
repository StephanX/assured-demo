terraform {
  backend "s3" {
    bucket = "assured-demo1-terraform-state"
    key = "assured-demo1/terraform.tfstate"
    region = "us-west-2"
    dynamodb_table = "assured-demo1-terraform-locks"
    encrypt = true
  }
}

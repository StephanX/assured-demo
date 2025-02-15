terraform {
  backend "s3" {
    bucket = "assured-demo3-terraform-state"
    key = "assured-demo3/terraform.tfstate"
    region = "us-west-2"
    dynamodb_table = "assured-demo3-terraform-locks"
    encrypt = true
  }
}

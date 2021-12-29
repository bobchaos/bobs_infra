# This file is provided for convenience when developing but will be replaced at runtime when using Terragrunt for full deployments
data "terraform_remote_state" "core" {
  backend = "s3"
  config = {
    bucket = "bobs-tfstates-bucket"
    key    = "bobs_infra/core"
    region = "us-east-1"
  }
}
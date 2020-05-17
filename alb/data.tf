data "terraform_remote_state" "core" {
  backend = "s3"
  config {
    bucket = "bobs-tfstates-bucket"
    region = "us-east-1"
    # These will be injected using terragrunt
    key = "${var.remote_state_key}"
  }
}

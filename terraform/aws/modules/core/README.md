# Core

This module manages core assets, like networking objects and support databases. Intended for use with Terragrunt but can work with plain old terraform too.

## Usage

If using Terragrunt, see the associated Terragrunt repo.

If using plain old Terraform:

1. Setup your [Terraform backend](https://www.terraform.io/language/settings/backends): `$EDITOR backend.tfvars`
  1. The backend.tfvars file is gitignored, if you're sharing a backend you'll need to edit that or rename the file in your fork.
  1. I recommend using S3 + DynamoDB (for state locking) backend if you don't already have anything else; it's simple, effective and easily hardened.
1. Create a variable file: `cp priv.tfvars.example priv.tfvars`
1. Edit variable file (All variables have descriptions in variables.tf): `$EDITOR priv.tfvars`
1. [Set your credentials via environment](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html).
1. [Run Terraform](https://www.terraform.io/cli/commands) as usual!
  1. `terraform init`
  1. `terraform plan` # Optional, but applying blindly is pretty much always a bad idea
  1. `terraform apply` # You reviewed that plan, right? :P

## Testing

I recommend testing by setting up a test stack in Terragrunt and executing Inspec manually against it (or with a script, Makefile or whatnot).

A kitchen-terraform file is nonetheless provided for convenience. It wraps the Inpsec profiles found at the root of this repo. There is also a Gemfile at the root.

```bash
cd path/to/repo/root
bundle install

bundle exec kitchen test
```
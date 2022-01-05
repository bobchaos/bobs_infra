# infra-core

Tests the `core` terraform module.

##  Usage

[Set your credentials via environment](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html) and [run the profile](https://docs.chef.io/inspec/cli/#exec)!

This profile is intended for use with kitchen-terraform, which should automatically provide all required inputs via the Terraform-outputs to Inspec input kitchen-tf functionality.

To use this manually, you'll need to create an `inputs.yml` file and set all input values. See `inspec.yml` for a list of required inputs.

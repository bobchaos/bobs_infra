# bobs\_infra
Experiments with Cinc, TF, TG and whatever catches my attention. Not intended for distribution, and as such I'm playing fast and loose with my devlopment practices, but you're welcome to fork or copy pieces.

## General Functioning and caveats

At this time, this consists mostly of terraform code intended to create a lab from scratch, and toss it when I'm done for the day. Things that do not conflict with that notion will ere on the side of "Enterprise Grade", to the best of my abilities.

It includes Packer templates to generate machine images, Terraform modules for standalone or Terragrunt usage, and Inspec profiles to test the results. Terragrunt is the recommended way to use the TF modules as they have shared variables and dependencies.

### Terraform Modules

Each module contains it's own README.md with usage and testing information.

All permissions are given using the principle of least privilege. Networking permissions are a bit looser so I can demo this from anywhere, and because writting egress rules is no fun :/

Code can be tested using kitchen-terraform and github actions but ideally will also be done using Terragrunt by defining a test stack.

Testing is performed with Chef Inspec&trade; , used under license as I have no commercial purposes and this is a lab. Businesses looking to fork will want to take that into consideration.

#### aws/core

Creates a VPC, a bastion and other assets required by other modules. All other modules depend on this one.

The bastion currently has no configuration, but I'm likely to add a hardening policy based on the works of the folks at [Dev-Sec](https://github.com/dev-sec/).

#### aws/bootstrap_vault

Adds a "bootstrap Vault" to the main VPC. This Hashicorp Vault installation can be used standalone but is intended to "bootstrap" a full-blown Vault cluster. Vault clusters require unique certificates for all it's nodes so this bootstrapping setup allows issuing such certificates to new Vault cluster nodes, ensuring certificates are never re-used across nodes.

#### aws/vault

Adds a Hashicorp Vault cluster, backed by a Hashicorp Consul cluster (included). It depends on the bootstrap_vault module and will not work standalone. It follows the [reference architecture](https://learn.hashicorp.com/tutorials/vault/reference-architecture) provided by Hashicorp.

#### aws/postgres

Creates a Postgres database on RDS.

#### vault_config

Uses the Vault provider to provision the `aws/vault` module with some basic configurations used by the Terragrunt stack.

### Packer templates

The Terraform modules deploy a number of instances. Most of them are built on an immutable model using the Packer templates from this repo.

#### vault_server

Creates a CentOS-based Hashicorp Vault AMI.

#### consul_server

Creates a CentOS-based Hasicorp Consul AMI

#### Golden-AMI

Demonstrating that off-the-shelf image security is significantly better than 100% custom security, not to mention free :P

## Testing

`kitchen test` and enjoy!

## Contributing

This is a just-for-fun project, so I'm not really taking contributions or intend on maintaining it "properly", but if someone's interested in doing that I'd happily contribute to a fork. Do feel free to open issues tho, I'll do my best to address them, provided it's interesting to me o.O

## License

[Apache2.0](https://www.apache.org/licenses/LICENSE-2.0)

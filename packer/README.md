# Packer templates

A short collection of packer templates to package AMIs and other images used in this repo

## consul_server

A Consul server image. Outputs:

- Amzn-linux-2 AMIs

to:

- us-east-1

TODO: Add a KMS encryption key in TF to encrypt the drives.

## vault_server

A Vault server image, with Consul setup in client mode. Outputs

- Amzn-linux-2 AMIs

to:

- us-east-1
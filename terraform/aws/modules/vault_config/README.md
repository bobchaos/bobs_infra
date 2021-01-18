# Vault_config

The `vault` module spawns a Consul-backed Vault cluster. This module is used to fill it with goodies!

Also includes additional Consul setup for the dedicated cluster, notably ACLs to ensure Vault is the only client.

## Dos and Don'ts

This module of course deals with very sensitive stuff, here's a short list of things to keep in mind when adding things to it.

Do:

- Mount backends
- Provision configuration files that don't have secrets in them
- Provision Vault roles or Consul ACLs

Don't:

- Populate secrets;
    - These will be visible in TFState files. TF14, however, introduces ways to hide them from outputs, plans and logs.
    - This module stashes it's remote state in a seperate folder with different access policy to mitigate the issue
- Inject secret configuration files
    - It is better to have the instances fetch or generate those secrets themselves with cloud-init scripts.
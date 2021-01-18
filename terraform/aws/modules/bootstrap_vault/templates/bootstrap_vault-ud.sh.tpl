#!/bin/bash
# This script is meant to be run in the User Data of each EC2 Instance while it's booting. The script uses the
# run-consul script to configure and start Consul in client mode and then the run-vault script to configure and start
# Vault in server mode. Note that this script assumes it's running in an AMI built from the Packer template in
# examples/vault-consul-ami/vault-consul.json.

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# The Packer template puts the TLS certs in these file paths
readonly VAULT_TLS_CERT_FILE="/opt/vault/tls/vault.crt.pem"
readonly VAULT_TLS_KEY_FILE="/opt/vault/tls/vault.key.pem"

/opt/vault/bin/run-vault --tls-cert-file "$VAULT_TLS_CERT_FILE"  --tls-key-file "$VAULT_TLS_KEY_FILE"

# Wait for Vault to be online, then initialize it, securing restore key (I'm alone, so there's only one :P) with PGP.
timeout 300 bash -c 'until curl localhost:8200; do echo "Waiting for Vault" && sleep 5; done' || echo "Timed out waiting for Vault to startup."

timeout 300 bash -c 'while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:8200)" != "200" ]]; do'
    case $(curl -s -o /dev/null -w ''%{http_code}'' localhost:8200) in
        503)
            echo 'Vault is sealed. This script assumes KMS auto-unseal is enabled and has no handling for a sealed Vault. Aborting.'
            exit 1
        4.*)
            echo 'Vault appears to be misconfigured; It is functional but inactive. Aborting.'
            exit 1
        501)
            # Initialize and upload recovery key to AWS Secrets Manager
            echo 'Vault is uninitialized; Initalizing'
            init_data = vault operator init -format json\
                -root-token-pgp-key "/opt/vault/pgp/${pgp_pubkey_name}"\
                -recovery-pgp-keys "/opt/vault/pgp/${pgp_pubkey_name}"\
                -recovery-shares 1\
                -recovery-threshold 1
            aws secretsmanager put-secret-value --secret-id ${recovery_key_asm_secret_name} \
                --secret-string $init_data
            echo "Vault initialized. All secrets stored in ASM secret \`${recovery_key_asm_secret_name}\`"
            break
    esac
done || echo 'Timed out waiting for initialisation.'
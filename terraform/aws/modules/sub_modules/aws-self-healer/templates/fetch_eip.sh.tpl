#!/bin/sh
# Redirect all output to file
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/var/log/fetch_eip.sh.out 2>&1

echo "Fetching EIP ${eip_alloc_id}"
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
INSTANCEID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

# Check that AWS cli and jq are installed
command -v /usr/local/bin/aws >/dev/null 2>&1 || { echo >&2 "$0 requires aws-cli but it's not found in \$PATH. Did init.sh run correctly? Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "$0 requires jq but it's not found in \$PATH. Did init.sh run correctly? Aborting."; exit 1; }

/usr/local/bin/aws ec2 associate-address --allow-reassociation --instance-id $INSTANCEID --allocation-id ${eip_alloc_id}

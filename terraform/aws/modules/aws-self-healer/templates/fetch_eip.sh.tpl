#!/bin/sh
echo "Fetching EIP ${eip_alloc_id}"
INSTANCEID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
echo "this is a placeholder for an EIP fetching script" >> /tmp/placeholder_report.txt

# Check that AWS cli and jq are installed
command -v /usr/local/bin/aws2 >/dev/null 2>&1 || { echo >&2 'I require aws2 but it's not found in $PATH. Did init.sh run correctly? Aborting.'; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 'I require jq but it's not found in $PATH. Did init.sh run correctly? Aborting.'; exit 1; }

# During failure scenarios the old instance might hold on the the EIP for a bit
# So we setup a test and wait a bit for it to be available.

/usr/local/bin/aws2 ec2 associate-address --instance-id $INSTANCEID --allocation-id ${eip_alloc_id}

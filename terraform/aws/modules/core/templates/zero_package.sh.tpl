#!/bin/bash
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>install_cinc.sh.out 2>&1

# Get cinc and zero package
curl -L https://omnitruck.cinc.sh/install.sh -v ${cinc_version} | bash
aws2 s3 cp s3://${bucket_name}/${zero_package}

# Run the package
cinc-client -z

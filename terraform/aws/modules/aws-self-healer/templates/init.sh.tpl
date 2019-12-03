#!/bin/sh

# Prerequisites for other scripts
# Check that we have connectivity.
echo -e "Checking for network connectivty\n"
until ping 8.8.8.8 -c 1
do
  sleep 5
done

echo -e "Network connectivity established\n"

# Run updates. Someday I'll setup a spacewalk or something
yum update -y

# Get AWS CLI. V2 is beta, but also 100% self-contained, making it 1000% less of a hassle
curl "https://d1vvhvl2y92vvt.cloudfront.net/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Extract and install aws2 + jq to parse it's output
yum install -y unzip jq
unzip awscliv2.zip
./aws/install
rm -f awscliv2.zip

mkdir -p /usr/local/bin

ln -s /usr/local/aws-cli/v2/current/bin/aws2 /usr/local/bin/aws2

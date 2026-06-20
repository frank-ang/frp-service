#!/bin/bash
# Associates the pre-created Elastic IP (allocation id injected by Terraform)
# to whichever instance the Auto Scaling Group launches. Runs on every boot,
# so a spot interruption + replacement instance re-attaches the same IP.
set -euo pipefail

EIP_ALLOCATION_ID="${eip_allocation_id}"
TOKEN_TTL=21600

# Ubuntu's stock AMI does not ship the AWS CLI (unlike Amazon Linux), so
# install it on first boot if it's missing. Subsequent boots skip this.
if ! command -v aws >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y unzip curl
  curl -sf "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
  rm -rf /tmp/awscliv2.zip /tmp/aws
fi

get_token() {
  curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: $TOKEN_TTL"
}

TOKEN="$(get_token)"
INSTANCE_ID="$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)"
REGION="$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region)"

echo "Associating Elastic IP allocation $EIP_ALLOCATION_ID to instance $INSTANCE_ID in $REGION"

# Retry briefly in case networking/IAM creds aren't fully ready yet.
for i in $(seq 1 10); do
  if aws ec2 associate-address \
    --instance-id "$INSTANCE_ID" \
    --allocation-id "$EIP_ALLOCATION_ID" \
    --region "$REGION" \
    --allow-reassociation; then
    echo "Elastic IP associated successfully."
    break
  fi
  echo "Attempt $i failed, retrying in 5s..."
  sleep 5
done

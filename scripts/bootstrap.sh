#!/usr/bin/env bash
# Create the state bucket for one environment and write
# terraform/backend.<env>.hcl. Terraform can't create the bucket that holds
# its own state, so this runs once per account before the first init.
# Safe to re-run.
#
#   scripts/bootstrap.sh <dev|stage|prod>
#
# The bucket is <project>-terraform-backend-<env>-<account id>. The account id
# keeps the name globally unique without random suffixes, and is how
# scripts/terraform.sh checks it is talking to the right account.
set -euo pipefail

env=${1:-}
case $env in
dev | stage | prod) ;;
*)
  echo "usage: $0 <dev|stage|prod>" >&2
  exit 2
  ;;
esac

root=$(cd "$(dirname "$0")/.." && pwd)
export AWS_PROFILE="${PROFILE_PREFIX:-showcase}-$env"
region=${AWS_REGION:-us-east-1}

account=$(aws sts get-caller-identity --query Account --output text)
bucket="${PROJECT:-showcase}-terraform-backend-$env-$account"

if ! aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
  if [[ $region == us-east-1 ]]; then
    aws s3api create-bucket --bucket "$bucket" >/dev/null
  else
    aws s3api create-bucket --bucket "$bucket" --create-bucket-configuration "LocationConstraint=$region" >/dev/null
  fi
  echo "created s3://$bucket"
fi

aws s3api put-bucket-versioning --bucket "$bucket" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$bucket" --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
aws s3api put-public-access-block --bucket "$bucket" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

cat >"$root/terraform/backend.$env.hcl" <<EOF
bucket       = "$bucket"
region       = "$region"
encrypt      = true
use_lockfile = true
EOF
echo "wrote terraform/backend.$env.hcl"

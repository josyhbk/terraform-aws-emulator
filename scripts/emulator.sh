#!/usr/bin/env bash
# Local AWS for this repo: Floci in Docker, one emulated account per profile
# in emulator/aws-config.
#
#   scripts/emulator.sh up [dev|stage|prod]   start it, default account = that env (dev)
#   scripts/emulator.sh down
#
# CloudFront answers viewer requests from the default account only, so `up`
# takes the environment whose site you want to open. CI starts one emulator
# per environment.
set -euo pipefail

IMAGE=floci/floci:2.5.0@sha256:a0fbf944d7f338cc0856f1ef83831ea749ff2be71956eb7a7fce08fc21458e19
NAME=floci
ZONE=showcase.example.com

root=$(cd "$(dirname "$0")/.." && pwd)
export AWS_CONFIG_FILE=$root/emulator/aws-config
prefix=${PROFILE_PREFIX:-showcase}

case ${1:-} in
up)
  env=${2:-dev}
  account=$(aws configure get aws_access_key_id --profile "$prefix-$env")
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  # The Docker socket lets Floci run Lambda functions in real containers.
  # The validation wait keeps new certificates PENDING_VALIDATION for a
  # while, like ACM does until the DNS records resolve.
  docker run -d --name "$NAME" -p 127.0.0.1:4566:4566 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e FLOCI_DEFAULT_ACCOUNT_ID="$account" \
    -e FLOCI_SERVICES_ACM_VALIDATION_WAIT_SECONDS=15 \
    "$IMAGE" >/dev/null
  for _ in $(seq 60); do
    aws --profile "$prefix-dns" sts get-caller-identity >/dev/null 2>&1 && break
    sleep 1
  done
  # The DNS account already has its zone in a real organization
  aws --profile "$prefix-dns" route53 create-hosted-zone --name "$ZONE" \
    --caller-reference "emulator-$(date +%s)" >/dev/null
  echo "emulator up, default account $account ($prefix-$env), zone $ZONE in $prefix-dns"
  echo "export AWS_CONFIG_FILE=$AWS_CONFIG_FILE"
  ;;
down)
  docker rm -f "$NAME" >/dev/null
  # Lambda containers Floci started
  docker ps -aq --filter "name=^floci-" | xargs -r docker rm -f >/dev/null
  ;;
*)
  echo "usage: $0 up [dev|stage|prod] | down" >&2
  exit 2
  ;;
esac

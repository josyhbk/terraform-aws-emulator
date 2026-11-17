#!/usr/bin/env bash
# Run Terraform for one environment.
#
#   scripts/terraform.sh <dev|stage|prod> <init|plan|apply|destroy|output|apply-dns> [terraform args]
#
# Picks the AWS profile <PROFILE_PREFIX>-<env> (prefix defaults to showcase),
# refuses to go on if that profile is not the account that owns the state,
# then inits with backend.<env>.hcl, selects the <env> workspace and runs the
# command with envs/<env>.tfvars.
#
# apply-dns is for the first apply of an environment with a custom domain.
# The hosted zone lives in a separate DNS account (<prefix>-dns), and
# CloudFront rejects a certificate that is not issued yet, so it goes:
#   1. apply only the certificate
#   2. publish its validation records in the DNS account
#   3. wait until ACM reports it ISSUED
#   4. full apply
#   5. point the domain at the distribution
# Every step is idempotent, so an interrupted run can simply be re-run.
set -euo pipefail

usage() {
  echo "usage: $0 <dev|stage|prod> <init|plan|apply|destroy|output|apply-dns> [terraform args]" >&2
  exit 2
}

env=${1:-}
cmd=${2:-}
shift 2 || usage
case $env in dev | stage | prod) ;; *) usage ;; esac

root=$(cd "$(dirname "$0")/.." && pwd)
prefix=${PROFILE_PREFIX:-showcase}
export AWS_PROFILE="$prefix-$env"
backend=backend.$env.hcl
vars=-var-file=envs/$env.tfvars

tf() { terraform -chdir="$root/terraform" "$@"; }

[[ -f $root/terraform/$backend ]] || {
  echo "terraform/$backend not found, run scripts/bootstrap.sh $env first" >&2
  exit 1
}

# The state bucket name ends in the id of the account that owns it
account=$(aws sts get-caller-identity --query Account --output text)
grep -q -- "-$account\"" "$root/terraform/$backend" || {
  echo "profile $AWS_PROFILE is account $account, which does not own the state in terraform/$backend" >&2
  exit 1
}

tf init -input=false -reconfigure -backend-config="$backend" >/dev/null
tf workspace select -or-create "$env" >/dev/null

dns() { aws --profile "$prefix-dns" route53 "$@"; }
upsert() { dns change-resource-record-sets --hosted-zone-id "$1" --change-batch "$2" >/dev/null; }

apply_dns() {
  tf apply "$vars" -target=module.dns_acm "$@"

  local out cert zone_name zone
  out=$(tf output -json)
  cert=$(jq -r '.certificate_arn.value // empty' <<<"$out")
  if [[ -z $cert ]]; then
    echo "enable_dns is off for $env, nothing to validate"
    tf apply "$vars" "$@"
    return
  fi

  zone_name=$(jq -r .dns_zone.value <<<"$out")
  zone=$(dns list-hosted-zones-by-name --dns-name "$zone_name" --max-items 1 \
    --query "HostedZones[?Name=='$zone_name.'].Id | [0]" --output text)
  [[ $zone != None ]] || {
    echo "hosted zone $zone_name not found in $prefix-dns" >&2
    exit 1
  }

  upsert "$zone" "$(jq '{Changes: [.certificate_validation_records.value[] |
    {Action: "UPSERT", ResourceRecordSet: {Name: .name, Type: .type, TTL: 300, ResourceRecords: [{Value: .value}]}}]}' <<<"$out")"
  echo "validation records published in $zone_name, waiting for the certificate"
  aws acm wait certificate-validated --region us-east-1 --certificate-arn "$cert"

  tf apply "$vars" "$@"

  out=$(tf output -json)
  upsert "$zone" "$(jq '.cdn_hosted_zone_id.value as $z | .cdn_domain.value as $d |
    {Changes: [("A", "AAAA") as $t | {Action: "UPSERT", ResourceRecordSet: {Name: .site_domain.value, Type: $t,
      AliasTarget: {HostedZoneId: $z, DNSName: $d, EvaluateTargetHealth: false}}}]}' <<<"$out")"
  echo "$(jq -r .site_domain.value <<<"$out") points at $(jq -r .cdn_domain.value <<<"$out")"
}

case $cmd in
init) ;;
plan | apply | destroy) tf "$cmd" "$vars" "$@" ;;
output) tf output "$@" ;;
apply-dns) apply_dns "$@" ;;
*) usage ;;
esac

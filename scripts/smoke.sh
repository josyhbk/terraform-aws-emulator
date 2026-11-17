#!/usr/bin/env bash
# Check a deployed environment works: the site loads through CloudFront with
# its API URL, an item written through the API reads back, and with DNS on,
# the domain points at the distribution.
#
#   scripts/smoke.sh <dev|stage|prod>
#
# EMULATOR=1 rewrites the AWS hostnames to the ones Floci serves them on.
set -euo pipefail

env=${1:?usage: $0 <dev|stage|prod>}
root=$(cd "$(dirname "$0")/.." && pwd)
out=$("$root/scripts/terraform.sh" "$env" output -json)
get() { jq -r ".$1.value // empty" <<<"$out"; }

site="https://$(get cdn_domain)"
api=$(get api_endpoint)
if [[ -n ${EMULATOR:-} ]]; then
  site=$(sed -E 's|https://([a-z0-9]+)\.cloudfront\.net|http://\1.cloudfront.localhost.floci.io:4566|' <<<"$site")
  api=$(sed -E 's|https://([a-z0-9]+)\.execute-api\.[a-z0-9-]+\.amazonaws\.com|http://\1.execute-api.localhost.floci.io:4566|' <<<"$api")
fi

curl -fsS "$site/" | grep -q '<title>Items</title>'
curl -fsS "$site/config.js" | grep -qF "$(get api_endpoint)"
echo "ok  site $site"

id=$(curl -fsS -X POST -H 'content-type: application/json' -d '{"name":"smoke test"}' "$api/items" | jq -r .id)
curl -fsS "$api/items" | jq -e --arg id "$id" 'any(.[]; .id == $id)' >/dev/null
status=$(curl -s -o /dev/null -w '%{http_code}' -X POST -d 'not json' "$api/items")
[[ $status == 400 ]] || { echo "bad input returned $status, expected 400" >&2; exit 1; }
echo "ok  api  $api"

domain=$(get site_domain)
if [[ -n $domain ]]; then
  zone=$(aws --profile "${PROFILE_PREFIX:-showcase}-dns" route53 list-hosted-zones-by-name \
    --dns-name "$(get dns_zone)" --max-items 1 --query 'HostedZones[0].Id' --output text)
  target=$(aws --profile "${PROFILE_PREFIX:-showcase}-dns" route53 list-resource-record-sets --hosted-zone-id "$zone" \
    --query "ResourceRecordSets[?Name=='$domain.' && Type=='A'].AliasTarget.DNSName | [0]" --output text)
  [[ ${target%.} == "$(get cdn_domain)" ]] || { echo "$domain points at $target, expected $(get cdn_domain)" >&2; exit 1; }
  echo "ok  dns  $domain -> $target"
fi

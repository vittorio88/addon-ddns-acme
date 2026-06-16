#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CALLS=$(mktemp)
trap 'rm -f "$CALLS"' EXIT

function bashio::log.info() { :; }
function bashio::log.debug() { :; }
function bashio::log.warning() { printf 'WARN %s\n' "$*" >&2; }
function bashio::log.error() { printf 'ERROR %s\n' "$*" >&2; }
function bashio::log.trace() { :; }

source "$REPO_ROOT/ddns-acme/rootfs/usr/bin/ddns-acme/dnsapi/dns_dynu.sh"
DNS_API_TOKEN="dynu-token"

function _get_domain_id() {
  domain_id=100328822
}

function _dynu_rest() {
  local method="$1" endpoint="$2" data="${3:-}"
  printf '%s|%s|%s\n' "$method" "$endpoint" "$data" >> "$CALLS"
  case "$method $endpoint" in
    "GET dns/100328822/record")
      response='{"statusCode":200,"dnsRecords":[{"id":111,"hostname":"_acme-challenge.fv-hass.figvic.com","nodeName":"_acme-challenge","recordType":"TXT","textData":"stale"},{"id":222,"hostname":"other.fv-hass.figvic.com","nodeName":"other","recordType":"TXT","textData":"keep"}]}'
      ;;
    "DELETE dns/100328822/record/111")
      response='{"statusCode":200}'
      ;;
    "POST dns/100328822/record")
      response='{"statusCode":200}'
      ;;
    *)
      echo "unexpected dynu call: $method $endpoint" >&2
      return 1
      ;;
  esac
}

dns_dynu_add_txt_record fv-hass.figvic.com new-token

if ! grep -q '^DELETE|dns/100328822/record/111|' "$CALLS"; then
  echo "expected stale TXT record deletion before add" >&2
  cat "$CALLS" >&2
  exit 1
fi
if grep -q '^DELETE|dns/100328822/record/222|' "$CALLS"; then
  echo "should not delete non-challenge TXT record" >&2
  cat "$CALLS" >&2
  exit 1
fi
if ! grep -q '^POST|dns/100328822/record|' "$CALLS"; then
  echo "expected new TXT record POST" >&2
  cat "$CALLS" >&2
  exit 1
fi

echo "PASS Dynu stale TXT cleanup before deploy"

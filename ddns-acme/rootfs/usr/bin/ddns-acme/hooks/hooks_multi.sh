#!/usr/bin/with-contenv bashio
# shellcheck disable=SC2034
set -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
CONFIG_PATH=${CONFIG_PATH:-/data/options.json}
DNS_API_TOKEN=${DNS_API_TOKEN:-unused-during-hook-dispatch-source}

source "$DIR/../dnsapi/dns_dynu.sh"
source "$DIR/../dnsapi/dns_duckdns.sh"
source "$DIR/../dnsapi/dns_cloudflare.sh"

SYS_CERTFILE=$(jq --raw-output '.certfile // "fullchain.pem"' "$CONFIG_PATH")
SYS_KEYFILE=$(jq --raw-output '.keyfile // "privkey.pem"' "$CONFIG_PATH")

get_dns_accounts_json() {
    if [ -n "${DNS_ACCOUNTS_JSON:-}" ]; then
        printf '%s\n' "$DNS_ACCOUNTS_JSON"
    else
        jq -c '[.dns_accounts[] | {provider: .provider, token: .token, domains: (.domains // [])}]' "$CONFIG_PATH"
    fi
}

get_alias_for_domain() {
    local domain="$1"
    jq --raw-output --exit-status "[.aliases[]?|{(.domain):.alias}]|add.\"$domain\" // empty" "$CONFIG_PATH" || true
}

load_account_for_domain() {
    local domain="$1"
    local accounts account_json
    accounts=$(get_dns_accounts_json)
    account_json=$(jq -c --arg domain "$domain" '.[] | select(.domains[]? == $domain)' <<< "$accounts" | head -n 1)

    if [ -z "$account_json" ]; then
        return 1
    fi

    DNS_PROVIDER_NAME=$(jq -r '.provider' <<< "$account_json")
    DNS_API_TOKEN=$(jq -r '.token' <<< "$account_json")
    export DNS_API_TOKEN
    return 0
}

load_account_for_challenge() {
    local domain="$1"
    local alias="$2"

    if load_account_for_domain "$domain"; then
        return 0
    fi

    if [ -n "$alias" ] && load_account_for_domain "$alias"; then
        return 0
    fi

    bashio::log.error "No dns_accounts entry found for ACME challenge domain: $domain"
    return 1
}

deploy_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}" ALIAS
    ALIAS="$(get_alias_for_domain "$DOMAIN")"
    [ -n "$ALIAS" ] || ALIAS="$DOMAIN"

    load_account_for_challenge "$DOMAIN" "$ALIAS"

    bashio::log.info "[${FUNCNAME[0]}] Deploying TXT Challenge for $ALIAS using $DNS_PROVIDER_NAME"
    case "$DNS_PROVIDER_NAME" in
        dynu)
            dns_dynu_add_txt_record "$ALIAS" "$TOKEN_VALUE"
            ;;
        duckdns)
            dns_duckdns_add_txt_record "$ALIAS" "$TOKEN_VALUE"
            ;;
        cloudflare)
            dns_cloudflare_add_txt_record "$ALIAS" "$TOKEN_VALUE"
            ;;
        *)
            bashio::log.error "Unsupported DNS provider for ACME challenge: $DNS_PROVIDER_NAME"
            return 1
            ;;
    esac

    bashio::log.info "[${FUNCNAME[0]}] Settling down for 90s to allow DNS TXT propagation..."
    sleep 90
}

clean_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}" ALIAS
    ALIAS="$(get_alias_for_domain "$DOMAIN")"
    [ -n "$ALIAS" ] || ALIAS="$DOMAIN"

    load_account_for_challenge "$DOMAIN" "$ALIAS"

    case "$DNS_PROVIDER_NAME" in
        dynu)
            dns_dynu_rm_record "$ALIAS" "$TOKEN_VALUE"
            ;;
        duckdns)
            dns_duckdns_rm_txt_record "$ALIAS" "$TOKEN_VALUE"
            ;;
        cloudflare)
            dns_cloudflare_rm_txt_record "$ALIAS" "$TOKEN_VALUE"
            ;;
        *)
            bashio::log.error "Unsupported DNS provider for ACME cleanup: $DNS_PROVIDER_NAME"
            return 1
            ;;
    esac
}

deploy_cert() {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}" TIMESTAMP="${6}"
    bashio::log.info "[${FUNCNAME[0]}] Installing certificate for $DOMAIN to /ssl/$SYS_CERTFILE and /ssl/$SYS_KEYFILE"
    cp -f "$FULLCHAINFILE" "/ssl/$SYS_CERTFILE"
    cp -f "$KEYFILE" "/ssl/$SYS_KEYFILE"
}

HANDLER="$1"; shift
if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge|deploy_cert)$ ]]; then
  "$HANDLER" "$@"
fi

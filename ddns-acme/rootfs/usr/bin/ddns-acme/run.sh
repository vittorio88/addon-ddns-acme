#!/usr/bin/with-contenv bashio

# CONSTANTS
bashio::log.level "info"
ACME_RENEW_WAIT_SECONDS=$(bashio::config 'acme_renew_wait')
CONFIG_PATH=/data/options.json

# Find Basepath
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Set DNS_API_TOKEN
DNS_API_TOKEN=$(bashio::config 'dns_api_token')
export DNS_API_TOKEN

# Set DOMAINS
DOMAINS=$(bashio::config 'domains')
export DOMAINS

# Debug: Print token (masked) and domains
bashio::log.info "DNS API Token (masked): ${DNS_API_TOKEN:0:4}...${DNS_API_TOKEN: -4}"
bashio::log.info "Domains: $DOMAINS"

# Source the appropriate DNS script based on the configuration
DNS_PROVIDER_NAME=$(bashio::config 'dns_provider_name')
bashio::log.info "DNS Provider: $DNS_PROVIDER_NAME"

case "$DNS_PROVIDER_NAME" in
    "dynu")
        source "$DIR/dnsapi/dns_dynu.sh"
        ;;
    "duckdns")
        source "$DIR/dnsapi/dns_duckdns.sh"
        ;;
    *)
        bashio::log.error "Unsupported DNS provider: $DNS_PROVIDER_NAME"
        exit 1
        ;;
esac

source "$DIR/acme.sh"
source "$DIR/ddns.sh"

# VARIABLES
acme_last_renewed_time=0

function update_dns_ip_addresses(){
    declare current_ipv4_address
    if ! hassio_determine_ipv4_address; then
        bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Could not determine IPv4 address"
        return 1
    fi

    declare current_ipv6_address
    if ! hassio_determine_ipv6_address; then
        bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Could not determine IPv6 address"
    fi

    # Update each domain
    for domain in ${DOMAINS}; do
        if [ "$DNS_PROVIDER_NAME" = "dynu" ]; then
            if ! dns_dynu_update_ipv4_ipv6 "$domain" "$current_ipv4_address" "$current_ipv6_address"; then
                bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Could not update Dynu DNS IP address records for domain: $domain"
                return 1
            fi
        elif [ "$DNS_PROVIDER_NAME" = "duckdns" ]; then
            if ! dns_duckdns_update "$domain" "$current_ipv4_address" "$current_ipv6_address"; then
                bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Could not update DuckDNS IP address records for domain: $domain"
                return 1
            fi
        fi
    done

    return 0
}

## INIT
bashio::log.info "[DDNS-ACME - Add On] Initializing."

# get config variables from hassio
if ! hassio_get_config_variables; then
        bashio::log.error "[DDNS-ACME - Add-On ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Failed to get config arguments from Add On Config"
        exit 1
fi

# Debug: Print ACME_PROVIDER_NAME
bashio::log.debug "ACME_PROVIDER_NAME: ${ACME_PROVIDER_NAME}"

# initialize lets encrypt
if ! acme_init $ACME_TERMS_ACCEPTED; then
        bashio::log.error "[DDNS-ACME - Add-On ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Lets Encrypt Init failed."
        exit 1
fi

bashio::log.info "[DDNS-ACME - Add-On]" "Entering main DDNS-ACME Renew loop"
while true; do

    # update IP Addresses
    if ! update_dns_ip_addresses; then
        bashio::log.warning "[DDNS-ACME - Add-On ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Could not update DNS IP address. Skipping ACME Renew."
    else
        now="$(date +%s)"
        acme_time_since_last_renew=$((now - acme_last_renewed_time))
        if [ $acme_time_since_last_renew -ge $ACME_RENEW_WAIT_SECONDS ]; then
            if ! acme_renew "$ACME_PROVIDER_NAME" "$ACME_TERMS_ACCEPTED" "$DNS_PROVIDER_NAME" "$DOMAINS" "$ALIASES"; then
                bashio::log.warning "[DDNS-ACME - Add-On ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "ACME renew failed."
            else
                bashio::log.info "[DDNS-ACME - Add-On]" "ACME renew succeeded."
                acme_last_renewed_time="$(date +%s)"
            fi
        else 
            bashio::log.info "[DDNS-ACME - Add-On]" "acme_time_since_last_renew=$acme_time_since_last_renew is not yet greater than $ACME_RENEW_WAIT_SECONDS. Skipping LE renew for now..."
        fi
    fi

    bashio::log.info "[DDNS-ACME - Add-On]" "Sleeping until Next IP update in $IP_UPDATE_WAIT_SECONDS seconds."
    sleep "${IP_UPDATE_WAIT_SECONDS}"
done

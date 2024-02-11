#!/usr/bin/with-contenv bashio

# # Have BASH tell you which function it errored on, rather than exit silently.
# function error_handler {
#     local exit_code=$?
#     local cmd="${BASH_COMMAND}" # Command that triggered the ERR
#     echo "Error in script at: '${cmd}' with exit code: ${exit_code}"
#     # Simple backtrace
#     local frame=0
#     while caller $frame; do
#         ((frame++));
#     done
# }

# trap 'error_handler' ERR

# CONSTANTS
bashio::log.level "info"
ACME_RENEW_WAIT_SECONDS=43200
CONFIG_PATH=/data/options.json

# Find Basepath
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

source "$DIR/dnsapi/dns_dynu.sh"
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

    # Update each domain
    for domain in ${DOMAINS}; do
        if ! dns_dynu_update_ipv4 "$domain" "$current_ipv4_address"; then
            bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Could not update DNS IP address records for domain: $domain"
            return 1
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

# initialize lets encrypt
if ! acme_init $ACME_TERMS_ACCEPTED; then
        bashio::log.error "[DDNS-ACME - Add-On ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Lets Encrypt Init failed."
        exit 1
fi

bashio::log.info "[DDNS-ACME - Add-On]" "Entering main DDNS-ACME Renew loop"
while true; do

    # update IP Addresses
    if ! update_dns_ip_addresses; then
        bashio::log.warning "[DDNS-ACME - Add-On ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Could not update Dynu DNS IP address. Skipping ACME Renew."
    else
        now="$(date +%s)"
        acme_time_since_last_renew=$((now - acme_last_renewed_time))
        if [ $acme_time_since_last_renew -ge $ACME_RENEW_WAIT_SECONDS ]; then
            if ! acme_renew "$DNS_PROVIDER_NAME" "$ACME_TERMS_ACCEPTED" "$DOMAINS" "$ALIASES"; then
                bashio::log.warning "[DDNS-ACME - Add-On ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "ACME renew failed."
            else
                bashio::log.info "[DDNS-ACME - Add-On]" "ACME renew succeeded."
                acme_last_renewed_time="$(date +%s)"
            fi
        else 
            bashio::log.info  "[DDNS-ACME - Add-On]" "acme_time_since_last_renew=$acme_time_since_last_renew is not yet greater than $ACME_RENEW_WAIT_SECONDS. Skipping LE renew for now..."
        fi
    fi

    bashio::log.info "[DDNS-ACME - Add-On]" "Sleeping until Next IP update in $IP_UPDATE_WAIT_SECONDS seconds."
    sleep "${IP_UPDATE_WAIT_SECONDS}"
done

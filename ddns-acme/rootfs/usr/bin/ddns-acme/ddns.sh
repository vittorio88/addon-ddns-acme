#!/usr/bin/with-contenv bashio

# CONSTANTS
QUERY_URL_IPV4="https://ipv4.text.wtfismyip.com"
QUERY_URL_IPV6="https://ipv6.text.wtfismyip.com"
LAST_IP_UPDATE_FILE="/data/last_ip_update"

function is_domain() {
    local domain="$1"

    # Regex for checking if a string is a domain name with at least one period
    # This pattern checks for a sequence of alphanumeric characters (including hyphens)
    # followed by a period, and then another sequence of alphanumeric characters.
    local regex="^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$"

    if [[ $domain =~ $regex ]]; then
        bashio::log.debug "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "$domain is a valid domain."
        return 0
    else
        bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "$domain is not a valid domain."
        return 1
    fi
}

function hassio_determine_ipv4_address(){
    case "$IPV4_UPDATE_METHOD" in
        "skip update")
            bashio::log.info "Skipping IPv4 address update"
            return 0
            ;;
        "query external server")
            ipv4_queried=$(curl -s -f -m 10 "${QUERY_URL_IPV4}")
            if [[ ${ipv4_queried} == *.* ]]; then
                bashio::log.info "[${FUNCNAME[0]}]" "According to: ${QUERY_URL_IPV4} , IPv4 address is ${ipv4_queried}"
                current_ipv4_address=${ipv4_queried}
                return 0
            else
                bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "It appears ipv4_queried: ${ipv4_queried} returned from ${QUERY_URL_IPV4} is not an IP address"
                return 1
            fi
            ;;
        "get interface address via bashio")
            current_ipv4_address=$(bashio::network.ipv4_address)
            if [[ ${current_ipv4_address} == *.* ]]; then
                bashio::log.info "[${FUNCNAME[0]}]" "IPv4 address from bashio: ${current_ipv4_address}"
                return 0
            else
                bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Failed to get valid IPv4 address from bashio"
                return 1
            fi
            ;;
        "use fixed address")
            if [[ -n "$IPV4_FIXED" && ${IPV4_FIXED} == *.* ]]; then
                bashio::log.info "Using fixed IPv4 address: ${IPV4_FIXED}"
                current_ipv4_address=${IPV4_FIXED}
                return 0
            else
                bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Invalid or missing fixed IPv4 address"
                return 1
            fi
            ;;
        *)
            bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Invalid IPv4 update method: ${IPV4_UPDATE_METHOD}"
            return 1
            ;;
    esac
}

function hassio_determine_ipv6_address(){
    case "$IPV6_UPDATE_METHOD" in
        "skip update")
            bashio::log.info "Skipping IPv6 address update"
            return 0
            ;;
        "query external server")
            ipv6_queried=$(curl -s -f -m 10 "${QUERY_URL_IPV6}")
            if [[ ${ipv6_queried} == *:* ]]; then
                bashio::log.info "[${FUNCNAME[0]}]" "According to: ${QUERY_URL_IPV6} , IPv6 address is ${ipv6_queried}"
                current_ipv6_address=${ipv6_queried}
                return 0
            else
                bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "It appears ipv6_queried: ${ipv6_queried} returned from ${QUERY_URL_IPV6} is not an IP address"
                return 1
            fi
            ;;
        "get interface address via bashio")
            bashio::cache.flush_all
            for addr in $(bashio::network.ipv6_address); do
                # Skip non-global addresses
                if [[ ${addr} != fe80:* && ${addr} != fc* && ${addr} != fd* ]]; then
                    current_ipv6_address=${addr%/*}
                    bashio::log.info "[${FUNCNAME[0]}]" "IPv6 address from bashio: ${current_ipv6_address}"
                    return 0
                fi
            done
            bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Failed to get valid IPv6 address from bashio"
            return 1
            ;;
        "use fixed address")
            if [[ -n "$IPV6_FIXED" && ${IPV6_FIXED} == *:* ]]; then
                bashio::log.info "Using fixed IPv6 address: ${IPV6_FIXED}"
                current_ipv6_address=${IPV6_FIXED}
                return 0
            else
                bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Invalid or missing fixed IPv6 address"
                return 1
            fi
            ;;
        *)
            bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Invalid IPv6 update method: ${IPV6_UPDATE_METHOD}"
            return 1
            ;;
    esac
}

function hassio_get_config_variables(){

    if bashio::config.has_value "ipv4_fixed"; then IPV4_FIXED=$(bashio::config 'ipv4_fixed'); else IPV4_FIXED=""; fi
    IPV4_UPDATE_METHOD=$(bashio::config 'ipv4_update_method');
    if bashio::config.has_value "ipv6_fixed"; then IPV6_FIXED=$(bashio::config 'ipv6_fixed'); else IPV6_FIXED=""; fi
    IPV6_UPDATE_METHOD=$(bashio::config 'ipv6_update_method');
    if bashio::config.has_value "aliases"; then ALIASES=$(bashio::config 'aliases'); else ALIASES=""; fi

    DNS_PROVIDER_NAME=$(bashio::config 'dns_provider_name')
    DNS_API_TOKEN=$(bashio::config 'dns_api_token')
    DOMAINS=$(bashio::config 'domains')
    IP_UPDATE_WAIT_SECONDS=$(bashio::config 'ip_update_wait_seconds')
    ACME_PROVIDER_NAME=$(bashio::config 'acme_provider_name')
    ACME_TERMS_ACCEPTED=$(bashio::config 'acme_accept_terms')

    # Check if DOMAINS are valid domains.
    for domain in ${DOMAINS}; do
       if is_domain $domain; then
            bashio::log.debug "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "domain $domain is a valid domain."
        else
            bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "domain $domain is not a valid domain... "
            return 1
        fi
    done

    # Check if ALIASES are valid domains.
    for domain in $ALIASES; do
        for alias in $domain; do
            if is_domain $alias; then
                bashio::log.debug "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "alias $domain is a valid domain."
            else
                bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "alias $domain is not a valid domain..."
                return 1
            fi
        done
    done

    # Check if /data/options.json is healthy
    if jq "select(.domain != null)" "$CONFIG_PATH" ; then
        bashio::log.debug "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "jq \"select(.domain != null)\" /data/options.json returned 0"
    else
        bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "jq \"select(.domain != null)\" /data/options.json did not 0"
        return 1
    fi

    return 0
}

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

    echo "$(date +%s)" > "${LAST_IP_UPDATE_FILE}"
    return 0
}

function get_last_ip_update_time() {
    if [ -f "${LAST_IP_UPDATE_FILE}" ]; then
        cat "${LAST_IP_UPDATE_FILE}"
    else
        echo "0"
    fi
}

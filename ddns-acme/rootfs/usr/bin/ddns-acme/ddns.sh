#!/usr/bin/with-contenv bashio

# CONSTANTS
QUERY_URL_IPV4="https://ipv4.text.wtfismyip.com"

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

    # Determine IPv4 Address
    if [[ -n "$IPV4_FIXED" ]]; then # use fixed IPv4 address
        bashio::log.info "Using parsed argument for fixed IPv4: ${IPV4_FIXED}"
        if [[ ${IPV4_FIXED} == *.* ]]; then
            current_ipv4_address=${IPV4_FIXED}
            return 0
        else
            bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "It appears the Add-On Argument: ipv4_fixed is not an IP address"
            exit 1
        fi
    else  # Ask external server for my IPv4 address, since HA probably doesn't know it.
        ipv4_queried=$(curl -s -f -m 10 "${QUERY_URL_IPV4}")
        if [[ ${ipv4_queried} == *.* ]]; then
            bashio::log.info "[${FUNCNAME[0]}]" "According to: ${QUERY_URL_IPV4} , IPv4 address is ${ipv4_queried}"
            current_ipv4_address=${ipv4_queried}
            return 0
        else
            bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "It appears ipv4_queried: ${ipv4_queried} returned from ${QUERY_URL_IPV4} is not an IP address"
            return 1
        fi
    fi
    return 1
    
}

function hassio_get_config_variables(){

    if bashio::config.has_value "ipv4_fixed"; then IPV4_FIXED=$(bashio::config 'ipv4_fixed'); else IPV4_FIXED=""; fi
    if bashio::config.has_value "aliases"; then ALIASES=$(bashio::config 'aliases'); else ALIASES=""; fi

    DNS_PROVIDER_NAME=$(bashio::config 'dns_provider.provider_name')
    DNS_API_TOKEN=$(bashio::config 'dns_provider.dns_api_token')
    DOMAINS=$(bashio::config 'domains')
    IP_UPDATE_WAIT_SECONDS=$(bashio::config 'ip_update_wait_seconds')
    ACME_PROVIDER_NAME=$(bashio::config 'acme_provider.provider_name')
    ACME_TERMS_ACCEPTED=$(bashio::config 'acme_provider.accept_terms')

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

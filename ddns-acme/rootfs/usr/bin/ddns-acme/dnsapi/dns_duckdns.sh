#!/usr/bin/with-contenv bashio
# shellcheck disable=SC2034

# Check if DNS_API_TOKEN is set
if [ -z "$DNS_API_TOKEN" ]; then
    bashio::log.error "DNS_API_TOKEN is not set. Please make sure it's configured correctly in the add-on settings."
    exit 1
fi

dns_duckdns_add_txt_record() {
    local domain="${1}"
    local txt_value="${2}"
    local duckdns_token="$DNS_API_TOKEN"
    local duckdns_domain

    # Extract the subdomain from the full domain
    duckdns_domain=$(echo "$domain" | sed -E 's/(.*)\.duckdns\.org/\1/')

    bashio::log.trace "${FUNCNAME[0]}" "${domain}" "${txt_value}"
    bashio::log.info "Adding TXT record for ${domain}"

    local url="https://www.duckdns.org/update?domains=${duckdns_domain}&token=${duckdns_token}&txt=${txt_value}"
    
    local response
    if ! response=$(curl -s -f -m 30 --retry 2 "$url" 2>/dev/null); then
        bashio::log.error "Failed to connect to DuckDNS API for ${domain}"
        return 1
    fi

    if [ "$response" != "OK" ]; then
        bashio::log.error "Failed to add TXT record for ${domain}. DuckDNS response: ${response}"
        return 1
    fi

    bashio::log.info "TXT record added successfully for ${domain}"
    return 0
}

dns_duckdns_rm_txt_record() {
    local domain="${1}"
    local txt_value="${2}"
    local duckdns_token="$DNS_API_TOKEN"
    local duckdns_domain

    # Extract the subdomain from the full domain
    duckdns_domain=$(echo "$domain" | sed -E 's/(.*)\.duckdns\.org/\1/')

    bashio::log.trace "${FUNCNAME[0]}" "${domain}" "${txt_value}"
    bashio::log.info "Removing TXT record for ${domain}"

    # DuckDNS doesn't have a specific API call to remove TXT records
    # We'll clear the TXT record by setting it to an empty string
    local url="https://www.duckdns.org/update?domains=${duckdns_domain}&token=${duckdns_token}&txt="
    
    local response
    if ! response=$(curl -s -f -m 30 --retry 2 "$url" 2>/dev/null); then
        bashio::log.error "Failed to connect to DuckDNS API for ${domain} (remove TXT)"
        return 1
    fi

    if [ "$response" != "OK" ]; then
        bashio::log.error "Failed to remove TXT record for ${domain}. DuckDNS response: ${response}"
        return 1
    fi

    bashio::log.info "TXT record removed successfully for ${domain}"
    return 0
}

dns_duckdns_update() {
    local domain="${1}"
    local ipv4="${2}"
    local ipv6="${3}"
    local duckdns_token="$DNS_API_TOKEN"
    local duckdns_domain

    # Extract the subdomain from the full domain
    duckdns_domain=$(echo "$domain" | sed -E 's/(.*)\.duckdns\.org/\1/')

    bashio::log.trace "${FUNCNAME[0]}" "${domain}" "${ipv4}" "${ipv6}"
    bashio::log.info "Updating DNS for ${domain}"

    local url="https://www.duckdns.org/update?domains=${duckdns_domain}&token=${duckdns_token}&ip=${ipv4}&ipv6=${ipv6}"
    
    local response
    if ! response=$(curl -s -f -m 30 --retry 2 "$url" 2>/dev/null); then
        bashio::log.error "Failed to connect to DuckDNS API for ${domain} (update DNS)"
        return 1
    fi

    if [ "$response" != "OK" ]; then
        bashio::log.error "Failed to update DNS for ${domain}. DuckDNS response: ${response}"
        return 1
    fi

    bashio::log.info "DNS updated successfully for ${domain}"
    return 0
}

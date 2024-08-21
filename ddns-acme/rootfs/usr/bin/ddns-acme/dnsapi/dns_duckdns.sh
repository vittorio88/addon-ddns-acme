#!/usr/bin/with-contenv bashio
# shellcheck disable=SC2034

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
    response=$(curl -s "$url")

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
    response=$(curl -s "$url")

    if [ "$response" != "OK" ]; then
        bashio::log.error "Failed to remove TXT record for ${domain}. DuckDNS response: ${response}"
        return 1
    fi

    bashio::log.info "TXT record removed successfully for ${domain}"
    return 0
}

# Helper function to validate the DuckDNS token
dns_duckdns_validate_token() {
    local duckdns_token="$DNS_API_TOKEN"
    
    if [ -z "$duckdns_token" ]; then
        bashio::log.error "DuckDNS token is not set. Please set the DNS_API_TOKEN environment variable."
        return 1
    fi

    # DuckDNS doesn't provide a specific API endpoint for token validation
    # We'll attempt a no-op update to check if the token is valid
    local url="https://www.duckdns.org/update?domains=test&token=${duckdns_token}"
    local response
    response=$(curl -s "$url")

    if [ "$response" != "OK" ]; then
        bashio::log.error "Invalid DuckDNS token. Please check your DNS_API_TOKEN."
        return 1
    fi

    bashio::log.info "DuckDNS token validated successfully."
    return 0
}

# Run token validation when the script is sourced
dns_duckdns_validate_token

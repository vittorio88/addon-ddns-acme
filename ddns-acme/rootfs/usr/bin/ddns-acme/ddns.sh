#!/usr/bin/with-contenv bashio

# CONSTANTS
QUERY_URL_IPV4="https://ipv4.text.wtfismyip.com"
QUERY_URL_IPV6="https://ipv6.text.wtfismyip.com"
LAST_IP_UPDATE_FILE="/data/last_ip_update"

function is_valid_ipv4() {
    local ip="$1"
    local ipv4_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    
    if [[ ! $ip =~ $ipv4_regex ]]; then
        return 1
    fi
    
    # Check each octet is between 0-255
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [[ $octet -gt 255 ]] || [[ $octet -lt 0 ]] || [[ ${#octet} -gt 1 && ${octet:0:1} == "0" ]]; then
            return 1
        fi
    done
    return 0
}

function is_valid_ipv6() {
    local ip="$1"
    # Simplified IPv6 validation - checks for hex chars and colons
    local ipv6_regex="^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$|^::1$|^::$"
    
    if [[ $ip =~ $ipv6_regex ]]; then
        return 0
    fi
    return 1
}

function validate_ip_address() {
    local ip="$1"
    local ip_type="$2"  # "ipv4" or "ipv6"
    
    case "$ip_type" in
        "ipv4")
            if is_valid_ipv4 "$ip"; then
                bashio::log.debug "[${FUNCNAME[0]}]" "$ip is a valid IPv4 address"
                return 0
            else
                bashio::log.warning "[${FUNCNAME[0]}]" "$ip is not a valid IPv4 address"
                return 1
            fi
            ;;
        "ipv6")
            if is_valid_ipv6 "$ip"; then
                bashio::log.debug "[${FUNCNAME[0]}]" "$ip is a valid IPv6 address"
                return 0
            else
                bashio::log.warning "[${FUNCNAME[0]}]" "$ip is not a valid IPv6 address"
                return 1
            fi
            ;;
        *)
            bashio::log.error "[${FUNCNAME[0]}]" "Unknown IP type: $ip_type"
            return 1
            ;;
    esac
}

function is_domain() {
    local domain="$1"
    
    # Input sanitization
    if [[ -z "$domain" ]]; then
        bashio::log.warning "[${FUNCNAME[0]}]" "Empty domain name provided"
        return 1
    fi
    
    # Check length limits
    if [[ ${#domain} -gt 255 ]]; then
        bashio::log.warning "[${FUNCNAME[0]}]" "Domain name too long: $domain (max 255 chars)"
        return 1
    fi

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
            if ! ipv4_queried=$(curl -s -f -m 10 --retry 3 "${QUERY_URL_IPV4}" 2>/dev/null); then
                bashio::log.error "[${FUNCNAME[0]}]" "Failed to query IPv4 address from ${QUERY_URL_IPV4}"
                return 2
            fi
            if validate_ip_address "${ipv4_queried}" "ipv4"; then
                bashio::log.info "[${FUNCNAME[0]}]" "According to: ${QUERY_URL_IPV4} , IPv4 address is ${ipv4_queried}"
                current_ipv4_address=${ipv4_queried}
                return 0
            else
                bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Invalid IPv4 address received: ${ipv4_queried} from ${QUERY_URL_IPV4}"
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
            if [[ -n "$IPV4_FIXED" ]] && validate_ip_address "$IPV4_FIXED" "ipv4"; then
                bashio::log.info "Using fixed IPv4 address: ${IPV4_FIXED}"
                current_ipv4_address=${IPV4_FIXED}
                return 0
            else
                bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Invalid or missing fixed IPv4 address: ${IPV4_FIXED}"
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
            if ! ipv6_queried=$(curl -s -f -m 10 --retry 3 "${QUERY_URL_IPV6}" 2>/dev/null); then
                bashio::log.error "[${FUNCNAME[0]}]" "Failed to query IPv6 address from ${QUERY_URL_IPV6}"
                return 2
            fi
            if validate_ip_address "${ipv6_queried}" "ipv6"; then
                bashio::log.info "[${FUNCNAME[0]}]" "According to: ${QUERY_URL_IPV6} , IPv6 address is ${ipv6_queried}"
                current_ipv6_address=${ipv6_queried}
                return 0
            else
                bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Invalid IPv6 address received: ${ipv6_queried} from ${QUERY_URL_IPV6}"
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
            if [[ -n "$IPV6_FIXED" ]] && validate_ip_address "$IPV6_FIXED" "ipv6"; then
                bashio::log.info "Using fixed IPv6 address: ${IPV6_FIXED}"
                current_ipv6_address=${IPV6_FIXED}
                return 0
            else
                bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Invalid or missing fixed IPv6 address: ${IPV6_FIXED}"
                return 1
            fi
            ;;
        *)
            bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Invalid IPv6 update method: ${IPV6_UPDATE_METHOD}"
            return 1
            ;;
    esac
}

function detect_legacy_dns_config() {
    local legacy_fields
    legacy_fields=$(jq -r '
        [
            (if ((.dns_provider_name // "") | tostring | length) > 0 then "dns_provider_name" else empty end),
            (if ((.dns_api_token // "") | tostring | length) > 0 then "dns_api_token" else empty end),
            (if ((.domains // []) | length) > 0 then "domains" else empty end)
        ] | join(", ")
    ' "$CONFIG_PATH")

    if [ -n "$legacy_fields" ]; then
        bashio::log.error "🚫 Old-style DNS configuration detected: ${legacy_fields}"
        bashio::log.error "💥 Breaking change in DDNS-ACME 3.0.0: replace legacy dns_provider_name/dns_api_token/domains with dns_accounts[]."
        bashio::log.error "Example: dns_accounts: [{provider: dynu, token: <token>, domains: [example.com]}]"
        return 1
    fi

    return 0
}

function build_dns_accounts_json() {
    if ! detect_legacy_dns_config; then
        return 1
    fi

    if ! jq -e '(.dns_accounts // []) | length > 0' "$CONFIG_PATH" >/dev/null; then
        bashio::log.error "dns_accounts is required; DDNS-ACME 3.0.0 no longer supports legacy DNS configuration"
        return 1
    fi

    DNS_ACCOUNTS_JSON=$(jq -c '[.dns_accounts[] | {provider: .provider, token: .token, domains: (.domains // [])}]' "$CONFIG_PATH")
    export DNS_ACCOUNTS_JSON
}

function configured_domains() {
    jq -r '.[].domains[]' <<< "$DNS_ACCOUNTS_JSON"
}

function validate_dns_accounts() {
    local account provider token domains

    while IFS= read -r account; do
        provider=$(jq -r '.provider // empty' <<< "$account")
        token=$(jq -r '.token // empty' <<< "$account")
        domains=$(jq -r '.domains[]? // empty' <<< "$account")

        case "$provider" in
            dynu|duckdns|cloudflare) ;;
            *)
                bashio::log.warning "Unsupported DNS account provider: $provider"
                return 1
                ;;
        esac

        if [ -z "$token" ]; then
            bashio::log.warning "Missing DNS API token for provider: $provider"
            return 1
        fi

        if [ -z "$domains" ]; then
            bashio::log.warning "DNS account for provider $provider has no domains"
            return 1
        fi

        while IFS= read -r domain; do
            [ -z "$domain" ] && continue
            if is_domain "$domain"; then
                bashio::log.debug "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "domain $domain is a valid domain."
            else
                bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "domain $domain is not a valid domain... "
                return 1
            fi
        done <<< "$domains"
    done < <(jq -c '.[]' <<< "$DNS_ACCOUNTS_JSON")
}

function hassio_get_config_variables(){

    if bashio::config.has_value "ipv4_fixed"; then IPV4_FIXED=$(bashio::config 'ipv4_fixed'); else IPV4_FIXED=""; fi
    IPV4_UPDATE_METHOD=$(bashio::config 'ipv4_update_method');
    if bashio::config.has_value "ipv6_fixed"; then IPV6_FIXED=$(bashio::config 'ipv6_fixed'); else IPV6_FIXED=""; fi
    IPV6_UPDATE_METHOD=$(bashio::config 'ipv6_update_method');
    
    # Validate that fixed IP addresses are provided when required
    if [ "$IPV4_UPDATE_METHOD" = "use fixed address" ] && [ -z "$IPV4_FIXED" ]; then
        bashio::log.error "IPv4 update method is set to 'use fixed address' but no fixed IPv4 address is configured."
        bashio::log.error "Please set the 'ipv4_fixed' configuration option or change the IPv4 update method."
        return 1
    fi
    
    if [ "$IPV6_UPDATE_METHOD" = "use fixed address" ] && [ -z "$IPV6_FIXED" ]; then
        bashio::log.error "IPv6 update method is set to 'use fixed address' but no fixed IPv6 address is configured."
        bashio::log.error "Please set the 'ipv6_fixed' configuration option or change the IPv6 update method."
        return 1
    fi
    if bashio::config.has_value "aliases"; then ALIASES=$(bashio::config 'aliases'); else ALIASES=""; fi

    DNS_PROVIDER_NAME=""
    DNS_API_TOKEN=""
    IP_UPDATE_WAIT_SECONDS=$(bashio::config 'ip_update_wait_seconds')
    ACME_PROVIDER_NAME=$(bashio::config 'acme_provider_name')
    ACME_TERMS_ACCEPTED=$(bashio::config 'acme_accept_terms')
    
    # Set log level from configuration
    if bashio::config.has_value "log_level"; then 
        LOG_LEVEL=$(bashio::config 'log_level')
        bashio::log.level "${LOG_LEVEL}"
        bashio::log.info "Log level set to: ${LOG_LEVEL}"
    fi

    if ! build_dns_accounts_json; then
        return 1
    fi
    if ! validate_dns_accounts; then
        return 1
    fi

    # Check if ALIASES are valid domains.
    for domain in "$ALIASES"; do
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
    if jq -e '(.dns_accounts // []) | length > 0' "$CONFIG_PATH" >/dev/null; then
        bashio::log.debug "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "DNS account configuration is present"
    else
        bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "No dns_accounts configured"
        return 1
    fi

    return 0
}

function update_dns_ip_addresses(){
    local provided_ipv4="${1:-}"
    local provided_ipv6="${2:-}"
    
    # Use provided IP addresses if given, otherwise determine fresh ones
    if [ -n "$provided_ipv4" ] && [ "$IPV4_UPDATE_METHOD" != "skip update" ]; then
        current_ipv4_address="$provided_ipv4"
        bashio::log.debug "Using provided IPv4 address: $current_ipv4_address"
    elif [ "$IPV4_UPDATE_METHOD" != "skip update" ]; then
        declare current_ipv4_address
        if ! hassio_determine_ipv4_address; then
            bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Could not determine IPv4 address"
            return 1
        fi
    else
        # IPv4 update is skipped, set empty value
        current_ipv4_address=""
        bashio::log.debug "IPv4 update is skipped, using empty IPv4 address"
    fi

    if [ -n "$provided_ipv6" ] && [ "$IPV6_UPDATE_METHOD" != "skip update" ]; then
        current_ipv6_address="$provided_ipv6"
        bashio::log.debug "Using provided IPv6 address: $current_ipv6_address"
    elif [ "$IPV6_UPDATE_METHOD" != "skip update" ]; then
        declare current_ipv6_address
        if ! hassio_determine_ipv6_address; then
            bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Could not determine IPv6 address"
        fi
    else
        # IPv6 update is skipped, set empty value
        current_ipv6_address=""
        bashio::log.debug "IPv6 update is skipped, using empty IPv6 address"
    fi

    # Update each domain for each configured DNS account.
    local original_dns_api_token="$DNS_API_TOKEN"
    local original_dns_provider_name="$DNS_PROVIDER_NAME"
    local account account_provider account_token domain
    while IFS= read -r account; do
        account_provider=$(jq -r '.provider' <<< "$account")
        account_token=$(jq -r '.token' <<< "$account")
        DNS_PROVIDER_NAME="$account_provider"
        DNS_API_TOKEN="$account_token"
        export DNS_API_TOKEN

        while IFS= read -r domain; do
            [ -z "$domain" ] && continue
            if [ "$account_provider" = "dynu" ]; then
                if ! dns_dynu_update_ipv4_ipv6 "$domain" "$current_ipv4_address" "$current_ipv6_address"; then
                    bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Could not update Dynu DNS IP address records for domain: $domain"
                    DNS_API_TOKEN="$original_dns_api_token"
                    DNS_PROVIDER_NAME="$original_dns_provider_name"
                    export DNS_API_TOKEN
                    return 1
                fi
            elif [ "$account_provider" = "duckdns" ]; then
                if ! dns_duckdns_update "$domain" "$current_ipv4_address" "$current_ipv6_address"; then
                    bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Could not update DuckDNS IP address records for domain: $domain"
                    DNS_API_TOKEN="$original_dns_api_token"
                    DNS_PROVIDER_NAME="$original_dns_provider_name"
                    export DNS_API_TOKEN
                    return 1
                fi
            elif [ "$account_provider" = "cloudflare" ]; then
                if ! dns_cloudflare_update "$domain" "$current_ipv4_address" "$current_ipv6_address"; then
                    bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Could not update Cloudflare DNS IP address records for domain: $domain"
                    DNS_API_TOKEN="$original_dns_api_token"
                    DNS_PROVIDER_NAME="$original_dns_provider_name"
                    export DNS_API_TOKEN
                    return 1
                fi
            fi
        done < <(jq -r '.domains[]' <<< "$account")
    done < <(jq -c '.[]' <<< "$DNS_ACCOUNTS_JSON")

    DNS_API_TOKEN="$original_dns_api_token"
    DNS_PROVIDER_NAME="$original_dns_provider_name"
    export DNS_API_TOKEN

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

function get_dns_ip_address() {
    local domain="$1"
    local record_type="$2"  # A or AAAA
    
    # Query DNS for current IP address
    local dns_ip
    dns_ip=$(dig +short "$domain" "$record_type" 2>/dev/null | tail -1)
    
    if [ -z "$dns_ip" ]; then
        bashio::log.debug "No $record_type record found for $domain"
        return 1
    fi
    
    echo "$dns_ip"
    return 0
}

function check_ip_differences_and_get_addresses() {
    local differences_found=false
    local local_ipv4=""
    local local_ipv6=""
    local check_failed=false
    
    # Determine current local IP addresses
    if [ "$IPV4_UPDATE_METHOD" != "skip update" ]; then
        declare current_ipv4_address
        if hassio_determine_ipv4_address && [ -n "$current_ipv4_address" ]; then
            local_ipv4="$current_ipv4_address"
            bashio::log.debug "Current local IPv4: $local_ipv4"
            
            # Check each domain's IPv4 record.
            while IFS= read -r domain; do
                [ -z "$domain" ] && continue
                local dns_ipv4
                if dns_ipv4=$(get_dns_ip_address "$domain" "A" 2>/dev/null); then
                    if [ "$local_ipv4" != "$dns_ipv4" ]; then
                        bashio::log.info "IPv4 difference detected for $domain: local=$local_ipv4, DNS=$dns_ipv4"
                        differences_found=true
                    fi
                else
                    bashio::log.info "No IPv4 record found in DNS for $domain, local IPv4 is $local_ipv4"
                    differences_found=true
                fi
            done < <(configured_domains)
        else
            bashio::log.warning "Could not determine IPv4 address for startup check"
            check_failed=true
        fi
    fi
    
    if [ "$IPV6_UPDATE_METHOD" != "skip update" ]; then
        declare current_ipv6_address
        if hassio_determine_ipv6_address && [ -n "$current_ipv6_address" ]; then
            local_ipv6="$current_ipv6_address"
            bashio::log.debug "Current local IPv6: $local_ipv6"
            
            # Check each domain's IPv6 record.
            while IFS= read -r domain; do
                [ -z "$domain" ] && continue
                local dns_ipv6
                if dns_ipv6=$(get_dns_ip_address "$domain" "AAAA" 2>/dev/null); then
                    if [ "$local_ipv6" != "$dns_ipv6" ]; then
                        bashio::log.info "IPv6 difference detected for $domain: local=$local_ipv6, DNS=$dns_ipv6"
                        differences_found=true
                    fi
                else
                    bashio::log.info "No IPv6 record found in DNS for $domain, local IPv6 is $local_ipv6"
                    differences_found=true
                fi
            done < <(configured_domains)
        else
            bashio::log.warning "Could not determine IPv6 address for startup check"
        fi
    fi
    
    # Output the IP addresses for the caller to use
    echo "$local_ipv4|$local_ipv6"
    
    # If there was a critical failure in determining IPs, we should still continue
    # but not attempt an update
    if [ "$check_failed" = true ]; then
        bashio::log.warning "IP address check failed, skipping startup update"
        return 2  # check failed, but not fatal
    elif [ "$differences_found" = true ]; then
        return 0  # differences found
    else
        bashio::log.info "No IP address differences detected between local and DNS records"
        return 1  # no differences found (normal case)
    fi
}

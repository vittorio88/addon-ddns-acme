#!/usr/bin/with-contenv bashio

# CONSTANTS
# Set default log level initially, will be updated from config later
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

# Function to convert seconds to human-readable format
seconds_to_human_readable() {
    local seconds=$1
    local days=$((seconds / 86400))
    local hours=$(( (seconds % 86400) / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    local remaining_seconds=$((seconds % 60))
    
    local result=""
    if [ $days -gt 0 ]; then
        result="${days} days, "
    fi
    if [ $hours -gt 0 ]; then
        result="${result}${hours} hours, "
    fi
    if [ $minutes -gt 0 ]; then
        result="${result}${minutes} minutes, "
    fi
    result="${result}${remaining_seconds} seconds"
    
    echo "$result"
}

# Function to convert seconds to hours and minutes
seconds_to_hours_minutes() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(( (seconds % 3600) / 60 ))
    echo "${hours}h ${minutes}m"
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

# Global variables to track startup results
startup_check_result=2
startup_ipv4=""
startup_ipv6=""
startup_update_performed=false

# Function to perform startup initialization and IP check
perform_startup_initialization() {
    bashio::log.info "[DDNS-ACME - Add-On]" "Checking for IP address differences on startup..."
    
    # Perform IP check and capture results
    local startup_ip_result
    startup_ip_result=$(check_ip_differences_and_get_addresses)
    startup_check_result=$?
    startup_ipv4=$(echo "$startup_ip_result" | cut -d'|' -f1)
    startup_ipv6=$(echo "$startup_ip_result" | cut -d'|' -f2)
    
    bashio::log.debug "[DDNS-ACME - Add-On]" "IP check function returned code: $startup_check_result"
    bashio::log.debug "[DDNS-ACME - Add-On]" "Parsed IPs: IPv4='$startup_ipv4' IPv6='$startup_ipv6'"

    # Handle different return codes from the IP check
    case $startup_check_result in
        0)
            # Differences found - perform immediate update
            bashio::log.info "[DDNS-ACME - Add-On]" "IP address differences detected on startup, performing immediate DDNS update"
            if update_dns_ip_addresses "$startup_ipv4" "$startup_ipv6"; then
                bashio::log.info "[DDNS-ACME - Add-On]" "Startup DDNS update succeeded."
                startup_update_performed=true
            else
                bashio::log.warning "[DDNS-ACME - Add-On ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Startup DDNS update failed."
                startup_update_performed=false
            fi
            ;;
        1)
            # No differences found - this is normal, continue
            bashio::log.info "[DDNS-ACME - Add-On]" "No IP address differences detected on startup, skipping immediate update"
            startup_update_performed=false
            ;;
        2)
            # Check failed but not fatal - log warning and continue
            bashio::log.warning "[DDNS-ACME - Add-On]" "IP address check failed on startup, skipping immediate update"
            startup_update_performed=false
            ;;
        *)
            # Unexpected return code - log warning and continue
            bashio::log.warning "[DDNS-ACME - Add-On]" "Unexpected result from IP check (code: $startup_check_result), skipping immediate update"
            startup_update_performed=false
            ;;
    esac
    
    bashio::log.info "[DDNS-ACME - Add-On]" "Startup IP check completed successfully, continuing to main loop"
    return 0
}

# Perform startup initialization with error handling
if ! perform_startup_initialization; then
    bashio::log.warning "[DDNS-ACME - Add-On]" "Startup IP check encountered an error, but continuing with normal operation"
fi
# Function to run the main DDNS-ACME renewal loop
run_main_loop() {
    local first_iteration=true
    
    bashio::log.info "[DDNS-ACME - Add-On]" "Entering main DDNS-ACME Renew loop"
    
    while true; do
        local now="$(date +%s)"
        local last_ip_update=$(get_last_ip_update_time)
        local last_acme_op=$(get_last_acme_op_time)
        local ip_update_interval=$((now - last_ip_update))
        local acme_op_interval=$((now - last_acme_op))

        # Perform DDNS update if necessary
        if [ $ip_update_interval -ge $IP_UPDATE_WAIT_SECONDS ]; then
            # On the first iteration, if startup already performed an update, skip it to avoid duplicate checking
            if [ "$first_iteration" = true ] && [ "$startup_update_performed" = true ]; then
                bashio::log.info "[DDNS-ACME - Add-On]" "Skipping first iteration DDNS update - already performed at startup"
            else
                # For first iteration without startup update, or subsequent iterations, check normally
                if update_dns_ip_addresses; then
                    bashio::log.info "[DDNS-ACME - Add-On]" "DDNS update succeeded."
                else
                    bashio::log.warning "[DDNS-ACME - Add-On ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "DDNS update failed."
                fi
            fi
        else
            bashio::log.info "[DDNS-ACME - Add-On]" "Skipping DDNS update. Time since last update: $(seconds_to_human_readable $ip_update_interval)"
        fi

        # Perform ACME renewal if necessary
        if [ $acme_op_interval -ge $ACME_RENEW_WAIT_SECONDS ]; then
            if acme_renew "$ACME_PROVIDER_NAME" "$ACME_TERMS_ACCEPTED" "$DNS_PROVIDER_NAME" "$DOMAINS" "$ALIASES"; then
                bashio::log.info "[DDNS-ACME - Add-On]" "ACME renew succeeded."
            else
                bashio::log.warning "[DDNS-ACME - Add-On ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "ACME renew failed."
            fi
        else
            bashio::log.info "[DDNS-ACME - Add-On]" "Skipping ACME renewal. Time since last renewal: $(seconds_to_human_readable $acme_op_interval)"
        fi

        # Calculate next update times
        local next_ip_update=$((last_ip_update + IP_UPDATE_WAIT_SECONDS))
        local next_acme_op=$((last_acme_op + ACME_RENEW_WAIT_SECONDS))

        # Calculate sleep duration
        local sleep_duration=$((IP_UPDATE_WAIT_SECONDS < ACME_RENEW_WAIT_SECONDS ? IP_UPDATE_WAIT_SECONDS : ACME_RENEW_WAIT_SECONDS))

        # Print information about updates and next scheduled operations
        bashio::log.info "Last IP update: $(seconds_to_hours_minutes $((now - last_ip_update))) ago | Next IP update: in $(seconds_to_hours_minutes $((next_ip_update - now)))"
        bashio::log.info "Last ACME operation: $(seconds_to_human_readable $((now - last_acme_op))) ago | Next ACME operation: in $(seconds_to_human_readable $((next_acme_op - now)))"
        bashio::log.info "Sleep duration: $(seconds_to_human_readable $sleep_duration)"

        # Reset first iteration flag after the first loop
        if [ "$first_iteration" = true ]; then
            first_iteration=false
        fi

        # Sleep until the next operation
        sleep $sleep_duration
    done
}

# Start the main loop
run_main_loop

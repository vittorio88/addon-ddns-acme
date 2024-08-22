#!/usr/bin/with-contenv bashio

CERT_DIR=/etc/dehydrated/certs
WORK_DIR=/etc/dehydrated/
LAST_ACME_OP_FILE="${WORK_DIR}/last_acme_op"

function acme_init(){
    local ACME_TERMS_ACCEPTED=$1
    local max_retries=5
    local retry_delay=5

    bashio::log.info "[${FUNCNAME[0]}]" "Initializing ACME using CERT_DIR=$CERT_DIR and WORK_DIR=$WORK_DIR"

    # Register/generate certificate if terms accepted
    if $ACME_TERMS_ACCEPTED; then
        # Init folder structs
        mkdir -p "${CERT_DIR}"
        mkdir -p "${WORK_DIR}"

        # Clean up possible stale lock file
        if [ -e "${WORK_DIR}/lock" ]; then
            rm -f "${WORK_DIR}/lock"
            bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "Reset dehydrated lock file"
        fi

        # Generate new certs
        if [ ! -d "${CERT_DIR}/live" ]; then
            # Create empty dehydrated config file so that this dir will be used for storage
            touch "${WORK_DIR}/config"

            # Determine the ACME server based on ACME_PROVIDER_NAME
            local acme_server
            case "$ACME_PROVIDER_NAME" in
                "lets_encrypt")
                    acme_server="https://acme-v02.api.letsencrypt.org/directory"
                    ;;
                "lets_encrypt_test")
                    acme_server="https://acme-staging-v02.api.letsencrypt.org/directory"
                    ;;
                *)
                    bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "Unsupported ACME provider: $ACME_PROVIDER_NAME"
                    return 1
                    ;;
            esac

            # Debug: Print ACME server
            bashio::log.debug "ACME server: ${acme_server}"

            # Set the CA in the dehydrated config file
            echo "CA=$acme_server" >> "${WORK_DIR}/config"

            for ((i=1; i<=max_retries; i++)); do
                if dehydrated --register --accept-terms --config "${WORK_DIR}/config"; then
                    bashio::log.debug "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "Init Success dehydrated returned 0"
                    return 0
                else
                    bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "Init Fail, dehydrated returned non-zero. Retry $i of $max_retries"
                    sleep $((retry_delay * 2**((i-1))))
                fi
            done

            bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "Failed to initialize ACME after $max_retries attempts"
            return 1
        fi
    else
        bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "Terms must be accepted in add-on config"
        exit 1
    fi

    return 0
}

# Function that performs a renew
function acme_renew() {
    local ACME_PROVIDER_NAME=$1
    local ACME_TERMS_ACCEPTED=$2
    local DNS_PROVIDER_NAME=$3
    local DOMAINS=$4
    local ALIASES=$5

    if $ACME_TERMS_ACCEPTED; then

        local domain_args=()
        local aliases=''

        bashio::log.info "Renewing ACME for: $ACME_PROVIDER_NAME"
        # Prepare domain for ACME processing
        for domain in ${DOMAINS}; do
            for alias in $(jq --raw-output --exit-status "[.aliases[]|{(.alias):.domain}]|add.\"$domain\" | select(. != null)" "$CONFIG_PATH") ; do
                aliases="$aliases $alias"
                bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "alias $alias is not a valid domain."
                return 1
            done
        done

        aliases="$(echo "${aliases}" | tr ' ' '\n' | sort | uniq)"

        bashio::log.debug "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Combining DOMAINS and ALIASES into domain_args: ${DOMAINS} ${aliases}"

        for domain in $(echo "${DOMAINS}" "${aliases}" | tr ' ' '\n' | sort | uniq); do
            bashio::log.debug "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "domain is: ${domain}"
            domain_args+=("--domain" "${domain}")
        done

        # Determine the hook path based on DNS_PROVIDER_NAME
        local hook_path
        case "$DNS_PROVIDER_NAME" in
            "dynu")
                hook_path="$DIR/hooks/hooks_dynu.sh"
                ;;
            "duckdns")
                hook_path="$DIR/hooks/hooks_duckdns.sh"
                ;;
            *)
                bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "Unsupported DNS provider: $DNS_PROVIDER_NAME"
                return 1
                ;;
        esac

        # Determine the ACME server based on ACME_PROVIDER_NAME
        local acme_server
        case "$ACME_PROVIDER_NAME" in
            "lets_encrypt")
                acme_server="https://acme-v02.api.letsencrypt.org/directory"
                ;;
            "lets_encrypt_test")
                acme_server="https://acme-staging-v02.api.letsencrypt.org/directory"
                ;;
            *)
                bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "Unsupported ACME provider: $ACME_PROVIDER_NAME"
                return 1
                ;;
        esac

        # Debug: Print ACME server
        bashio::log.debug "ACME server: ${acme_server}"

        DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ) # find path to this file.
        bashio::log.info "[${FUNCNAME[0]}]" "Running Dehydrated with domain_args: ${domain_args[@]}"
        if dehydrated --cron --hook "$hook_path" --challenge dns-01 "${domain_args[@]}" --out "${CERT_DIR}" --config "${WORK_DIR}/config" --ca "$acme_server"; then
            bashio::log.info "[${FUNCNAME[0]}" "dehydrated completed successfully."
            echo "$(date +%s)" > "${LAST_ACME_OP_FILE}"
            return 0
        else
            bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "dehydrated did not complete successfully."
            return 1
        fi

    else
        bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "Terms must be accepted in add-on config"
        exit 1
    fi
    return 0
}

function get_last_acme_op_time() {
    if [ -f "${LAST_ACME_OP_FILE}" ]; then
        cat "${LAST_ACME_OP_FILE}"
    else
        echo "0"
    fi
}

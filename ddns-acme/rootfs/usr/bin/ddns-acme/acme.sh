#!/usr/bin/with-contenv bashio

CERT_DIR=/etc/dehydrated/certs
WORK_DIR=/etc/dehydrated/

# CONSTANTS
ACME_RENEW_WAIT_SECONDS=43200

# VARIABLES
acme_last_renewed_time=0

function acme_init(){
    local ACME_TERMS_ACCEPTED=$1

    bashio::log.info "Initializing ACME using CERT_DIR=$CERT_DIR and WORK_DIR=$WORK_DIR"

    # Register/generate certificate if terms accepted
    if $ACME_TERMS_ACCEPTED; then
        # Init folder structs
        mkdir -p "${CERT_DIR}"
        mkdir -p "${WORK_DIR}"

        # Clean up possible stale lock file
        if [ -e "${WORK_DIR}/lock" ]; then
            rm -f "${WORK_DIR}/lock"
            bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Reset dehydrated lock file"
        fi

        # Generate new certs
        if [ ! -d "${CERT_DIR}/live" ]; then
            # Create empty dehydrated config file so that this dir will be used for storage
            touch "${WORK_DIR}/config"

            if dehydrated --register --accept-terms --config "${WORK_DIR}/config"; then
                bashio::log.debug "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Init Success dehydrated returned 0"
                return 0
            else
                bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Init Fail, dehydrated returned not 0"
                return 1
            fi
        fi
    else
        bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Terms must be accepted in add-on config"
        exit 1
    fi

    return 0
}

# Function that performe a renew
function acme_renew() {
    local PROVIDER_NAME=$1
    local ACME_TERMS_ACCEPTED=$2
    local DOMAINS=$3
    local ALIASES=$4

    if $ACME_TERMS_ACCEPTED; then
        now="$(date +%s)"
        acme_time_since_last_renew=$((now - acme_last_renewed_time))
        if [ $acme_time_since_last_renew -ge $ACME_RENEW_WAIT_SECONDS ]; then

            local domain_args=()
            local aliases=''

            bashio::log.info "Renewing ACME for: $PROVIDER_NAME"
            # Prepare domain for ACME processing
            for domain in ${DOMAINS}; do
                for alias in $(jq --raw-output --exit-status "[.aliases[]|{(.alias):.domain}]|add.\"$domain\" | select(. != null)" "$CONFIG_PATH") ; do
                    aliases="$aliases $alias"
                    bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "alias $alias is not a valid domain."
                    return 1
                done
            done

            aliases="$(echo "${aliases}" | tr ' ' '\n' | sort | uniq)"

            bashio::log.debug "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Combining DOMAINS and ALIASES into domain_args: ${DOMAINS} ${aliases}"

            for domain in $(echo "${DOMAINS}" "${aliases}" | tr ' ' '\n' | sort | uniq); do
                bashio::log.debug "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "domain is: ${domain}"
                domain_args+=("--domain" "${domain}")
            done

            # WIP: Modify the following block to check $ACME_PROVIDER_NAME and $DNS_PROVIDER_NAME.
            #       - Based on $DNS_PROVIDER_NAME, change hook path.
            #       - Based on $ACME_PROVIDER_NAME, change dehydrated arguments to use Let's encrypt or Other ACME provider.
            bashio::log.info "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}]" "Running Dehydrated with domain_args: ${domain_args[@]}"
            DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ) # find path to this file.
            if dehydrated --cron --hook "$DIR/hooks/hooks_dynu.sh" --challenge dns-01 "${domain_args[@]}" --out "${CERT_DIR}" --config "${WORK_DIR}/config"; then
                acme_last_renewed_time="$(date +%s)"
                bashio::log.info "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}]" "dehydrated completed successfully."
                return 0
            else
                bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "dehydrated did not complete successfully."
                return 1
            fi
        else 
            bashio::log.trace "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@"
            bashio::log.debug "acme_time_since_last_renew=$acme_time_since_last_renew is not yet greater than $ACME_RENEW_WAIT_SECONDS. Skipping LE renew for now..."

            return 0
        fi
    else
        bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "Terms must be accepted in add-on config"
        exit 1
    fi
    return 0

}
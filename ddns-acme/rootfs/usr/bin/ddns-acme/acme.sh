#!/usr/bin/with-contenv bashio

CERT_DIR=/etc/dehydrated/certs
WORK_DIR=/etc/dehydrated/
LAST_ACME_OP_FILE="${WORK_DIR}/last_acme_op"
ACME_RENEW_MIN_VALID_SECONDS=${ACME_RENEW_MIN_VALID_SECONDS:-2592000} # 30 days

function acme_server_for_provider() {
    local provider="$1"
    case "$provider" in
        "lets_encrypt")
            echo "https://acme-v02.api.letsencrypt.org/directory"
            ;;
        "lets_encrypt_test")
            echo "https://acme-staging-v02.api.letsencrypt.org/directory"
            ;;
        *)
            bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "Unsupported ACME provider: $provider"
            return 1
            ;;
    esac
}

function acme_init(){
    local ACME_TERMS_ACCEPTED=$1

    bashio::log.info "[${FUNCNAME[0]}]" "Initializing ACME using CERT_DIR=$CERT_DIR and WORK_DIR=$WORK_DIR"

    if $ACME_TERMS_ACCEPTED; then
        mkdir -p "${CERT_DIR}"
        mkdir -p "${WORK_DIR}"

        if [ -e "${WORK_DIR}/lock" ]; then
            rm -f "${WORK_DIR}/lock"
            bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "Reset dehydrated lock file"
        fi

        touch "${WORK_DIR}/config"

        local acme_server
        if ! acme_server=$(acme_server_for_provider "$ACME_PROVIDER_NAME"); then
            return 1
        fi

        bashio::log.debug "ACME server: ${acme_server}"
        if ! grep -q '^CA=' "${WORK_DIR}/config" 2>/dev/null; then
            echo "CA=$acme_server" >> "${WORK_DIR}/config"
        fi
    else
        bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "Terms must be accepted in add-on config"
        exit 1
    fi

    return 0
}

function acme_register_if_needed() {
    local max_retries=5
    local retry_delay=5

    # Avoid creating/registering a new ACME account on every add-on restart when
    # the configured certificate is already valid and no ACME order is needed.
    # This function is called only immediately before an order is attempted.
    if [ -e "${WORK_DIR}/accounts" ] || [ -e "${WORK_DIR}/account_key.pem" ]; then
        return 0
    fi

    for ((i=1; i<=max_retries; i++)); do
        if dehydrated --register --accept-terms --config "${WORK_DIR}/config"; then
            bashio::log.debug "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "ACME account registration succeeded"
            return 0
        else
            bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "ACME account registration failed. Retry $i of $max_retries"
            sleep $((retry_delay * 2**((i-1))))
        fi
    done

    bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "Failed to register ACME account after $max_retries attempts"
    return 1
}

function configured_acme_domains() {
    jq -r '.[].domains[]' <<< "$DNS_ACCOUNTS_JSON" | sort -u
}

function configured_alias_domains() {
    local acme_domains domain alias aliases=''
    acme_domains=$(configured_acme_domains)
    for domain in $(printf '%s\n' "$acme_domains"); do
        [ -z "$domain" ] && continue
        for alias in $(jq --raw-output --exit-status "[.aliases[]|{(.alias):.domain}]|add.\"$domain\" | select(. != null)" "$CONFIG_PATH") ; do
            aliases="$aliases $alias"
            bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "alias $alias is not a valid domain."
            return 1
        done
    done
    printf '%s\n' "$aliases" | tr ' ' '\n' | sort -u
}

function configured_certificate_domains() {
    local acme_domains aliases
    acme_domains=$(configured_acme_domains)
    if ! aliases=$(configured_alias_domains); then
        return 1
    fi
    printf '%s\n%s\n' "$acme_domains" "$aliases" | sed '/^$/d' | sort -u
}

function certificate_san_dns_names() {
    local cert_path="$1"
    openssl x509 -in "$cert_path" -noout -ext subjectAltName 2>/dev/null \
        | tr ',' '\n' \
        | sed -n 's/^ *DNS://p' \
        | sort -u
}

function certificate_domains_match_exact() {
    local cert_path="$1"
    shift
    local expected actual
    expected=$(printf '%s\n' "$@" | sort -u)
    actual=$(certificate_san_dns_names "$cert_path")
    [ "$expected" = "$actual" ]
}

function certificate_needs_renewal() {
    local certfile="$1"
    shift
    local cert_path="/ssl/${certfile}"

    if [ ! -s "$cert_path" ]; then
        bashio::log.info "Certificate /ssl/${certfile} is missing; ACME issue is needed."
        return 0
    fi

    if ! openssl x509 -in "$cert_path" -noout >/dev/null 2>&1; then
        bashio::log.warning "Certificate /ssl/${certfile} is not parseable; ACME issue is needed."
        return 0
    fi

    if ! openssl x509 -in "$cert_path" -checkend "$ACME_RENEW_MIN_VALID_SECONDS" -noout >/dev/null 2>&1; then
        bashio::log.info "Certificate /ssl/${certfile} expires within ${ACME_RENEW_MIN_VALID_SECONDS}s; ACME renewal is needed."
        return 0
    fi

    if ! certificate_domains_match_exact "$cert_path" "$@"; then
        bashio::log.info "Certificate /ssl/${certfile} SAN set does not exactly match configured domains; ACME issue is needed."
        return 0
    fi

    return 1
}

# Function that performs a renew. All configured domains are intentionally
# managed as one certificate because Home Assistant consumes one cert/key pair.
# Existing valid certs are skipped before any ACME order is created to avoid
# unnecessary Let's Encrypt rate-limit usage.
function acme_renew() {
    local ACME_PROVIDER_NAME=$1
    local ACME_TERMS_ACCEPTED=$2
    local ALIASES=${3:-}

    if ! $ACME_TERMS_ACCEPTED; then
        bashio::log.error "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "Terms must be accepted in add-on config"
        exit 1
    fi

    local acme_server
    if ! acme_server=$(acme_server_for_provider "$ACME_PROVIDER_NAME"); then
        return 1
    fi

    local hook_path
    DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
    hook_path="$DIR/hooks/hooks_multi.sh"

    local certfile domain domains domain_args=() domain_array=()
    certfile=$(jq -r '.certfile // "fullchain.pem"' "$CONFIG_PATH")

    if ! domains=$(configured_certificate_domains); then
        return 1
    fi

    bashio::log.info "Renewing ACME for: $ACME_PROVIDER_NAME"
    bashio::log.debug "ACME server: ${acme_server}"

    while IFS= read -r domain; do
        [ -z "$domain" ] && continue
        bashio::log.debug "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] Args: $@" "domain is: ${domain}"
        domain_args+=("--domain" "$domain")
        domain_array+=("$domain")
    done <<< "$domains"

    if [ ${#domain_array[@]} -eq 0 ]; then
        bashio::log.warning "No ACME domains configured."
        return 1
    fi

    if ! certificate_needs_renewal "$certfile" "${domain_array[@]}"; then
        bashio::log.info "Skipping ACME; /ssl/${certfile} is valid and covers: ${domain_array[*]}"
        echo "$(date +%s)" > "${LAST_ACME_OP_FILE}"
        return 0
    fi

    if ! acme_register_if_needed; then
        return 1
    fi

    bashio::log.info "[${FUNCNAME[0]}]" "Running Dehydrated with domain_args: ${domain_args[*]}"
    if dehydrated --cron --hook "$hook_path" --challenge dns-01 "${domain_args[@]}" --out "${CERT_DIR}" --config "${WORK_DIR}/config" --ca "$acme_server"; then
        bashio::log.info "[${FUNCNAME[0]}]" "dehydrated completed successfully."
        echo "$(date +%s)" > "${LAST_ACME_OP_FILE}"
        return 0
    else
        bashio::log.warning "[${FUNCNAME[0]} ${BASH_SOURCE[0]}:${LINENO}] [Args: $@]" "dehydrated did not complete successfully."
        return 1
    fi
}

function get_last_acme_op_time() {
    if [ -f "${LAST_ACME_OP_FILE}" ]; then
        cat "${LAST_ACME_OP_FILE}"
    else
        echo "0"
    fi
}

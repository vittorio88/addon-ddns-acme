#!/usr/bin/with-contenv bashio
# shellcheck disable=SC2034

# DNS_API_TOKEN is supplied per dns_accounts entry at dispatch time.
CLOUDFLARE_API_ENDPOINT="https://api.cloudflare.com/client/v4"

dns_cloudflare_update() {
    local domain="${1}"
    local ipv4="${2}"
    local ipv6="${3}"

    if [ -z "${DNS_API_TOKEN:-}" ]; then
        bashio::log.error "Missing Cloudflare DNS_API_TOKEN."
        return 1
    fi

    bashio::log.info "Updating Cloudflare DNS: ${domain} IP addresses"
    if [ -n "$ipv4" ]; then
        if ! _cloudflare_upsert_record "$domain" "A" "$ipv4"; then
            return 1
        fi
    fi
    if [ -n "$ipv6" ]; then
        if ! _cloudflare_upsert_record "$domain" "AAAA" "$ipv6"; then
            return 1
        fi
    fi
    return 0
}

dns_cloudflare_add_txt_record() {
    local fulldomain="${1}"
    local txtvalue="${2}"
    local record_name="_acme-challenge.${fulldomain}"

    if [ -z "${DNS_API_TOKEN:-}" ]; then
        bashio::log.error "Missing Cloudflare DNS_API_TOKEN."
        return 1
    fi

    if ! _cloudflare_get_zone_id "$fulldomain"; then
        return 1
    fi

    bashio::log.info "Removing stale Cloudflare TXT records for ${record_name} before deploying a new challenge."
    if ! _cloudflare_delete_txt_records_for_name "$record_name" ""; then
        return 1
    fi

    local payload
    payload=$(jq -nc --arg type "TXT" --arg name "$record_name" --arg content "$txtvalue" \
        '{type:$type,name:$name,content:$content,ttl:120}')
    if ! _cloudflare_rest POST "zones/${cloudflare_zone_id}/dns_records" "$payload"; then
        bashio::log.error "Could not add Cloudflare TXT record for ${record_name}."
        return 1
    fi
    if [ "$(printf '%s' "$response" | jq -r '.success // false')" != "true" ]; then
        bashio::log.error "Cloudflare TXT add failed for ${record_name}."
        return 1
    fi
    return 0
}

dns_cloudflare_rm_txt_record() {
    local fulldomain="${1}"
    local txtvalue="${2}"
    local record_name="_acme-challenge.${fulldomain}"

    if [ -z "${DNS_API_TOKEN:-}" ]; then
        bashio::log.error "Missing Cloudflare DNS_API_TOKEN."
        return 1
    fi

    if ! _cloudflare_get_zone_id "$fulldomain"; then
        return 1
    fi

    _cloudflare_delete_txt_records_for_name "$record_name" "$txtvalue"
}

_cloudflare_upsert_record() {
    local name="${1}"
    local type="${2}"
    local content="${3}"
    local record_id payload current_content

    if ! _cloudflare_get_zone_id "$name"; then
        return 1
    fi

    record_id=""
    current_content=""
    if ! _cloudflare_rest GET "zones/${cloudflare_zone_id}/dns_records?type=${type}&name=${name}" ""; then
        bashio::log.error "Could not query Cloudflare ${type} record for ${name}."
        return 1
    fi
    record_id=$(printf '%s' "$response" | jq -r '.result[0].id // empty')
    current_content=$(printf '%s' "$response" | jq -r '.result[0].content // empty')

    if [ -n "$record_id" ] && [ "$current_content" = "$content" ]; then
        bashio::log.debug "Cloudflare ${type} record for ${name} already matches ${content}."
        return 0
    fi

    payload=$(jq -nc --arg type "$type" --arg name "$name" --arg content "$content" \
        '{type:$type,name:$name,content:$content,ttl:1,proxied:false}')

    if [ -n "$record_id" ]; then
        if ! _cloudflare_rest PATCH "zones/${cloudflare_zone_id}/dns_records/${record_id}" "$payload"; then
            bashio::log.error "Could not update Cloudflare ${type} record for ${name}."
            return 1
        fi
    else
        if ! _cloudflare_rest POST "zones/${cloudflare_zone_id}/dns_records" "$payload"; then
            bashio::log.error "Could not create Cloudflare ${type} record for ${name}."
            return 1
        fi
    fi

    if [ "$(printf '%s' "$response" | jq -r '.success // false')" != "true" ]; then
        bashio::log.error "Cloudflare ${type} record upsert failed for ${name}."
        return 1
    fi
    return 0
}

_cloudflare_get_zone_id() {
    local domain="${1}"
    local zone_name labels label_count start

    IFS='.' read -r -a labels <<< "$domain"
    label_count=${#labels[@]}
    cloudflare_zone_id=""

    for (( start=0; start<label_count-1; start++ )); do
        zone_name=$(IFS=.; echo "${labels[*]:start}")
        if ! _cloudflare_rest GET "zones?name=${zone_name}&status=active" ""; then
            return 1
        fi
        cloudflare_zone_id=$(printf '%s' "$response" | jq -r '.result[0].id // empty')
        if [ -n "$cloudflare_zone_id" ]; then
            cloudflare_zone_name="$zone_name"
            export cloudflare_zone_id cloudflare_zone_name
            return 0
        fi
    done

    bashio::log.error "Could not find Cloudflare zone for ${domain}."
    return 1
}

_cloudflare_delete_txt_records_for_name() {
    local record_name="${1}"
    local txtvalue="${2:-}"
    local record_ids record_id

    if ! _cloudflare_rest GET "zones/${cloudflare_zone_id}/dns_records?type=TXT&name=${record_name}" ""; then
        return 1
    fi

    if [ -n "$txtvalue" ]; then
        record_ids=$(printf '%s' "$response" | jq -r --arg content "$txtvalue" '.result[]? | select(.content == $content) | .id')
    else
        record_ids=$(printf '%s' "$response" | jq -r '.result[]?.id')
    fi

    if [ -z "$record_ids" ]; then
        bashio::log.debug "No Cloudflare TXT records found for ${record_name}."
        return 0
    fi

    while IFS= read -r record_id; do
        [ -z "$record_id" ] && continue
        bashio::log.info "Removing Cloudflare TXT record ${record_id} for ${record_name}."
        if ! _cloudflare_rest DELETE "zones/${cloudflare_zone_id}/dns_records/${record_id}" ""; then
            return 1
        fi
        if [ "$(printf '%s' "$response" | jq -r '.success // false')" != "true" ]; then
            return 1
        fi
    done <<< "$record_ids"

    return 0
}

_cloudflare_rest() {
    local method="${1}"
    local endpoint="${2}"
    local data="${3:-}"
    local url="${CLOUDFLARE_API_ENDPOINT}/${endpoint}"

    bashio::log.debug "Performing Cloudflare REST API method: ${method} to endpoint: ${endpoint}"
    if [ -n "$data" ]; then
        response=$(curl -s -f -m 30 --retry 2 -X "$method" \
            -H "Authorization: Bearer ${DNS_API_TOKEN}" \
            -H "Content-Type: application/json" \
            "$url" -d "$data" 2>/dev/null) || return 1
    else
        response=$(curl -s -f -m 30 --retry 2 -X "$method" \
            -H "Authorization: Bearer ${DNS_API_TOKEN}" \
            -H "Content-Type: application/json" \
            "$url" 2>/dev/null) || return 1
    fi
    return 0
}

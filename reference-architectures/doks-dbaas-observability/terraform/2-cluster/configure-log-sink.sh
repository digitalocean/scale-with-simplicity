#!/bin/bash

# Script to configure DigitalOcean log sink for a database
# Usage: ./configure-log-sink.sh <database-name>

set -euo pipefail

# Check if database name argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <database-name>"
    echo "Example: $0 my-postgres-cluster"
    exit 1
fi

DATABASE_NAME="$1"

# Check required environment variables
if [ -z "${DIGITALOCEAN_ACCESS_TOKEN:-}" ]; then
    echo "Error: DIGITALOCEAN_ACCESS_TOKEN environment variable is required"
    exit 1
fi

# Function to get database UUID from DO API
get_database_uuid() {
    local db_name="$1"
    echo "Looking up database UUID for: $db_name" >&2

    local response
    response=$(curl -s -X GET \
        -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        "https://api.digitalocean.com/v2/databases")

    local uuid
    uuid=$(echo "$response" | jq -r --arg name "$db_name" '.databases[] | select(.name == $name) | .id')

    if [ -z "$uuid" ] || [ "$uuid" = "null" ]; then
        echo "Error: Database '$db_name' not found" >&2
        echo "Available databases:" >&2
        echo "$response" | jq -r '.databases[] | "  - \(.name) (id: \(.id))"' >&2
        exit 1
    fi

    echo "Found database UUID: $uuid" >&2
    echo "$uuid"
}

# Function to get NLB DNS name using kubectl
get_nlb_dns_name() {
    echo "Getting NLB DNS name..." >&2

    local external_ip
    external_ip=$(kubectl get service -n cluster-services alloy-syslog-nlb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

    if [ -z "$external_ip" ]; then
        echo "Error: Could not get external IP for alloy-syslog-nlb service" >&2
        echo "Service status:" >&2
        kubectl get service -n cluster-services alloy-syslog-nlb >&2
        exit 1
    fi

    # Get the FQDN from the service annotation
    local fqdn
    fqdn=$(kubectl get service -n cluster-services alloy-syslog-nlb -o jsonpath='{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}' 2>/dev/null)

    if [ -z "$fqdn" ]; then
        echo "Error: Could not get FQDN from service annotation" >&2
        exit 1
    fi

    echo "Found NLB DNS name: $fqdn (IP: $external_ip)" >&2
    echo "$fqdn"
}

# Function to get CA certificate using kubectl
get_ca_certificate() {
    echo "Getting CA certificate..." >&2

    local ca_cert
    ca_cert=$(kubectl get secret -n cluster-services syslog-ca-secret -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d)

    if [ -z "$ca_cert" ]; then
        echo "Error: Could not get CA certificate from syslog-ca-secret" >&2
        echo "Available secrets:" >&2
        kubectl get secrets -n cluster-services | grep syslog >&2
        exit 1
    fi

    echo "Successfully retrieved CA certificate" >&2
    echo "$ca_cert"
}

# Function to configure log sink via DO API
configure_log_sink() {
    local db_uuid="$1"
    local db_name="$2"
    local endpoint_url="$3"
    local ca_cert="$4"

    echo "Configuring log sink for database $db_uuid..." >&2

    # Create unique sink name based on database name (max 40 chars)
    local sink_name="loki-${db_name}"
    # Truncate if too long
    if [ ${#sink_name} -gt 40 ]; then
        sink_name="${sink_name:0:40}"
    fi

    # Create JSON payload for log sink configuration
    local payload
    payload=$(jq -n \
        --arg sink_name "$sink_name" \
        --arg endpoint "$endpoint_url" \
        --arg ca_cert "$ca_cert" \
        '{
            "sink_name": $sink_name,
            "sink_type": "rsyslog",
            "config": {
                "server": $endpoint,
                "port": 6514,
                "tls": true,
                "format": "rfc5424",
                "ca": $ca_cert
            }
        }')

    # Check if log sink already exists
    echo "Checking for existing log sink..." >&2
    local existing_response
    existing_response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET \
        -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
        "https://api.digitalocean.com/v2/databases/$db_uuid/logsinks")

    local existing_status
    existing_status=$(echo "$existing_response" | grep "HTTP_STATUS:" | cut -d: -f2)
    local existing_body
    existing_body=$(echo "$existing_response" | sed '$d')

    local sink_id=""
    local method="POST"
    local endpoint="https://api.digitalocean.com/v2/databases/$db_uuid/logsink"

    if [ "$existing_status" -eq 200 ]; then
        # Check if our sink already exists
        sink_id=$(echo "$existing_body" | jq -r --arg name "$sink_name" '.sinks[] | select(.sink_name == $name) | .sink_id')
        if [ -n "$sink_id" ] && [ "$sink_id" != "null" ]; then
            echo "Found existing log sink: $sink_id, updating..." >&2
            method="PUT"
            endpoint="https://api.digitalocean.com/v2/databases/$db_uuid/logsinks/$sink_id"
        else
            echo "No existing log sink found, creating new one..." >&2
        fi
    fi

    echo "Sending log sink configuration to DigitalOcean API using $method..." >&2

    local response
    response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X "$method" \
        -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$endpoint")

    local http_status
    http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
    local response_body
    response_body=$(echo "$response" | sed '$d')

    if [ "$http_status" -eq 201 ] || [ "$http_status" -eq 200 ]; then
        if [ "$method" = "POST" ]; then
            echo "✅ Log sink created successfully!" >&2
        else
            echo "✅ Log sink updated successfully!" >&2
        fi
        echo "Response:" >&2
        echo "$response_body" | jq '.' >&2
        return 0
    else
        echo "❌ Error configuring log sink (HTTP $http_status):" >&2
        echo "$response_body" | jq '.' >&2
        return 1
    fi
}

# Main execution
main() {
    echo "🔧 Configuring log sink for database: $DATABASE_NAME"
    echo "=================================================="

    # Step 1: Get database UUID
    local db_uuid
    db_uuid=$(get_database_uuid "$DATABASE_NAME")

    # Step 2: Get NLB DNS name
    local nlb_dns
    nlb_dns=$(get_nlb_dns_name)

    # Step 3: Get CA certificate
    local ca_cert
    ca_cert=$(get_ca_certificate)

    # Step 4: Configure log sink
    local endpoint_url="$nlb_dns"
    configure_log_sink "$db_uuid" "$DATABASE_NAME" "$endpoint_url" "$ca_cert"

    echo "=================================================="
    echo "✅ Log sink configuration completed!"
    echo ""
    echo "Database: $DATABASE_NAME (UUID: $db_uuid)"
    echo "Endpoint: $endpoint_url:6514 (TLS enabled)"
    echo ""
    echo "Logs from this database will now be forwarded to Loki via the rsyslog sink."
}

# Run main function
main "$@"
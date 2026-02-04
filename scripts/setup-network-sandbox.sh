#!/bin/bash
# Setup network sandbox using nftables based on scenario's sandbox.lua
# Usage: ./setup-network-sandbox.sh <scenario-dir>
#
# Reads sandbox.lua to determine:
# - Whether network is enabled
# - Which hosts are allowed
#
# Creates nftables rules accordingly. Use cleanup-network-sandbox.sh to remove.

set -euo pipefail

SCENARIO_DIR="$1"
TABLE_NAME="${2:-eval_sandbox}"

if [[ ! -d "$SCENARIO_DIR" ]]; then
    echo "Error: Scenario directory '$SCENARIO_DIR' not found" >&2
    exit 1
fi

SANDBOX_CONFIG="$SCENARIO_DIR/sandbox.lua"

# Default: no network
NETWORK_ENABLED="false"
ALLOWED_HOSTS=""

if [[ -f "$SANDBOX_CONFIG" ]]; then
    # Check if network is enabled
    if grep -q 'enabled = true' "$SANDBOX_CONFIG" 2>/dev/null; then
        NETWORK_ENABLED="true"
    fi

    # Extract hosts from the config
    # Look for lines like: "hostname", inside the hosts table
    ALLOWED_HOSTS=$(grep -oP '^\s*"[a-zA-Z0-9._-]+"\s*,' "$SANDBOX_CONFIG" 2>/dev/null | \
        tr -d '", ' | grep -v '^\s*$' | sort -u | tr '\n' ' ' || true)
fi

echo "Network enabled: $NETWORK_ENABLED"
echo "Allowed hosts: $ALLOWED_HOSTS"

# Resolve hostnames to IPs
ALLOWED_IPS=""
if [[ "$NETWORK_ENABLED" == "true" && -n "$ALLOWED_HOSTS" ]]; then
    for host in $ALLOWED_HOSTS; do
        # Resolve using getent, get unique IPv4 addresses
        ips=$(getent ahostsv4 "$host" 2>/dev/null | awk '{print $1}' | sort -u | head -10 || true)
        if [[ -n "$ips" ]]; then
            ALLOWED_IPS="$ALLOWED_IPS $ips"
            echo "Resolved $host -> $ips"
        else
            echo "Warning: Could not resolve $host" >&2
        fi
    done
fi

# Remove any existing table
sudo nft delete table inet "$TABLE_NAME" 2>/dev/null || true

if [[ "$NETWORK_ENABLED" == "false" ]]; then
    # Block all outbound network (except loopback and established)
    cat <<EOF | sudo nft -f -
table inet $TABLE_NAME {
    chain output {
        type filter hook output priority 0; policy accept;

        # Allow loopback
        oif lo accept

        # Allow established/related (for responses to allowed connections)
        ct state established,related accept

        # Block all new outbound TCP/UDP connections
        # This blocks new connections but allows the system to function
        ct state new tcp dport 1-65535 drop
        ct state new udp dport 1-65535 drop
    }
}
EOF
    echo "Network sandbox: ALL outbound connections blocked"
else
    # Allow only specific hosts
    cat <<EOF | sudo nft -f -
table inet $TABLE_NAME {
    set allowed_ips {
        type ipv4_addr
        flags interval
    }

    chain output {
        type filter hook output priority 0; policy accept;

        # Allow loopback
        oif lo accept

        # Allow established connections
        ct state established,related accept

        # Allow DNS (needed for any network access)
        ct state new udp dport 53 accept

        # Allow connections to allowed IPs
        ct state new ip daddr @allowed_ips accept

        # Block all other new outbound connections
        ct state new tcp dport 1-65535 drop
        ct state new udp dport 1-65535 drop
    }
}
EOF

    # Add resolved IPs to the allowed set
    for ip in $ALLOWED_IPS; do
        sudo nft add element inet "$TABLE_NAME" allowed_ips { "$ip" } 2>/dev/null || true
        echo "Added $ip to allowlist"
    done

    echo "Network sandbox: Only allowed hosts can be reached"
fi

# Output the table name for cleanup
echo "TABLE_NAME=$TABLE_NAME"

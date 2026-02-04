#!/bin/bash
# Cleanup network sandbox nftables rules
# Usage: ./cleanup-network-sandbox.sh [table-name]

set -euo pipefail

TABLE_NAME="${1:-eval_sandbox}"

if sudo nft list table inet "$TABLE_NAME" >/dev/null 2>&1; then
    sudo nft delete table inet "$TABLE_NAME"
    echo "Removed nftables table: $TABLE_NAME"
else
    echo "Table $TABLE_NAME not found, nothing to clean up"
fi

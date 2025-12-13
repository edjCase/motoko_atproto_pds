#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Error: network required (local/ic)"
    echo "Usage: $0 <network> <new_member_principal>"
    exit 1
fi

if [ -z "$2" ]; then
    echo "Error: new member principal required"
    echo "Usage: $0 <network> <new_member_principal>"
    exit 1
fi

network=$1
new_member=$2

# Get the directory where this script is located
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the current identity's principal (will be removed)
current_principal=$(dfx identity get-principal)

echo "Replacing you (${current_principal}) with new member (${new_member})..."

# Add the new member
echo "Step 1: Adding new member..."
"${script_dir}/add_member.sh" "${network}" "${new_member}"

# Remove the current identity
echo "Step 2: Removing you..."
"${script_dir}/remove_member.sh" "${network}" "${current_principal}"

echo "Successfully replaced you (${current_principal}) with ${new_member}"

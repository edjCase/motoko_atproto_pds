#!/bin/bash

if [ -z "$1" ]; then
    echo "Error: network required (local/ic)"
    echo "Usage: $0 <network> <memberId>"
    exit 1
fi

network=$1

canister_id=$(dfx canister id dao_backend  --network "${network}")

if [ -z "$2" ]; then
    echo "Error: member principal required"
    echo "Usage: $0 <network> <memberId>"
    exit 1
fi

memberId=$2

echo "Adding member '${memberId}' to the dao canister ${canister_id}..."

dfx canister call ${canister_id} addMember "(principal \"${memberId}\")" --network "${network}"
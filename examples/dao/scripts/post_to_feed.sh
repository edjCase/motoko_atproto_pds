#!/bin/bash

if [ -z "$1" ]; then
    echo "Error: network required (local/ic)"
    echo "Usage: $0 <network> <canister_id> <message>"
    exit 1
fi

network=$1
canister_id=$2

if [ -z "$3" ]; then
    echo "Error: message required"
    echo "Usage: $0 <network> <canister_id> <message>"
    exit 1
fi

message=$3

echo "Posting '${message}' to the feed of canister ${canister_id}..."

nowISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

dfx canister call ${canister_id} createRecord "(record {
        collection = \"app.bsky.feed.post\";
        rkey = null;
        \"record\" = variant { 
            map = vec {
                record { \"\$type\"; variant { text = \"app.bsky.feed.post\" }};
                record { \"text\"; variant { text = \"${message}\" } };
                record { \"createdAt\"; variant { text = \"${nowISO}\" } }
            }
        };
        validate = null;
        swapCommit = null;
      })" --network "${network}"
#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Error: plc_did argument required"
    echo "Usage: $0 <network> ('new'|<plc_did>) [mode]"
    echo "  Specify 'new' to create a new DID, or provide an existing PLC DID"
    exit 1
fi

if [ -z "$2" ]; then
    mode="auto"
else
    mode=$2
fi
plc_did=$2

port=":4943"
canister_id=$(dfx canister id pds --network "${network}" 2>/dev/null || dfx canister create pds --network "${network}" --no-wallet | grep -o 'canister id: [^ ]*' | awk '{print $3}')
hostname="${canister_id}.localhost"
fullDomain="${hostname}"

# Build PLC variant
if [ "$plc_did" = "new" ]; then
    echo "Deploying PDS to network '${network}' using mode '${mode}' with new DID..."
    
    # Create new PLC identity
    plc_variant="variant { new = record { alsoKnownAs = vec { \"at://${hostname}\" }; services = vec { record { id = \"atproto_pds\"; \"type\" = \"AtprotoPersonalDataServer\"; endpoint = \"https://${fullDomain}\" } } } }"
else
    echo "Deploying PDS to network 'local' using mode '${mode}' with existing DID: ${plc_did}..."
    # Use provided PLC DID
    plc_variant="variant { id = \"${plc_did}\" }"
fi

# Build candid args with all initialization parameters
candid_args="(record { owner = null; plcKind = ${plc_variant}; hostname = \"${hostname}\"; serviceSubdomain = null })"
echo "Candid args: ${candid_args}"

# Deploy PDS with initialization arguments
response=$(dfx deploy pds --argument-type idl --argument "${candid_args}" --network local --mode "${mode}")

echo "$response"

# Extract canister ID
canister_id=$(dfx canister id pds --network "local")

echo "Successfully deployed PDS canister with ID: ${canister_id} at: ${fullDomain}${port}"
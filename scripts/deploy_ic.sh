#!/bin/bash
set -e

# Parse arguments
if [ -z "$1" ]; then
    echo "Error: plc_did argument required"
    echo "Usage: $0 ('new'|<plc_did>) <hostname> [mode] [serviceSubdomain]"
    echo "  plc_did: Specify 'new' to create a new DID, or provide an existing PLC DID"
    echo "  hostname: Required. The base hostname (e.g., 'example.com')"
    echo "  mode: Optional. Deployment mode (default: 'auto')"
    echo "  serviceSubdomain: Optional. The service subdomain (default: null)"
    exit 1
fi

if [ -z "$2" ]; then
    echo "Error: hostname argument required"
    echo "Usage: $0 ('new'|<plc_did>) <hostname> [mode] [serviceSubdomain]"
    echo "  plc_did: Specify 'new' to create a new DID, or provide an existing PLC DID"
    echo "  hostname: Required. The base hostname (e.g., 'example.com')"
    echo "  mode: Optional. Deployment mode (default: 'auto')"
    echo "  serviceSubdomain: Optional. The service subdomain (default: null)"
    exit 1
fi

plc_did=$1
hostname=$2

# Optional arguments
if [ -z "$3" ]; then
    mode="auto"
else
    mode=$3
fi

if [ -z "$4" ]; then
    serviceSubdomain=
else
    serviceSubdomain=$4
fi

# Handle empty/whitespace serviceSubdomain
serviceSubdomain_trimmed=$(echo "$serviceSubdomain" | xargs)
if [ -z "$serviceSubdomain_trimmed" ]; then
    serviceSubdomainCandid="null"
    fullDomain="${hostname}"
else
    serviceSubdomainCandid="opt \"${serviceSubdomain_trimmed}\""
    fullDomain="${serviceSubdomain_trimmed}.${hostname}"
fi

port=""

# Build PLC variant
if [ "$plc_did" = "new" ]; then
    echo "Deploying PDS to network 'ic' using mode '${mode}' with new DID..."
    
    # Create new PLC identity
    plc_variant="variant { new = record { alsoKnownAs = vec { \"at://${hostname}\" }; services = vec { record { id = \"atproto_pds\"; \"type\" = \"AtprotoPersonalDataServer\"; endpoint = \"https://${fullDomain}\" } } } }"
else
    echo "Deploying PDS to network 'ic' using mode '${mode}' with existing DID: ${plc_did}..."
    # Use provided PLC DID
    plc_variant="variant { id = \"${plc_did}\" }"
fi

# Build candid args with all initialization parameters
candid_args="(record { owner = null; plcKind = ${plc_variant}; hostname = \"${hostname}\"; serviceSubdomain = ${serviceSubdomainCandid} })"
echo "Candid args: ${candid_args}"

# Deploy PDS with initialization arguments
response=$(dfx deploy pds --argument-type idl --argument "${candid_args}" --network ic --mode "${mode}")

echo "$response"

# Extract canister ID
canister_id=$(dfx canister id pds --network ic)

echo "Successfully deployed PDS canister with ID: ${canister_id} at: ${fullDomain}${port}"
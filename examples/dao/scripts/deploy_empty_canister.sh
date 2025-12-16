#!/usr/bin/env bash
set -euo pipefail

# Usage: ./create_local_canister_via_wallet.sh
# Uses the currently selected dfx identity as controller
# and the identity's configured wallet canister on the *local* network.

CONTROLLER="$(dfx identity get-principal)"
WALLET_ID="$(dfx identity get-wallet --network local)"

# 10T cycles as an example; adjust as desired.
CYCLES="10000000000000"

echo "Creating canister on local via wallet..."
echo "Controller: $CONTROLLER"
echo "Wallet ID:  $WALLET_ID"
echo "Cycles:     $CYCLES"
echo

# Call the wallet_create_canister method on the wallet canister.
DFX_OUTPUT=$(dfx canister call "$WALLET_ID" wallet_create_canister \
  '(record {
      cycles = '"$CYCLES"' : nat64;
      settings = record {
        controller = opt principal "'"$CONTROLLER"'";
        freezing_threshold = null;
        controllers = null;
        memory_allocation = null;
        compute_allocation = null;
      };
    })' \
  --network local)

echo "$DFX_OUTPUT"
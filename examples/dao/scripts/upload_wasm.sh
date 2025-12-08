#!/bin/bash

set -e
# Configuration
DEFAULT_CHUNK_SIZE=$((1 * 1024 * 1024))  # 1MB
DEFAULT_PATH="../../.dfx/ic/canisters/pds/pds.wasm"
CHUNK_SIZE=${CHUNK_SIZE:-$DEFAULT_CHUNK_SIZE}

if [ -z "$1" ]; then
    echo "Error: network required"
    echo "Usage: $0 <network> [wasm_file_path]"
    echo "Optional: CHUNK_SIZE=<bytes> $0 ..."
    echo "Default path: $DEFAULT_PATH"
    exit 1
fi

network=$1
wasm_file=${2:-$DEFAULT_PATH}

if [ ! -f "$wasm_file" ]; then
    echo "Error: WASM file not found: $wasm_file"
    exit 1
fi

canister_id=$(dfx canister id backend --network "${network}")

echo "===== WASM Upload ====="
echo "File: $wasm_file"
echo "Canister: $canister_id"
echo "Network: $network"
echo "Chunk size: $CHUNK_SIZE bytes"
echo ""

# Calculate SHA256
echo "[1/4] Calculating SHA256..."
if command -v sha256sum >/dev/null; then
    wasm_hash=$(sha256sum "$wasm_file" | cut -d' ' -f1)
elif command -v shasum >/dev/null; then
    wasm_hash=$(shasum -a 256 "$wasm_file" | cut -d' ' -f1)
else
    echo "Error: sha256sum/shasum not found"
    exit 1
fi
echo "Hash: $wasm_hash"

# Split file
temp_dir=$(mktemp -d)
trap "rm -rf $temp_dir" EXIT

echo ""
echo "[2/4] Splitting file..."
split -b $CHUNK_SIZE "$wasm_file" "$temp_dir/chunk_"
chunks=("$temp_dir"/chunk_*)
total_chunks=${#chunks[@]}
echo "Created $total_chunks chunks"

# Upload chunks
echo ""
echo "[3/4] Uploading chunks..."

hash_bytes=$(echo "$wasm_hash" | sed 's/../0x&;/g' | sed 's/;$//')

for i in "${!chunks[@]}"; do
    chunk_size=$(wc -c < "${chunks[$i]}")
    echo "  Uploading chunk $((i+1))/$total_chunks ($chunk_size bytes)..."
    
    # Create candid argument file
    arg_file="$temp_dir/arg_$i.txt"
    chunk_hex=$(xxd -p "${chunks[$i]}" | tr -d '\n')
    chunk_bytes=$(echo "$chunk_hex" | sed 's/../0x&;/g' | sed 's/;$//')
    
    echo "(record { wasmHash = vec { $hash_bytes }; index = $i : nat; chunk = vec { $chunk_bytes } })" > "$arg_file"
    
    echo "  Calling canister..."
    set +e
    dfx canister call $canister_id addWasmChunk \
        --argument-file "$arg_file" \
        --network $network
    exit_code=$?
    set -e
    
    if [ $exit_code -ne 0 ]; then
        echo "  ✗ Chunk $((i+1))/$total_chunks failed"
        exit 1
    fi
    echo "  ✓ Chunk $((i+1))/$total_chunks"
done

# Finalize
echo ""
echo "[4/4] Finalizing..."
set +e
dfx canister call "$canister_id" finalizeWasmChunks \
    "(vec { $hash_bytes })" \
    --network "$network"
exit_code=$?
set -e

if [ $exit_code -eq 0 ]; then
    echo "✓ Complete"
else
    echo "✗ Finalize failed"
    exit 1
fi
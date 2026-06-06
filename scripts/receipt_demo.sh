#!/bin/bash
# receipton — One-shot demo
# Generates a receipt for a real public Pharos mainnet tx so the demo is
# reproducible from a fresh checkout, no other arguments needed.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECEIPT_SH="$SCRIPT_DIR/receipt.sh"

# Real public mainnet tx that succeeded (verified via eth_getTransactionReceipt).
# You can swap in any Pharos mainnet hash you like.
DEMO_TX="${1:-0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7}"
NETWORK="${2:-mainnet}"
FORMAT="${3:-md}"
TEMPLATE="${4:-invoice}"

echo ""
echo "==========================================="
echo "  receipton demo"
echo "==========================================="
echo "  TX:        $DEMO_TX"
echo "  Network:   $NETWORK"
echo "  Format:    $FORMAT"
echo "  Template:  $TEMPLATE"
echo "==========================================="
echo ""

bash "$RECEIPT_SH" "$DEMO_TX" --network "$NETWORK" --format "$FORMAT" --template "$TEMPLATE"

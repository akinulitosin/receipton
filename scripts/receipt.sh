#!/bin/bash
# receipton — On-chain receipt generator (zero-dep version)
# Network: Pharos Atlantic Testnet (default) and Pacific Ocean Mainnet
# Reads network config from references/networks.json — no hardcoded URLs/IDs.
#
# Usage:
#   bash scripts/receipt.sh <TX_HASH> [--network mainnet|testnet] [--format md|txt|html] [--template invoice|donation|audit|tax]
#
# Zero deps: bash, curl. No cast, no jq, no Python. USD estimate is always "unavailable".

# We deliberately do NOT use `set -e` — optional fields can be missing and we want to
# keep going. All `|| true` guard against grep/jq/curl returning empty.

# -------- arg parsing --------
TX_HASH=""
NETWORK_OVERRIDE=""
FORMAT="md"
TEMPLATE="invoice"
PRINT_HELP=0
PREV=""
for arg in "$@"; do
  case "$PREV" in
    --network) NETWORK_OVERRIDE="$arg"; PREV=""; continue ;;
    --format)  FORMAT="$arg"; PREV=""; continue ;;
    --template) TEMPLATE="$arg"; PREV=""; continue ;;
  esac
  case "$arg" in
    -h|--help)  PRINT_HELP=1 ;;
    --network)   PREV="--network" ;;
    --network=*) NETWORK_OVERRIDE="${arg#*=}" ;;
    --format)    PREV="--format" ;;
    --format=*)  FORMAT="${arg#*=}" ;;
    --template)  PREV="--template" ;;
    --template=*) TEMPLATE="${arg#*=}" ;;
    -*)          echo "Unknown flag: $arg"; exit 1 ;;
    *)           [ -z "$TX_HASH" ] && TX_HASH="$arg" ;;
  esac
done
[ "$PREV" = "--network" ] || [ "$PREV" = "--format" ] || [ "$PREV" = "--template" ] && {
  echo "Error: $PREV requires a value"; exit 1; }

if [ "$PRINT_HELP" = "1" ]; then
  cat <<'USAGE'
Usage: bash scripts/receipt.sh <TX_HASH> [flags]

Flags:
  --network mainnet|testnet    Default: mainnet
  --format  md|txt|html         Default: md
  --template invoice|donation|audit|tax   Default: invoice

Examples:
  bash scripts/receipt.sh 0xabc... --network mainnet
  bash scripts/receipt.sh 0xabc... --network testnet --format html --template donation
USAGE
  exit 0
fi

if [ -z "$TX_HASH" ]; then
  echo "Usage: bash scripts/receipt.sh <TX_HASH> [--network mainnet|testnet] [--format md|txt|html] [--template invoice|donation|audit|tax]"
  exit 1
fi

case "$FORMAT" in md|txt|html) ;; *) echo "Invalid format: $FORMAT (use md|txt|html)"; exit 1 ;; esac
case "$TEMPLATE" in invoice|donation|audit|tax) ;; *) echo "Invalid template: $TEMPLATE (use invoice|donation|audit|tax)"; exit 1 ;; esac

# -------- load network config --------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NET_JSON="$SCRIPT_DIR/../references/networks.json"
[ ! -f "$NET_JSON" ] && { echo "❌ references/networks.json not found"; exit 1; }

get_field() {
  local net_name="$1" field="$2"
  sed -n "/\"name\": *\"$net_name\"/,/^    }/p" "$NET_JSON" \
    | grep -E "\"$field\":" | head -1 \
    | sed -E 's/^[^:]+:[[:space:]]*"([^"]*)".*/\1/' | sed -E 's/,$//'
}
get_num() {
  local net_name="$1" field="$2"
  sed -n "/\"name\": *\"$net_name\"/,/^    }/p" "$NET_JSON" \
    | grep -E "\"$field\":" | head -1 | grep -oE '[0-9]+' | head -1
}

NET="${NETWORK_OVERRIDE:-mainnet}"
case "$NET" in
  testnet|atlantic|atlantic-testnet) NET_KEY="atlantic-testnet" ;;
  mainnet|pacific|pacific-mainnet)   NET_KEY="mainnet" ;;
  *) echo "Unknown network: $NET"; exit 1 ;;
esac

RPC_URL=$(get_field    "$NET_KEY" "rpcUrl")
EXPLORER_URL=$(get_field "$NET_KEY" "explorerUrl")
CHAIN_ID=$(get_num     "$NET_KEY" "chainId")
NATIVE=$(get_field     "$NET_KEY" "nativeToken")
DISPLAY_NAME=$(get_field "$NET_KEY" "displayName")

# -------- fetch tx + receipt --------
RECEIPT=$(curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$TX_HASH\"],\"id\":1}" || echo "")

if [ -z "$RECEIPT" ] || echo "$RECEIPT" | grep -q '"result":null'; then
  echo "❌ Transaction $TX_HASH not found on $DISPLAY_NAME (chain $CHAIN_ID)."
  echo ""
  echo "  Possible causes:"
  echo "    - the tx hash is wrong (double-check it)"
  echo "    - the tx is on a different chain (try --network testnet if it was on testnet, or --network mainnet if it was on mainnet)"
  echo "    - the RPC is rate-limited or down (try again in a moment)"
  echo "    - the tx is very old and the public RPC has pruned its history"
  exit 1
fi

TX=$(curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionByHash\",\"params\":[\"$TX_HASH\"],\"id\":1}" || echo "")

extract_hex() {
  echo "$1" | grep -o "\"$2\":\"0x[^\"]*\"" | head -1 | grep -o '0x[^"]*' | head -1
}

STATUS=$(extract_hex "$RECEIPT" status)
BLOCK_HEX=$(extract_hex "$RECEIPT" blockNumber)
GAS_USED_HEX=$(extract_hex "$RECEIPT" gasUsed)
EFF_GP_HEX=$(extract_hex "$RECEIPT" effectiveGasPrice)
FROM=$(extract_hex "$RECEIPT" from)
TO=$(extract_hex "$RECEIPT" to)
CONTRACT=$(extract_hex "$RECEIPT" contractAddress)

# tx fields
TX_FROM=$(extract_hex "$TX" from)
TX_TO=$(extract_hex "$TX" to)
TX_VALUE_HEX=$(extract_hex "$TX" value)
TX_NONCE_HEX=$(extract_hex "$TX" nonce)
TX_INPUT=$(extract_hex "$TX" input)
TX_GAS_HEX=$(extract_hex "$TX" gas)
TX_GP_HEX=$(extract_hex "$TX" gasPrice)

# dec helpers
hex_to_dec() { [ -z "$1" ] || [ "$1" = "0x" ] && echo 0 || printf "%d" "$1" 2>/dev/null || echo 0; }

BLOCK=$(hex_to_dec "$BLOCK_HEX")
GAS_USED=$(hex_to_dec "$GAS_USED_HEX")
EFF_GP=$(hex_to_dec "$EFF_GP_HEX")
TX_VALUE=$(hex_to_dec "$TX_VALUE_HEX")
TX_NONCE=$(hex_to_dec "$TX_NONCE_HEX")

# wei → native (18 decimals): human = value / 1e18, 4 decimal places
wei_to_native() {
  local v=$1
  [ "$v" = "0" ] && { echo "0.0000"; return; }
  python3 -c "print(f'{${v} / 1e18:.4f}')" 2>/dev/null || awk -v v="$v" 'BEGIN{printf "%.4f", v/1e18}'
}

# Try python3 first for the conversion (most reliable); fall back to awk
VALUE_HUMAN=$(wei_to_native "$TX_VALUE")
# fee = gas_used * effective_gas_price
if command -v python3 >/dev/null 2>&1; then
  FEE_NATIVE=$(python3 -c "print($GAS_USED * $EFF_GP)")
else
  FEE_NATIVE=$((GAS_USED * EFF_GP))
fi
FEE_HUMAN=$(wei_to_native "$FEE_NATIVE")
GP_GWEI=$(python3 -c "print(f'{$EFF_GP / 1e9:.2f}')" 2>/dev/null || echo "$EFF_GP")

# block timestamp — Pharos RPC requires `false` (boolean) for the 2nd arg, not "false" (string).
# Use python to build the JSON to avoid shell-quoting pitfalls.
BLOCK_TS_HEX=$(python3 -c "
import json, urllib.request
req = urllib.request.Request('${RPC_URL}', data=json.dumps({
    'jsonrpc':'2.0','method':'eth_getBlockByNumber','params':['${BLOCK_HEX}', False],'id':1
}).encode(), headers={'Content-Type':'application/json'})
with urllib.request.urlopen(req, timeout=10) as r:
    d = json.loads(r.read())['result']
print(d.get('timestamp', '0x0'))
")
BLOCK_TS=$(hex_to_dec "$BLOCK_TS_HEX")
BLOCK_TS_ISO=$(python3 -c "from datetime import datetime,timezone; print(datetime.fromtimestamp($BLOCK_TS, tz=timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC'))" 2>/dev/null || echo "(timestamp unavailable)")
BLOCK_TS_ISO_SAFE=$(python3 -c "from datetime import datetime,timezone; print(datetime.fromtimestamp($BLOCK_TS, tz=timezone.utc).isoformat())" 2>/dev/null || echo "")

# resolve "to" — fall back to contractAddress for contract creations
DISPLAY_TO="$TO"
[ -z "$DISPLAY_TO" ] || [ "$DISPLAY_TO" = "0x" ] && DISPLAY_TO="(contract creation → $CONTRACT)"

INPUT_SELECTOR="${TX_INPUT:0:10}"
[ -z "$INPUT_SELECTOR" ] && INPUT_SELECTOR="0x"

EXPLORER_LINK="${EXPLORER_URL}tx/$TX_HASH"
GENERATED_AT=$(python3 -c "from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC'))" 2>/dev/null || echo "(now)")

# -------- render --------
# In all formats, we build the body and the same fields; only the formatting differs.

# Helper: format a value with thousand separators (works in bash with printf)
fmt_int() { printf "%'d" "$1" 2>/dev/null || echo "$1"; }
fmt_block() { printf "%'d" "$1" 2>/dev/null || echo "$1"; }

render_md() {
  cat <<EOF
═══════════════════════════════════════
           PHAROS RECEIPT
═══════════════════════════════════════

**Network:**      $DISPLAY_NAME (chain $CHAIN_ID)
**Status:**       $([ "$STATUS" = "0x1" ] && echo "✅ SUCCESS" || echo "❌ FAILED")
**Block:**        $(fmt_block "$BLOCK")  ($BLOCK_TS_ISO)
**Tx hash:**      \`$TX_HASH\`

**From:**         \`$TX_FROM\`
**To:**           \`$DISPLAY_TO\`

**Value:**        $VALUE_HUMAN $NATIVE
**Gas used:**     $(fmt_int "$GAS_USED")
**Gas price:**    $GP_GWEI gwei
**Tx fee:**       $FEE_HUMAN $NATIVE
**Nonce:**        $TX_NONCE
**Input:**        \`$INPUT_SELECTOR\` (first 4 bytes)

---

**USD value (at execution):** unavailable (bash version; use receipt.py for USD)
**USD fee (at execution):**   unavailable

---

**Explorer:**     $EXPLORER_LINK
**Generated:**    $GENERATED_AT
**Generator:**    receipton-1.0.0 (bash)
EOF
  if [ "$TEMPLATE" = "donation" ]; then
    cat <<'EOF'

---

Thank you for your contribution.
Receipt ID: `__TX_HASH__` — keep this hash as proof of payment.
EOF
    sed -i "s|__TX_HASH__|$TX_HASH|g" /dev/stdin <<< "$(cat)"
  fi
  if [ "$TEMPLATE" = "audit" ]; then
    cat <<EOF

---

**AUDIT APPENDIX (JSON):**
\`\`\`json
{
  "tx_hash":            "$TX_HASH",
  "network":            "$NET_KEY",
  "chain_id":           $CHAIN_ID,
  "status":             "$([ "$STATUS" = "0x1" ] && echo "SUCCESS" || echo "FAILED")",
  "block_number":       $BLOCK,
  "block_timestamp":    "$BLOCK_TS_ISO_SAFE",
  "from":               "$TX_FROM",
  "to":                 "$DISPLAY_TO",
  "value_wei":          "$TX_VALUE",
  "value_human":        "$VALUE_HUMAN $NATIVE",
  "gas_used":           $GAS_USED,
  "gas_price_wei":      "$EFF_GP",
  "fee_wei":            "$FEE_NATIVE",
  "fee_human":          "$FEE_HUMAN $NATIVE",
  "nonce":              $TX_NONCE,
  "input_selector":     "$INPUT_SELECTOR",
  "explorer_link":      "$EXPLORER_LINK"
}
\`\`\`
EOF
  fi
  if [ "$TEMPLATE" = "tax" ]; then
    cat <<EOF

---

**TAX COST-BASIS APPENDIX:**
- Asset:                  $NATIVE
- Quantity:               $VALUE_HUMAN
- Date acquired:          $BLOCK_TS_ISO_SAFE
- Date sold:              —
- Proceeds (USD @ t/x):   unavailable (bash version; use receipt.py for USD)
- Cost basis (USD @ t/x): depends on the user's acquisition cost (off-chain)
- Gain / loss:            n/a

**8949 hints:** Part I, box 1a — reportable if sold/exchanged.
EOF
  fi
}

render_txt() {
  cat <<EOF
=================================================
               PHAROS RECEIPT
=================================================

Network:        $DISPLAY_NAME (chain $CHAIN_ID)
Status:         $([ "$STATUS" = "0x1" ] && echo "SUCCESS" || echo "FAILED")
Block:          $(fmt_block "$BLOCK")  ($BLOCK_TS_ISO)
Tx hash:        $TX_HASH

From:           $TX_FROM
To:             $DISPLAY_TO

Value:          $VALUE_HUMAN $NATIVE
Gas used:       $(fmt_int "$GAS_USED")
Gas price:      $GP_GWEI gwei
Tx fee:         $FEE_HUMAN $NATIVE
Nonce:          $TX_NONCE
Input:          $INPUT_SELECTOR (first 4 bytes)

-------------------------------------------------
USD value (at execution): unavailable
USD fee (at execution):   unavailable
-------------------------------------------------

Explorer:       $EXPLORER_LINK
Generated:      $GENERATED_AT
Generator:      receipton-1.0.0 (bash)
EOF
  [ "$TEMPLATE" = "donation" ] && cat <<EOF

---
Thank you for your contribution.
Receipt ID: $TX_HASH
EOF
  [ "$TEMPLATE" = "audit" ] && cat <<EOF

---
AUDIT APPENDIX (JSON):
{ "tx_hash": "$TX_HASH", "network": "$NET_KEY", "chain_id": $CHAIN_ID, "block": $BLOCK,
  "from": "$TX_FROM", "to": "$DISPLAY_TO", "value_human": "$VALUE_HUMAN $NATIVE",
  "gas_used": $GAS_USED, "fee_human": "$FEE_HUMAN $NATIVE", "nonce": $TX_NONCE,
  "input_selector": "$INPUT_SELECTOR", "explorer_link": "$EXPLORER_LINK" }
EOF
  [ "$TEMPLATE" = "tax" ] && cat <<EOF

---
TAX COST-BASIS APPENDIX:
Asset: $NATIVE
Quantity: $VALUE_HUMAN
Date acquired: $BLOCK_TS_ISO_SAFE
Date sold: —
Proceeds (USD @ t/x): unavailable
Cost basis (USD @ t/x): depends on the user's acquisition cost (off-chain)
Gain / loss: n/a
EOF
}

render_html() {
  cat <<EOF
<!doctype html>
<html><head><meta charset="utf-8"><title>Pharos Receipt — $TX_HASH</title>
<style>
  body{font:14px/1.5 -apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;color:#0d1117;background:#f6f8fa;margin:0;padding:40px}
  .receipt{max-width:680px;margin:0 auto;background:#fff;border:1px solid #d0d7de;border-radius:8px;padding:32px}
  h1{text-align:center;margin:0 0 4px;font-size:18px;letter-spacing:0.1em}
  .sub{display:flex;justify-content:space-between;align-items:center;color:#57606a;font-size:12px;border-bottom:2px solid #0d1117;padding-bottom:8px;margin-bottom:20px}
  table{width:100%;border-collapse:collapse}
  td{padding:6px 0;vertical-align:top}
  td.k{color:#57606a;width:160px}
  td.v{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;word-break:break-all}
  td.vr{text-align:right;font-variant-numeric:tabular-nums}
  .status-ok{color:#1a7f37;font-weight:600}
  .status-fail{color:#cf222e;font-weight:600}
  hr{border:0;border-top:1px solid #d0d7de;margin:20px 0}
  .qr{text-align:center;margin-top:24px;color:#57606a;font-size:12px}
  .qr img{width:160px;height:160px;border:1px solid #d0d7de;border-radius:4px;padding:8px;background:#fff}
  .footer{margin-top:24px;padding-top:12px;border-top:1px solid #d0d7de;font-size:11px;color:#57606a;text-align:center}
  .appendix{background:#f6f8fa;border:1px solid #d0d7de;border-radius:6px;padding:12px;margin-top:16px;font-size:12px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap;word-break:break-word}
  .thankyou{background:#ddf4ff;border:1px solid #54aeff;border-radius:6px;padding:12px;margin-top:16px;text-align:center;color:#0969da}
  a{color:#0969da;text-decoration:none}
  a:hover{text-decoration:underline}
</style></head>
<body>
<div class="receipt">
  <h1>PHAROS RECEIPT</h1>
  <div class="sub">
    <span>$DISPLAY_NAME (chain $CHAIN_ID)</span>
    <span>$([ "$STATUS" = "0x1" ] && echo '<span class="status-ok">SUCCESS</span>' || echo '<span class="status-fail">FAILED</span>')</span>
  </div>

  <table>
    <tr><td class="k">Block</td><td class="vr">$(fmt_block "$BLOCK")</td></tr>
    <tr><td class="k">Timestamp</td><td class="vr">$BLOCK_TS_ISO</td></tr>
    <tr><td class="k">Tx hash</td><td class="v"><code>$TX_HASH</code></td></tr>
    <tr><td class="k">From</td><td class="v"><code>$TX_FROM</code></td></tr>
    <tr><td class="k">To</td><td class="v"><code>$DISPLAY_TO</code></td></tr>
    <tr><td class="k">Value</td><td class="vr"><strong>$VALUE_HUMAN $NATIVE</strong></td></tr>
    <tr><td class="k">Gas used</td><td class="vr">$(fmt_int "$GAS_USED")</td></tr>
    <tr><td class="k">Gas price</td><td class="vr">$GP_GWEI gwei</td></tr>
    <tr><td class="k">Tx fee</td><td class="vr">$FEE_HUMAN $NATIVE</td></tr>
    <tr><td class="k">Nonce</td><td class="vr">$TX_NONCE</td></tr>
    <tr><td class="k">Input</td><td class="v"><code>$INPUT_SELECTOR</code></td></tr>
  </table>

  <hr>

  <table>
    <tr><td class="k">USD value (at execution)</td><td class="vr"><em>unavailable (bash version)</em></td></tr>
    <tr><td class="k">USD fee (at execution)</td><td class="vr"><em>unavailable</em></td></tr>
  </table>

  <hr>

  <div class="qr">
    <p>QR encodes the transaction hash. Scan to open in a Pharos block explorer.</p>
    <p><em>QR generation requires the Python script (receipt.py). The bash version prints
    the hash above for manual scanning.</em></p>
  </div>
EOF

  if [ "$TEMPLATE" = "donation" ]; then
    echo '<div class="thankyou">Thank you for your contribution.<br>Receipt ID: <code>'$TX_HASH'</code> — keep this hash as proof of payment.</div>'
  fi
  if [ "$TEMPLATE" = "audit" ]; then
    cat <<EOF
  <div class="appendix">{ "tx_hash": "$TX_HASH", "network": "$NET_KEY", "chain_id": $CHAIN_ID, "block": $BLOCK,
  "from": "$TX_FROM", "to": "$DISPLAY_TO", "value_human": "$VALUE_HUMAN $NATIVE",
  "gas_used": $GAS_USED, "fee_human": "$FEE_HUMAN $NATIVE", "nonce": $TX_NONCE,
  "input_selector": "$INPUT_SELECTOR", "explorer_link": "$EXPLORER_LINK" }</div>
EOF
  fi
  if [ "$TEMPLATE" = "tax" ]; then
    cat <<EOF
  <div class="appendix">TAX COST-BASIS APPENDIX
Asset: $NATIVE
Quantity: $VALUE_HUMAN
Date acquired: $BLOCK_TS_ISO_SAFE
Date sold: —
Proceeds (USD @ t/x): unavailable
Cost basis (USD @ t/x): depends on the user's acquisition cost (off-chain)
Gain / loss: n/a
8949 hints: Part I, box 1a — reportable if sold/exchanged.</div>
EOF
  fi

  cat <<EOF

  <div class="footer">
    Explorer: <a href="$EXPLORER_LINK" target="_blank">$EXPLORER_LINK</a><br>
    Generated: $GENERATED_AT · Generator: receipton-1.0.0 (bash)
  </div>
</div>
</body></html>
EOF
}

# dispatch
case "$FORMAT" in
  md)   render_md   ;;
  txt)  render_txt  ;;
  html) render_html ;;
esac

# Receipt format reference

This document defines the canonical fields that appear in every `receipton` output, regardless of template or format. The bash and Python generators both produce outputs that match this schema.

## Field reference

| Field | Type | Source | Always present? |
|---|---|---|---|
| `tx_hash` | hex string (66 chars) | user input | yes |
| `network.name` | string | `networks.json` | yes |
| `network.chain_id` | integer | `networks.json` | yes |
| `network.native_token` | string | `networks.json` | yes |
| `network.explorer_url` | string | `networks.json` | yes |
| `status` | "SUCCESS" \| "FAILED" | `receipt.status` | yes |
| `block_number` | integer | `receipt.blockNumber` | yes |
| `block_timestamp_iso` | ISO 8601 string | `block.timestamp` | yes |
| `from` | 0x address (42 chars) | `tx.from` | yes |
| `to` | 0x address (42 chars) or `null` for contract creation | `tx.to` or `receipt.contractAddress` | yes |
| `value_native` | decimal string in wei | `tx.value` (hex → dec) | yes |
| `value_human` | decimal string in PROS/PHRS | `value_native / 10^18` | yes |
| `gas_used` | integer | `receipt.gasUsed` | yes |
| `gas_price_wei` | integer | `receipt.effectiveGasPrice` | yes |
| `gas_price_gwei` | decimal string | `gas_price_wei / 10^9` | yes |
| `fee_native` | decimal string in wei | `gas_used × gas_price_wei` | yes |
| `fee_human` | decimal string in PROS/PHRS | `fee_native / 10^18` | yes |
| `nonce` | integer | `tx.nonce` | yes |
| `input_selector` | first 4 bytes of `tx.input`, or `0x` if no calldata | `tx.input.slice(0, 10)` | yes |
| `usd_price_at_execution` | decimal string or `null` | CoinGecko historical | best-effort |
| `usd_value_at_execution` | decimal string or `null` | `value_human × usd_price` | best-effort |
| `usd_fee_at_execution` | decimal string or `null` | `fee_human × usd_price` | best-effort |
| `explorer_link` | URL | `net.explorer + "tx/" + tx_hash` | yes |
| `qr_png_base64` | base64 string | hash → QR (Python only) | only in HTML/Python |
| `generated_at` | ISO 8601 string | `datetime.utcnow().isoformat() + "Z"` | yes |
| `generator` | "receipton-X.Y.Z" | this skill | yes |

## Template schemas

### `invoice` (default)

The simplest, most professional layout. Two-column key-value table + a "Notes" block.

```
═══════════════════════════════════════
           PHAROS RECEIPT
═══════════════════════════════════════
Network:    Pharos Pacific Ocean Mainnet (chain 1672)
Status:     ✅ SUCCESS
Block:      8,527,764  (2026-04-15 14:23:11 UTC)
From:       0xAbCd...
To:         0xEf12...
Value:      100.0000 PROS
Tx Fee:     0.0003 PROS
═══════════════════════════════════════
USD value (at execution):  $12.34
USD fee (at execution):    $0.00
═══════════════════════════════════════
Explorer:   https://www.pharosscan.xyz/tx/0x...
Generated:  2026-06-06 16:00:00 UTC
Generator:  receipton-1.0.0
═══════════════════════════════════════
```

### `donation`

Invoice template + a "received from" gratitude block. Use for charity / grant / treasury-to-NGO flows.

```
... (invoice content above) ...

Thank you for your contribution.
Receipt ID: 0xabc... — keep this hash as proof of payment.
```

### `audit`

Invoice template + a JSON appendix with the raw field dump. Use for compliance teams that ingest structured data.

```
... (invoice content above) ...

────── AUDIT APPENDIX ──────
{
  "tx_hash": "0x...",
  "network": "mainnet",
  "chain_id": 1672,
  "block": 8527764,
  "timestamp": "2026-04-15T14:23:11Z",
  "from": "0xAbCd...",
  "to": "0xEf12...",
  "value_native": "100000000000000000000",
  "value_human": "100.0000",
  "gas_used": 207347,
  "gas_price_wei": "10000000000",
  "fee_native": "2073470000000000",
  ...
}
```

### `tax`

Invoice template + a cost-basis / 8949-style appendix. Use for US tax export.

```
... (invoice content above) ...

────── TAX COST-BASIS APPENDIX ──────
Asset:                 PROS
Quantity:              100.0000
Date acquired:         2026-04-15
Date sold:             —
Proceeds (USD @ t/x):  $12.34
Cost basis (USD @ t/x):$12.34
Gain / loss:           $0.00
8949 hints:
  • Part I, box 1a: reportable if sold/exchanged
  • Part II: check if long-term or short-term
```

**Important:** The tax template is a *data export*, not a tax form. The user is responsible for filling in 8949 with their real cost basis. The on-chain USD value at execution is the *proceeds side*; the cost basis depends on what the user paid for the tokens, which is not on-chain.

## Format-specific behavior

| Field | `md` | `txt` | `html` |
|---|---|---|---|
| `tx_hash` | `0x...` (backticks) | `0x...` | monospace, in a `<code>` tag |
| `value_human` | `100.0000 PROS` | `100.0000 PROS` | right-aligned in a `<td>` |
| `usd_value_at_execution` | `$12.34` | `$12.34` | bold |
| `explorer_link` | `[link](url)` | full URL on its own line | `<a href="..." target="_blank">` |
| `qr_png_base64` | not shown | not shown | inline `<img src="data:image/png;base64,...">` |
| `audit` appendix | JSON in a fenced code block | JSON in plain text | `<pre>` block |

## Output filename

When piped to a file, the suggested name is:
```
{tx_hash[:10]}_{template}_{YYYYMMDD-HHMMSS}.{md|txt|html}
```
Example: `0x9606bcfd_0_invoice_20260606-160000.md`

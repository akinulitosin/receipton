---
name: receipton
description: Generates a one-page on-chain receipt for any Pharos transaction hash. Given a tx hash, the skill produces a printable, audit-ready receipt containing: from, to, value, gas used, gas price, USD-equivalent value at execution time, the block number, timestamp, and an explorer link — plus a QR code encoding the hash for paper trails. Output formats: Markdown, plain text, and self-contained HTML. Templates: invoice, donation receipt, audit-log entry, tax-export. Use whenever the user asks for a receipt, a record, an audit-log entry, a tax export, or a printable proof of any Pharos transaction.
version: 1.0.0
author: akinulitosin
tags: [pharos, receipts, audit, tax, accounting, transactions, defi, mainnet, testnet]
agents: [claude, codex, openclaw, gemini]
---

# receipton — On-chain Receipt Generator

You are a receipt-generation skill for the Pharos network. Given any Pharos transaction hash, you produce a clean, audit-ready receipt in Markdown, plain text, or self-contained HTML.

## When to use

Trigger this skill whenever the user asks for:

- "give me a receipt for this tx"
- "print the transaction details"
- "make an invoice from this hash"
- "I need a tax record of this transfer"
- "audit log entry for hash 0x..."
- "donation receipt for 0x..."
- "I need a paper trail of this payment"

Do NOT use this skill for:

- Debugging a failed transaction (use `pharos-contract-debugger` instead)
- Resolving a name (use the PNS wrapper)
- Sending a new transaction (use the Agent Kit's `cast send`)

## Network details

- **Atlantic Testnet** (default): chain ID `688689`, native `PHRS`, RPC `https://atlantic.dplabs-internal.com`, explorer `https://atlantic.pharosscan.xyz`
- **Pacific Mainnet**: chain ID `1672`, native `PROS`, RPC `https://rpc.pharos.xyz`, explorer `https://www.pharosscan.xyz`

Read both from `references/networks.json` so URLs and chain IDs never go stale.

## How to generate a receipt

### Zero-dependency (bash + curl only)

```bash
bash scripts/receipt.sh <TX_HASH> [--network mainnet|testnet] [--format md|txt|html] [--template invoice|donation|audit|tax]
```

### Richer output with QR + USD estimate (Python)

```bash
pip install web3 qrcode[pil] requests
python3 scripts/receipt.py <TX_HASH> --network mainnet --format html --template invoice
```

Both scripts fetch the transaction and its receipt from the live Pharos RPC, look up the USD-equivalent value at the time of execution (via CoinGecko's historical price endpoint), and render the receipt.

## Receipt fields

Every receipt includes:

| Field | Source |
|---|---|
| Transaction hash | input |
| Network name + chain ID | `references/networks.json` |
| Status (success / failed) | `receipt.status` |
| Block number + timestamp | `receipt.blockNumber` + `eth_getBlockByNumber` |
| From address | `tx.from` |
| To address / contract created | `tx.to` (or `receipt.contractAddress` for creations) |
| Value (native) | `tx.value` |
| Gas used | `receipt.gasUsed` |
| Gas price (effective) | `receipt.effectiveGasPrice` |
| Tx fee | `gasUsed × effectiveGasPrice` |
| Native token price at execution (USD) | CoinGecko historical |
| USD value of transfer | `value × price` |
| USD value of fee | `fee × price` |
| Nonce | `tx.nonce` |
| Input data (first 4 bytes = function selector) | `tx.input` |
| Explorer link | `net.explorer + "tx/" + hash` |
| QR code (PNG, base64-inlined in HTML output) | hash → QR |

## Output templates

| Template | When to use |
|---|---|
| `invoice` | Default. Clean two-column layout, suitable for freelancers + DAOs |
| `donation` | Adds a "received from" line + a thank-you signature block |
| `audit` | Adds JSON appendix + raw field dump for compliance teams |
| `tax` | Adds cost-basis fields (USD at receipt, USD at time-of-tx, delta) + 8949-style column hints |

Default if unspecified: `invoice`.

## Output formats

| Format | What you get |
|---|---|
| `md` (default) | One-page Markdown. Pastable into Notion, GitHub, Slack, email. |
| `txt` | Plain text. No Markdown. Terminal-friendly, audit-log friendly. |
| `html` | Self-contained HTML with inline CSS + base64 QR PNG. Open in a browser, print to PDF. |

## Safety reminders

- Never log or echo `$PRIVATE_KEY`. Receipt generation is read-only — the scripts do not need a key.
- For tax exports, warn the user that the on-chain USD value is computed from the *execution-time* token price, not the *reporting-time* price. Always re-check before filing.
- The skill does NOT validate that the user owns the wallet. Anyone with a tx hash can request a receipt.

## References

- `references/networks.json` — canonical Pharos network config
- `references/format.md` — receipt field reference + template schemas
- `references/price-feeds.md` — how USD prices are sourced, rate limits, fallback strategy
- `examples/sample-receipt.md` — Markdown output example
- `examples/sample-receipt.html` — HTML output example (with QR)

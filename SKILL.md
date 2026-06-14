---
name: receipton
description: AI agent skill that generates a Markdown / plain-text / HTML receipt for any Pharos transaction. Takes a tx hash + network, fetches the receipt and tx via JSON-RPC, and renders a clean receipt with native, gas, fee, nonce, input selector, and explorer link. Supports 4 templates: invoice, donation, audit, tax. Use this skill whenever an agent needs to make a receipt, confirm a payment, or produce an audit-friendly record of an on-chain transaction. Triggers on phrases like "make a receipt for tx", "confirm payment", "transaction record", "audit report for tx", "pharos receipt", "tax cost basis".
version: 2.0.0
author: akinulitosin
requires: read
bins: [bash, curl, sed, grep, awk]
network: pharos
tags: [receipt, invoice, audit, tax, pharos, transaction, erc-20, native]
agents: [claude, codex, gemini, openclaw]
---

# Pharos On-Chain Receipt Generator

A bash + curl (JSON-RPC) skill that generates a Markdown / plain-text / HTML receipt for any Pharos transaction. Takes a tx hash + network, fetches the receipt and tx, and renders a clean receipt with native, gas, fee, nonce, input selector, and explorer link.

## Quick Actions

### Generate a Markdown receipt
```
Make a receipt for transaction 0xabc...def on Pharos mainnet
```

### Generate an HTML donation receipt
```
Make an HTML donation receipt for tx 0xabc...def on Pharos mainnet
```

### Generate an audit report (with JSON appendix)
```
Generate an audit report (with JSON appendix) for tx 0xabc...def
```

## Invocation

```bash
# Default: Markdown invoice on mainnet
bash scripts/receipt.sh 0xYOUR_TX_HASH

# HTML donation receipt
bash scripts/receipt.sh 0xYOUR_TX_HASH --format html --template donation

# Audit report (with JSON appendix)
bash scripts/receipt.sh 0xYOUR_TX_HASH --template audit

# Tax cost-basis report
bash scripts/receipt.sh 0xYOUR_TX_HASH --format txt --template tax
```

## Flags

| Flag | Description |
|---|---|
| `0xTX_HASH` | Transaction hash to receipt-ify (positional, required) |
| `--network mainnet \| testnet` | Pharos chain (default: testnet) |
| `--format md \| txt \| html` | Output format (default: md) |
| `--template invoice \| donation \| audit \| tax` | Receipt template (default: invoice) |
| `-h`, `--help` | Show the help text |

## Templates

| Template | What it adds |
|---|---|
| `invoice` (default) | Standard receipt: network, status, block, from, to, value, gas, fee, nonce, input selector, explorer link |
| `donation` | Adds a "Thank you" line and receipt ID for contribution tracking |
| `audit` | Adds a machine-readable JSON appendix with every field |
| `tax` | Adds a cost-basis appendix with date acquired, USD proceeds placeholder, and Form 8949 hints |

## Networks

| Network | Chain ID | RPC URL | Default |
|---|---:|---|:---:|
| mainnet (Pacific Ocean) | 1672 | `https://rpc.pharos.xyz` | |
| atlantic-testnet | 688689 | `https://atlantic.dplabs-internal.com` | ✓ |

Chain config is read from `references/networks.json` at startup.

## Dependencies

- **bash 4+** — preinstalled on macOS, Ubuntu 20+, most Linux
- **curl** — preinstalled on most systems
- **POSIX utilities** — `sed`, `grep`, `awk`, `printf`
- **(Optional)** Foundry — not used by the bash engine but `foundry.toml` is shipped for Agent Center compatibility

## Security model

- The skill is **read-only** — it never imports, reads, or stores a private key.
- It reads tx receipts and tx data via `eth_getTransactionReceipt` / `eth_getTransactionByHash` (read-only RPC).
- It never submits a transaction, never writes to disk (output goes to stdout).
- The only network call is to the user-configured RPC URL.

## Error handling

- Missing tx hash → usage hint + exit 1
- Bad tx hash format → no validation (JSON-RPC will return null)
- tx not found → "Transaction 0x... not found on $NETWORK"
- Unknown flag → "Unknown flag: X"
- Bad format → "Invalid format: X (use md|txt|html)"
- Bad template → "Invalid template: X (use invoice|donation|audit|tax)"
- Bad network → "Unknown network: X"

## Reference docs

- `references/format.md` — the field set rendered in each template
- `examples/sample-receipt.html` / `examples/sample-receipt.md` — annotated examples

## Repository layout

```
receipton/
├── SKILL.md              # This file
├── README.md             # Full documentation
├── foundry.toml          # Foundry config (for Agent Center compatibility)
├── LICENSE               # MIT
├── assets/
│   └── networks.json
├── references/
│   ├── format.md
│   └── price-feeds.md
├── examples/
│   ├── sample-receipt.html
│   └── sample-receipt.md
├── scripts/
│   └── receipt.sh        # The single bash script that does the work
└── tests/
    └── test_receipt_smoke.sh
```

# receipton

An on-chain receipt generator for the [Pharos Agent Center](https://www.pharos.xyz/agent-center). Given any Pharos transaction hash, produces a printable, audit-ready receipt in Markdown, plain text, or self-contained HTML — including a QR code encoding the hash, the USD value at execution time, the gas breakdown, and a link to the explorer.

Use it for **invoices, donation receipts, audit-log entries, and tax exports** of any Pharos transaction.

## What you get

A receipt is a single document containing:

| Field | Where it comes from |
|---|---|
| Transaction hash + status | Pharos RPC |
| Network + chain ID | `references/networks.json` |
| Block number + timestamp | `eth_getBlockByNumber` |
| From / to addresses | RPC |
| Value (native) | RPC |
| Gas used, effective gas price, fee | RPC |
| USD value at execution time | CoinGecko historical price |
| Function selector (first 4 bytes of input) | RPC |
| Explorer link | `references/networks.json` |
| QR code (PNG, base64-inlined in HTML) | hash → QR |

## Quick start

### Zero-dependency version (bash + curl only)

```bash
# Default: Markdown invoice on mainnet
bash scripts/receipt.sh 0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7

# Pick a network + format + template
bash scripts/receipt.sh 0xYOUR_TX --network testnet --format html --template donation
```

No `cast`, no `jq`, no Python. The bash script does everything with `curl` + `printf`.

### Richer version (Python, with QR + USD)

```bash
pip install web3 requests
# Optional but recommended for the QR code:
pip install qrcode[pil]

python3 scripts/receipt.py 0xYOUR_TX --network mainnet --format html --template invoice
```

The Python script adds:
- A real QR code (PNG, base64-embedded in HTML output)
- A historical USD price lookup via CoinGecko
- A cost-basis / 8949-style appendix for the `tax` template
- Cleaner Markdown for `md` output

## Templates

| Template | Use case |
|---|---|
| `invoice` (default) | Freelancers, DAOs, payments to contractors |
| `donation` | Charities, grants, treasury outflows to non-profits |
| `audit` | Compliance teams, on-chain forensics, regulatory archive |
| `tax` | US tax export, 8949-style cost-basis reporting |

## Output formats

| Format | What it is |
|---|---|
| `md` (default) | One-page Markdown. Pastable into Notion / GitHub / Slack / email. |
| `txt` | Plain text. Terminal-friendly, appendable to audit logs. |
| `html` | Self-contained HTML with inline CSS + base64 QR PNG. Browser-printable to PDF. |

## Networks

| Network | Chain ID | Native | RPC | Explorer |
|---|---:|---|---|---|
| Pharos Atlantic Testnet | 688689 | PHRS | `https://atlantic.dplabs-internal.com` | https://atlantic.pharosscan.xyz |
| Pharos Pacific Ocean Mainnet | 1672 | PROS | `https://rpc.pharos.xyz` | https://www.pharosscan.xyz |

## Repository layout

```
.
├── README.md
├── SKILL.md                          # Agent-side description
├── references/
│   ├── networks.json                 # Canonical Pharos config
│   ├── format.md                     # Receipt field reference
│   └── price-feeds.md                # How USD prices are sourced
├── scripts/
│   ├── receipt.sh                    # Zero-dep bash generator
│   ├── receipt.py                    # Python generator (QR + USD)
│   └── receipt_demo.sh               # One-shot demo with a real tx
├── tests/
│   ├── test_format.py                # Format tests (no network required)
│   └── test_price_feed.py            # CoinGecko fallback tests
└── examples/
    ├── sample-receipt.md             # Markdown sample
    └── sample-receipt.html           # HTML sample (with QR)
```

## Requirements

- `bash` 4+ and `curl` — for `scripts/receipt.sh` (zero deps beyond)
- `python3` 3.8+ and `pip install web3 requests` — for `scripts/receipt.py`
- `pip install qrcode[pil]` — only if you want the QR code in HTML output
- Internet access to `https://api.coingecko.com` — for the USD estimate (the script falls back to "USD value unavailable" if blocked)

## License

MIT

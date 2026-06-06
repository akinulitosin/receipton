# receipton

An on-chain receipt generator for the [Pharos Network](https://pharos.xyz). Given any Pharos transaction hash, produces a printable, audit-ready receipt in Markdown, plain text, or self-contained HTML — including a QR code encoding the hash, the USD value at execution time, the gas breakdown, and a link to the explorer.

Use it for **invoices, donation receipts, audit-log entries, and tax exports** of any Pharos transaction. Ships as a [Pharos Agent Center](https://www.pharos.xyz/agent-center) skill — drop it into Claude / Codex / OpenClaw and the agent can produce receipts on demand.

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

## Install

Pick **one** of the two install methods below.

### Option A — Clone the repo (for direct CLI use, forking, or self-hosting)

```bash
# 1. Clone
git clone https://github.com/akinulitosin/receipton.git
cd receipton
chmod +x scripts/receipt.sh scripts/receipt_demo.sh

# 2. Make scripts callable from anywhere
ln -s "$(pwd)/scripts/receipt.sh" /usr/local/bin/receipton
# (now you can run `receipton 0xYOUR_TX` from any directory)

# 3. (Optional) Python deps for the QR + USD version
pip install web3 requests
pip install qrcode[pil]   # only if you want the QR code in HTML output

# 4. (Optional) Install as a Pharos Agent Center / Claude Code / Codex / OpenClaw skill
mkdir -p ~/.pharos/skills
cp -r . ~/.pharos/skills/receipton
# (or: ~/.claude/skills/, ~/.codex/skills/ — same recipe)
```

### Option B — One-line via the OpenClaw registry

```bash
npx skills add https://github.com/akinulitosin/receipton
```

That's it. No build step, no compile. The skill is pure bash + Python.

### Verify the install

```bash
# 1. The zero-dep version needs only bash + curl
bash scripts/receipt.sh --help

# 2. The Python version needs web3 + requests
python3 scripts/receipt.py --help

# 3. The format tests should all pass
python3 tests/test_format.py
#   ✓ test_md_invoice_has_all_fields
#   ✓ test_md_donation_appends_thankyou
#   ✓ test_md_audit_appends_json
#   ✓ test_md_tax_appends_8949_hint
#   ✓ test_txt_invoice_has_all_fields
#   ✓ test_html_invoice_has_table_and_styles
#   ✓ test_html_invoice_inlines_qr_when_provided
#   ✓ test_html_failed_status_uses_fail_class
#   ✓ test_all_templates_render_without_exception
# 9 test(s) passed
```

## Quick start

Once installed (any of the methods above):

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

### Runtime

| Tool | Version | Required by | Notes |
|---|---|---|---|
| `bash` | 4+ | `scripts/receipt.sh` | shell interpreter |
| `curl` | any | `scripts/receipt.sh` | for the JSON-RPC calls |
| `python3` | 3.8+ | `scripts/receipt.py` | interpreter |
| `cast` / `forge` | any | (optional) | for the underlying Pharos Agent Kit — not required to run the scripts directly |

### Python packages (only for `receipt.py`)

```bash
pip install web3 requests
# Optional, for the QR code in HTML output:
pip install qrcode[pil]
```

The bash script needs **none** of these.

### Network access

| Endpoint | Why | Fallback if blocked |
|---|---|---|
| `https://rpc.pharos.xyz` (mainnet) | fetch the tx + receipt + block | none — the skill is read-only against the chain |
| `https://atlantic.dplabs-internal.com` (testnet) | same, for testnet | none |
| `https://api.coingecko.com` (Python script only) | historical USD price | the script falls back to `"unavailable"` rather than failing |

## Framework compatibility

| Framework | Compatible? | How to use |
|---|---|---|
| Pharos Agent Center (official) | ✅ yes | drop `SKILL.md` into `~/.pharos/skills/receipton/` — the agent will pick it up automatically |
| Claude Code | ✅ yes | drop `SKILL.md` into `~/.claude/skills/` |
| Codex | ✅ yes | drop `SKILL.md` into `~/.codex/skills/` |
| OpenClaw | ✅ yes | drop into the global skills directory or use `npx skills add https://github.com/akinulitosin/receipton` |
| Raw CLI / cron | ✅ yes | `bash scripts/receipt.sh 0x...` or `python3 scripts/receipt.py 0x...` — no agent needed |
| Any agent that reads SKILL.md | ✅ yes | the skill description triggers on "receipt", "audit", "tax", "invoice" |

## Tests

```bash
# 9 format tests, no network required
python3 tests/test_format.py

# (output)
#   ✓ test_md_invoice_has_all_fields
#   ✓ test_md_donation_appends_thankyou
#   ✓ test_md_audit_appends_json
#   ✓ test_md_tax_appends_8949_hint
#   ✓ test_txt_invoice_has_all_fields
#   ✓ test_html_invoice_has_table_and_styles
#   ✓ test_html_invoice_inlines_qr_when_provided
#   ✓ test_html_failed_status_uses_fail_class
#   ✓ test_all_templates_render_without_exception
# 9 test(s) passed
```

## License

MIT

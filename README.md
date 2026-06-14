# Pharos On-Chain Receipt Generator

> Generate a Markdown / plain-text / HTML receipt for any Pharos transaction, with native, gas, fee, and explorer link.

[![foundry](https://img.shields.io/badge/built%20with-Foundry-orange)]()
[![bash](https://img.shields.io/badge/script-bash-blue)]()
[![license](https://img.shields.io/badge/license-MIT-green)]()
[![pharos](https://img.shields.io/badge/network-Pharos-blueviolet)]()
[![ai-agent](https://img.shields.io/badge/callable%20by-AI%20agent-purple)]()

## What it is

This is a **skill built for the Pharos network** — a self-contained, deterministic bash script that runs on top of the [Pharos](https://pharos.network) EVM chains. It is **not** an AI agent itself, and not a chatbot. It is a single bash script that:

- takes input from the caller via CLI flags,
- reads live on-chain data from Pharos via JSON-RPC,
- renders a clean receipt (Markdown, text, or HTML) to stdout.

Takes a transaction hash + network, fetches the receipt and tx via JSON-RPC, and renders a clean receipt in one of three formats (Markdown, text, or HTML) with one of four templates (invoice, donation, audit, tax). Reads live data from Pharos mainnet (chain 1672) or Atlantic testnet (chain 688689) via the chain config in `references/networks.json`. Output is self-contained — no external CSS, no JS, just a single HTML file with inline styles. The audit template adds a machine-readable JSON appendix; the tax template adds an IRS Form 8949 cost-basis appendix.

## Use it from an AI agent

This skill is designed to be **called by an AI agent** (a Claude Code / Codex / Cursor agent, the Pharos Agent Center, or any custom LLM agent). The agent reads `SKILL.md` to discover the skill's flags, fills them in based on the user's request, and runs the bash script in its sandbox. The agent's job is just to translate "make a receipt for tx 0xabc" into `bash scripts/receipt.sh 0xabc`.

Typical agent-side flow:

```text
User -> Agent: "Make a receipt for tx 0xabc...def on Pharos mainnet"
Agent -> looks up SKILL.md for Pharos On-Chain Receipt Generator
Agent -> runs: bash scripts/receipt.sh 0xabc...def
Agent -> reads the rendered output and presents it to the user
```

The script prints structured output to stdout, so the agent can pipe it directly to the user or write it to a file.

## Install

You need two things: **`bash` 4+** and **`git`** to clone the repo. The script uses standard POSIX utilities (curl, sed, grep, awk) and a Foundry cast is available if you need it.

```bash
git clone https://github.com/akinulitosin/receipton.git
cd receipton
chmod +x scripts/*.sh tests/*.sh
```

## Quick test (30 seconds, no API keys needed)

```bash
bash scripts/receipt.sh --help
```

## Usage

```bash
# Default: Markdown invoice on mainnet
bash scripts/receipt.sh 0xYOUR_TX_HASH

# HTML donation receipt on mainnet
bash scripts/receipt.sh 0xYOUR_TX_HASH --format html --template donation

# Markdown audit report on testnet (with JSON appendix)
bash scripts/receipt.sh 0xYOUR_TX_HASH --network testnet --template audit

# Plain-text tax cost-basis on mainnet
bash scripts/receipt.sh 0xYOUR_TX_HASH --format txt --template tax
```

### All flags

```
0xTX_HASH --network mainnet|testnet --format md|txt|html --template invoice|donation|audit|tax
```

| Flag | Description |
|---|---|
| `0xTX_HASH` | The transaction hash to receipt-ify (positional, required) |
| `--network mainnet \| testnet` | Pharos chain (default: testnet) |
| `--format md \| txt \| html` | Output format (default: md) |
| `--template invoice \| donation \| audit \| tax` | Receipt template (default: invoice) |
| `-h`, `--help` | Show the help text |

## Templates

| Template | What it adds |
|---|---|
| `invoice` (default) | Standard receipt: network, status, block, from, to, value, gas, fee, nonce, input selector, explorer link |
| `donation` | Adds a "Thank you" line and receipt ID for contribution tracking |
| `audit` | Adds a machine-readable JSON appendix with every field (audit-friendly) |
| `tax` | Adds a cost-basis appendix with date acquired, USD proceeds placeholder, and Form 8949 hints |

## Networks

The skill is built to run against the Pharos EVM chains. The chain config is stored in `references/networks.json` and read at startup — no hardcoded URLs in the script.

| Network | Chain ID | RPC URL | Default |
|---|---:|---|:---:|
| mainnet (Pacific Ocean) | 1672 | `https://rpc.pharos.xyz` | |
| atlantic-testnet | 688689 | `https://atlantic.dplabs-internal.com` | ✓ |

The script defaults to testnet (since the bash engine doesn't sign or broadcast, you can run it freely on either). Pass `--network mainnet` to use mainnet.

## Set it up in an AI agent

Three install paths for any AI agent that wants to call this skill.

### Path A — Pharos Agent Center (for the official Pharos LLM agent)

The Pharos Agent Center is the official agent runtime for the Pharos network. It reads `SKILL.md` from any skill repo to discover capabilities, dependencies, and required flags.

1. **Copy the skill into the Agent Center's skills directory:**
   ```bash
   cp -r scripts assets references examples SKILL.md README.md foundry.toml LICENSE \
     ~/.pharos/agent-center/skills/receipton/
   ```

2. **Reload the Agent Center's skill registry:**
   ```bash
   pharos-agent reload-skills
   ```

3. **Invoke from the agent's chat UI:**
   ```text
   User: "Generate a receipt for transaction 0xabc...def on Pharos mainnet"
   Agent Center: loads Pharos On-Chain Receipt Generator, runs:
     bash ~/.pharos/agent-center/skills/receipton/scripts/receipt.sh 0xTX_HASH --network mainnet
   ```

### Path B — `npx skills add` (for Claude Code, Cursor, Codex, generic MCP agents)

```bash
npx skills add https://github.com/akinulitosin/receipton --skill receipton
```

### Path C — Manual copy (any agent that reads `~/.claude/skills/`)

```bash
mkdir -p ~/.claude/skills/receipton
cp -r scripts assets references examples SKILL.md README.md foundry.toml LICENSE ~/.claude/skills/receipton/
```

### Path D — Direct invocation (shell agents, cron jobs, CI pipelines)

```bash
bash scripts/receipt.sh 0xTX_HASH --format html --template donation > receipt.html
```

### What the agent says to invoke this skill

| Caller says | Script invocation |
|---|---|
| Receipt for tx `0xabc...def` on Pharos mainnet | `bash scripts/receipt.sh 0xabc...def` |
| HTML donation receipt for tx `0xabc...def` | `bash scripts/receipt.sh 0xabc...def --format html --template donation` |
| Audit report (with JSON appendix) for tx `0xabc...def` | `bash scripts/receipt.sh 0xabc...def --template audit` |
| "Show the help" | `bash scripts/receipt.sh --help` |

## Security model

The skill is **read-only by design**:

- The script never imports, reads, or stores a private key.
- It reads tx receipts and tx data via `eth_getTransactionReceipt` / `eth_getTransactionByHash` / `eth_getBlockByNumber` (read-only RPC).
- It never submits a transaction, never writes to disk (output goes to stdout).
- The only network call is to the user-configured RPC URL.

## Framework

| Layer | Tech | Purpose |
|---|---|---|
| Engine | **bash 4+** | Script host (single file per skill) |
| RPC client | **curl + JSON-RPC** | Read-only chain reads |
| Chain config | **JSON** (`references/networks.json`) | Network endpoints + chain IDs |
| Renderers | **bash heredocs** | Three output formats (Markdown, text, HTML) |
| Runtime | Any POSIX shell | Tested on Linux + macOS |

## Dependencies

**Required:**
- `bash` 4+ (preinstalled on macOS, Ubuntu 20+, most Linux)
- `curl` (preinstalled on most systems)
- POSIX utilities: `sed`, `grep`, `awk`, `printf`

**Optional:**
- `git` — only required if you're cloning the repo (you already have it)

**For Foundry-based chains (optional):** [Foundry](https://getfoundry.sh) — not used by the bash engine but `foundry.toml` is shipped for Agent Center compatibility.

## Tests

Each repo ships with a bash smoke test that verifies:
1. `--help` works (no cast required)
2. No-args shows the usage hint
3. Unknown flags are rejected
4. Bad format is rejected
5. Bad template is rejected
6. Bad network is rejected

```bash
bash tests/test_receipt_smoke.sh
```

The test runs offline by default. A live `--network mainnet` test against a real tx will make one JSON-RPC call.

## Reference docs

- `references/format.md` — the field set rendered in each template
- `references/price-feeds.md` — the planned USD price feed integration (not yet shipped in the bash engine)

## Repository layout

```
receipton/
├── SKILL.md              # Skill contract
├── README.md             # This file
├── foundry.toml          # Foundry config (for Agent Center compatibility)
├── LICENSE               # MIT
├── assets/
│   └── networks.json     # mainnet + testnet chain config
├── references/
│   ├── format.md
│   └── price-feeds.md
├── examples/
│   ├── sample-receipt.html
│   └── sample-receipt.md
├── scripts/
│   └── receipt.sh          # The single bash script that does the work
└── tests/
    └── test_receipt_smoke.sh   # Offline smoke test
```

## License

MIT — see `LICENSE`.

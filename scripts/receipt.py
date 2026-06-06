#!/usr/bin/env python3
"""
receipton — On-chain receipt generator (Python version with QR + USD estimate)
Network: Pharos Atlantic Testnet + Pacific Ocean Mainnet

Usage:
  python3 scripts/receipt.py <TX_HASH> [--network mainnet|testnet] [--format md|txt|html] [--template invoice|donation|audit|tax]

Dependencies:
  pip install web3 requests
  pip install qrcode[pil]   # optional, for QR in HTML output
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

# -------- locate references/networks.json relative to this script --------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NET_JSON = os.path.join(SCRIPT_DIR, "..", "references", "networks.json")


# -------- network config --------
def load_networks():
    with open(NET_JSON) as f:
        return json.load(f)["networks"]


def pick_network(networks, key):
    aliases = {
        "testnet": "atlantic-testnet", "atlantic": "atlantic-testnet",
        "mainnet": "mainnet", "pacific": "mainnet",
    }
    key = aliases.get(key, key)
    for n in networks:
        if n["name"] == key:
            return n
    raise SystemExit(f"Unknown network: {key}")


# -------- JSON-RPC helper --------
def rpc(net, method, params):
    body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
    req = Request(net["rpcUrl"], data=body, headers={"Content-Type": "application/json"})
    with urlopen(req, timeout=15) as r:
        return json.loads(r.read())["result"]


# -------- price feed (CoinGecko, with cache) --------
PRICE_CACHE = {}

def get_usd_price(net, iso_date):
    if iso_date in PRICE_CACHE:
        return PRICE_CACHE[iso_date]
    cg_id = net.get("coingeckoId")
    if not cg_id:
        PRICE_CACHE[iso_date] = (None, "no-coingecko-id")
        return PRICE_CACHE[iso_date]
    day, month, year = iso_date.split("-")[2], iso_date.split("-")[1], iso_date.split("-")[0]
    url = f"https://api.coingecko.com/api/v3/coins/{cg_id}/history?date={day}-{month}-{year}"
    try:
        req = Request(url, headers={"User-Agent": "receipton/1.0"})
        with urlopen(req, timeout=8) as r:
            data = json.loads(r.read())
        price = data.get("market_data", {}).get("current_price", {}).get("usd")
        PRICE_CACHE[iso_date] = (price, "coingecko-history")
        return PRICE_CACHE[iso_date]
    except (URLError, HTTPError, KeyError, json.JSONDecodeError) as e:
        PRICE_CACHE[iso_date] = (None, f"unavailable: {type(e).__name__}")
        return PRICE_CACHE[iso_date]


# -------- formatting helpers --------
def hex_to_int(h):
    if h is None or h == "" or h == "0x":
        return 0
    return int(h, 16)

def wei_to_native(v):
    return v / 1e18

def fmt_int(n):
    return f"{n:,}"

def iso_ts(epoch):
    if epoch is None or epoch == 0:
        return "(unavailable)", ""
    dt = datetime.fromtimestamp(epoch, tz=timezone.utc)
    return dt.strftime("%Y-%m-%d %H:%M:%S UTC"), dt.isoformat()


# -------- main analyzer --------
def analyze(tx_hash, net):
    receipt = rpc(net, "eth_getTransactionReceipt", [tx_hash])
    if receipt is None:
        raise SystemExit(f"❌ Transaction {tx_hash} not found on {net['displayName']} (chain {net['chainId']}).")

    tx = rpc(net, "eth_getTransactionByHash", [tx_hash])
    block_hash = receipt["blockHash"]
    block = rpc(net, "eth_getBlockByHash", [block_hash, False]) if block_hash else None
    block_ts = int(block["timestamp"], 16) if block and "timestamp" in block else None
    block_iso, block_iso_safe = iso_ts(block_ts)

    status = "SUCCESS" if receipt["status"] == "0x1" else "FAILED"
    gas_used = hex_to_int(receipt.get("gasUsed"))
    eff_gp = hex_to_int(receipt.get("effectiveGasPrice", "0x0"))
    fee_wei = gas_used * eff_gp
    fee_native = wei_to_native(fee_wei)

    value_wei = hex_to_int(tx.get("value"))
    value_native = wei_to_native(value_wei)

    from_addr = tx.get("from", "")
    to_addr = tx.get("to")
    if not to_addr:
        to_addr = receipt.get("contractAddress") or "(contract creation)"
    nonce = hex_to_int(tx.get("nonce"))
    input_data = tx.get("input", "0x")
    input_selector = input_data[:10] if input_data else "0x"

    usd_price, price_src = (None, "unavailable")
    usd_value_str, usd_fee_str = "unavailable", "unavailable"
    if block_iso_safe:
        date_only = block_iso_safe.split("T")[0]
        usd_price, price_src = get_usd_price(net, date_only)
        if usd_price is not None:
            usd_value_str = f"${value_native * usd_price:,.2f}"
            usd_fee_str = f"${fee_native * usd_price:,.6f}"

    explorer_link = f"{net['explorerUrl']}tx/{tx_hash}"
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    return {
        "tx_hash": tx_hash, "network": net, "status": status,
        "block": hex_to_int(receipt["blockNumber"]),
        "block_ts_iso": block_iso, "block_ts_iso_safe": block_iso_safe,
        "from": from_addr, "to": to_addr, "to_raw": tx.get("to"),
        "value_wei": value_wei, "value_native": value_native,
        "value_human": f"{value_native:.4f} {net['nativeToken']}",
        "gas_used": gas_used, "gas_price_wei": eff_gp,
        "gas_price_gwei": f"{eff_gp / 1e9:.2f}",
        "fee_wei": fee_wei, "fee_native": fee_native,
        "fee_human": f"{fee_native:.6f} {net['nativeToken']}",
        "nonce": nonce, "input_selector": input_selector,
        "usd_price": usd_price, "usd_price_source": price_src,
        "usd_value": usd_value_str, "usd_fee": usd_fee_str,
        "explorer_link": explorer_link, "generated_at": generated_at,
    }


# -------- renderers --------
def render_md(r, template):
    status_md = "✅ SUCCESS" if r["status"] == "SUCCESS" else "❌ FAILED"
    out = f"""═══════════════════════════════════════
           PHAROS RECEIPT
═══════════════════════════════════════

**Network:**      {r['network']['displayName']} (chain {r['network']['chainId']})
**Status:**       {status_md}
**Block:**        {fmt_int(r['block'])}  ({r['block_ts_iso']})
**Tx hash:**      `{r['tx_hash']}`

**From:**         `{r['from']}`
**To:**           `{r['to']}`

**Value:**        {r['value_human']}
**Gas used:**     {fmt_int(r['gas_used'])}
**Gas price:**    {r['gas_price_gwei']} gwei
**Tx fee:**       {r['fee_human']}
**Nonce:**        {r['nonce']}
**Input:**        `{r['input_selector']}` (first 4 bytes)

---

**USD value (at execution):** {r['usd_value']}  _(source: {r['usd_price_source']})_
**USD fee (at execution):**   {r['usd_fee']}

---

**Explorer:**     {r['explorer_link']}
**Generated:**    {r['generated_at']}
**Generator:**    receipton-1.0.0 (python)
"""
    if template == "donation":
        out += f"""
---

Thank you for your contribution.
Receipt ID: `{r['tx_hash']}` — keep this hash as proof of payment.
"""
    if template == "audit":
        out += f"""
---

**AUDIT APPENDIX (JSON):**
```json
{json.dumps({
  "tx_hash": r["tx_hash"], "network": r["network"]["name"],
  "chain_id": r["network"]["chainId"], "status": r["status"],
  "block_number": r["block"], "block_timestamp": r["block_ts_iso_safe"],
  "from": r["from"], "to": r["to"],
  "value_wei": str(r["value_wei"]), "value_human": r["value_human"],
  "gas_used": r["gas_used"], "gas_price_wei": str(r["gas_price_wei"]),
  "fee_wei": str(r["fee_wei"]), "fee_human": r["fee_human"],
  "nonce": r["nonce"], "input_selector": r["input_selector"],
  "usd_price_usd": r["usd_price"], "usd_price_source": r["usd_price_source"],
  "explorer_link": r["explorer_link"]
}, indent=2)}
```
"""
    if template == "tax":
        out += f"""
---

**TAX COST-BASIS APPENDIX:**
- Asset:                  {r['network']['nativeToken']}
- Quantity:               {r['value_human']}
- Date acquired:          {r['block_ts_iso_safe']}
- Date sold:              —
- Proceeds (USD @ t/x):   {r['usd_value']}
- Cost basis (USD @ t/x): depends on the user's acquisition cost (off-chain)
- Gain / loss:            n/a

**8949 hints:** Part I, box 1a — reportable if sold/exchanged.
"""
    return out


def render_txt(r, template):
    status_txt = "SUCCESS" if r["status"] == "SUCCESS" else "FAILED"
    out = f"""=================================================
               PHAROS RECEIPT
=================================================

Network:        {r['network']['displayName']} (chain {r['network']['chainId']})
Status:         {status_txt}
Block:          {fmt_int(r['block'])}  ({r['block_ts_iso']})
Tx hash:        {r['tx_hash']}

From:           {r['from']}
To:             {r['to']}

Value:          {r['value_human']}
Gas used:       {fmt_int(r['gas_used'])}
Gas price:      {r['gas_price_gwei']} gwei
Tx fee:         {r['fee_human']}
Nonce:          {r['nonce']}
Input:          {r['input_selector']} (first 4 bytes)

-------------------------------------------------
USD value (at execution): {r['usd_value']}  (source: {r['usd_price_source']})
USD fee (at execution):   {r['usd_fee']}
-------------------------------------------------

Explorer:       {r['explorer_link']}
Generated:      {r['generated_at']}
Generator:      receipton-1.0.0 (python)
"""
    if template == "donation":
        out += f"\n---\nThank you for your contribution.\nReceipt ID: {r['tx_hash']}\n"
    if template == "audit":
        out += f"\n---\nAUDIT APPENDIX (JSON):\n{json.dumps({k:r[k] for k in ('tx_hash','status','block','from','to','value_human','gas_used','fee_human','nonce','input_selector','explorer_link')}, indent=2)}\n"
    if template == "tax":
        out += f"\n---\nTAX COST-BASIS APPENDIX:\nAsset: {r['network']['nativeToken']}\nQuantity: {r['value_human']}\nDate acquired: {r['block_ts_iso_safe']}\nDate sold: -\nProceeds (USD @ t/x): {r['usd_value']}\nCost basis (USD @ t/x): depends on the user's acquisition cost (off-chain)\nGain / loss: n/a\n8949 hints: Part I, box 1a — reportable if sold/exchanged.\n"
    return out


def render_html(r, template, qr_png_b64=None):
    status_class = "status-ok" if r["status"] == "SUCCESS" else "status-fail"
    qr_block = ""
    if qr_png_b64:
        qr_block = f"""
  <div class="qr">
    <p>QR encodes the transaction hash. Scan to open in a Pharos block explorer.</p>
    <img src="data:image/png;base64,{qr_png_b64}" alt="QR for {r['tx_hash']}">
  </div>"""
    else:
        qr_block = """
  <div class="qr">
    <p>QR generation requires the <code>qrcode</code> Python package.<br>
       Install with <code>pip install qrcode[pil]</code> to enable.</p>
  </div>"""

    out = f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Pharos Receipt — {r['tx_hash']}</title>
<style>
  body{{font:14px/1.5 -apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;color:#0d1117;background:#f6f8fa;margin:0;padding:40px}}
  .receipt{{max-width:680px;margin:0 auto;background:#fff;border:1px solid #d0d7de;border-radius:8px;padding:32px}}
  h1{{text-align:center;margin:0 0 4px;font-size:18px;letter-spacing:0.1em}}
  .sub{{display:flex;justify-content:space-between;align-items:center;color:#57606a;font-size:12px;border-bottom:2px solid #0d1117;padding-bottom:8px;margin-bottom:20px}}
  table{{width:100%;border-collapse:collapse}}
  td{{padding:6px 0;vertical-align:top}}
  td.k{{color:#57606a;width:160px}}
  td.v{{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;word-break:break-all}}
  td.vr{{text-align:right;font-variant-numeric:tabular-nums}}
  .status-ok{{color:#1a7f37;font-weight:600}}
  .status-fail{{color:#cf222e;font-weight:600}}
  hr{{border:0;border-top:1px solid #d0d7de;margin:20px 0}}
  .qr{{text-align:center;margin-top:24px;color:#57606a;font-size:12px}}
  .qr img{{width:160px;height:160px;border:1px solid #d0d7de;border-radius:4px;padding:8px;background:#fff}}
  .footer{{margin-top:24px;padding-top:12px;border-top:1px solid #d0d7de;font-size:11px;color:#57606a;text-align:center}}
  .appendix{{background:#f6f8fa;border:1px solid #d0d7de;border-radius:6px;padding:12px;margin-top:16px;font-size:12px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap;word-break:break-word}}
  .thankyou{{background:#ddf4ff;border:1px solid #54aeff;border-radius:6px;padding:12px;margin-top:16px;text-align:center;color:#0969da}}
  a{{color:#0969da;text-decoration:none}}
  a:hover{{text-decoration:underline}}
</style></head>
<body>
<div class="receipt">
  <h1>PHAROS RECEIPT</h1>
  <div class="sub">
    <span>{r['network']['displayName']} (chain {r['network']['chainId']})</span>
    <span class="{status_class}">{r['status']}</span>
  </div>

  <table>
    <tr><td class="k">Block</td><td class="vr">{fmt_int(r['block'])}</td></tr>
    <tr><td class="k">Timestamp</td><td class="vr">{r['block_ts_iso']}</td></tr>
    <tr><td class="k">Tx hash</td><td class="v"><code>{r['tx_hash']}</code></td></tr>
    <tr><td class="k">From</td><td class="v"><code>{r['from']}</code></td></tr>
    <tr><td class="k">To</td><td class="v"><code>{r['to']}</code></td></tr>
    <tr><td class="k">Value</td><td class="vr"><strong>{r['value_human']}</strong></td></tr>
    <tr><td class="k">Gas used</td><td class="vr">{fmt_int(r['gas_used'])}</td></tr>
    <tr><td class="k">Gas price</td><td class="vr">{r['gas_price_gwei']} gwei</td></tr>
    <tr><td class="k">Tx fee</td><td class="vr">{r['fee_human']}</td></tr>
    <tr><td class="k">Nonce</td><td class="vr">{r['nonce']}</td></tr>
    <tr><td class="k">Input</td><td class="v"><code>{r['input_selector']}</code></td></tr>
  </table>

  <hr>

  <table>
    <tr><td class="k">USD value (at execution)</td><td class="vr"><strong>{r['usd_value']}</strong></td></tr>
    <tr><td class="k">USD fee (at execution)</td><td class="vr">{r['usd_fee']}</td></tr>
    <tr><td class="k">Price source</td><td class="vr"><em>{r['usd_price_source']}</em></td></tr>
  </table>

  {qr_block}
"""
    if template == "donation":
        out += f'\n  <div class="thankyou">Thank you for your contribution.<br>Receipt ID: <code>{r["tx_hash"]}</code> — keep this hash as proof of payment.</div>\n'
    if template == "audit":
        out += f'\n  <div class="appendix">{json.dumps({k:r[k] for k in ("tx_hash","status","block","from","to","value_human","gas_used","fee_human","nonce","input_selector","explorer_link")}, indent=2)}</div>\n'
    if template == "tax":
        out += f"""
  <div class="appendix">TAX COST-BASIS APPENDIX
Asset: {r['network']['nativeToken']}
Quantity: {r['value_human']}
Date acquired: {r['block_ts_iso_safe']}
Date sold: —
Proceeds (USD @ t/x): {r['usd_value']}
Cost basis (USD @ t/x): depends on the user's acquisition cost (off-chain)
Gain / loss: n/a
8949 hints: Part I, box 1a — reportable if sold/exchanged.</div>
"""
    out += f"""
  <div class="footer">
    Explorer: <a href="{r['explorer_link']}" target="_blank">{r['explorer_link']}</a><br>
    Generated: {r['generated_at']} · Generator: receipton-1.0.0 (python)
  </div>
</div>
</body></html>
"""
    return out


# -------- CLI --------
def main():
    p = argparse.ArgumentParser(description="Generate a Pharos on-chain receipt for any tx hash.")
    p.add_argument("tx", help="transaction hash (0x...)")
    p.add_argument("--network", default="testnet", choices=["mainnet", "testnet", "atlantic", "pacific"])
    p.add_argument("--format", default="md", choices=["md", "txt", "html"])
    p.add_argument("--template", default="invoice", choices=["invoice", "donation", "audit", "tax"])
    args = p.parse_args()

    networks = load_networks()
    net = pick_network(networks, args.network)

    r = analyze(args.tx, net)

    # optional QR
    qr_png_b64 = None
    if args.format == "html":
        try:
            import qrcode
            import base64
            from io import BytesIO
            img = qrcode.make(r["tx_hash"])
            buf = BytesIO()
            img.save(buf, format="PNG")
            qr_png_b64 = base64.b64encode(buf.getvalue()).decode()
        except ImportError:
            pass

    if args.format == "md":
        print(render_md(r, args.template))
    elif args.format == "txt":
        print(render_txt(r, args.template))
    elif args.format == "html":
        print(render_html(r, args.template, qr_png_b64))


if __name__ == "__main__":
    main()

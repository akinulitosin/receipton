# Price feeds

The receipt generator estimates the USD value at execution time by fetching a historical price for the native token. This document explains which feeds we use, why, and how the script falls back when a feed is unreachable.

## Native token identifiers

| Network | Native | CoinGecko ID |
|---|---|---|
| Atlantic Testnet | PHRS | `pharos-atlantic` (placeholder — adjust if CoinGecko lists a different slug) |
| Pacific Mainnet | PROS | `pharos-network` |

Source: `references/networks.json` → `coingeckoId` field.

## Primary feed: CoinGecko

```
GET https://api.coingecko.com/api/v3/coins/{coingeckoId}/history?date=DD-MM-YYYY
```

Returns a `market_data.current_price.usd` field for the date the tx was mined.

**Free tier:** ~10-30 calls/min. No API key needed for the free endpoint. Rate-limited but the script caches per-day, so a single block of receipts only uses one call per unique day.

**Caveat:** CoinGecko may not list very small tokens. The `coingeckoId` in `networks.json` is a placeholder; if the actual slug differs, edit the JSON.

## Fallback chain

If the CoinGecko request fails, the script falls back in this order:

1. **CoinGecko simple price** (current) — used as a last-resort estimate with a `(estimated at current price, not historical)` annotation
2. **Hardcoded fallback** — `references/networks.json` can include a `fallbackUsdPrice` field that the script uses if all live feeds fail
3. **`null` / "unavailable"** — the receipt still renders, but with `USD value: unavailable` instead of a dollar amount

The receipt always renders, even if the price feed is dead. The USD column is optional; the on-chain values are always present.

## Privacy

The price lookup is a public read against CoinGecko's public API. The script does not send the user's wallet address, tx hash, or any other identifying info to CoinGecko. Only the date is sent (as a URL parameter).

## Implementation

`scripts/receipt.py` is the only place that calls the price feed. It:

1. Reads the block's `timestamp` from the RPC
2. Converts to a `YYYY-MM-DD` date
3. Caches the per-day price in memory (so batch-printing N receipts for the same day = 1 API call)
4. Returns `(usd_price, source)` where `source` is `"coingecko-history"` or `"fallback-current"` or `"fallback-hardcoded"` or `"unavailable"`

`scripts/receipt.sh` does NOT call CoinGecko — it's the zero-dep version. The USD column in the bash output will always show `unavailable`. Use the Python script when you need a USD estimate.

## Rate-limit recovery

If you hit CoinGecko's free-tier rate limit, you'll get a 429 response. The script catches it and:

- Logs the error to stderr
- Falls back to the next strategy
- Marks the USD field as `unavailable` in the output

Wait 60 seconds and retry. For batch jobs, throttle the script to 1 receipt per 5 seconds.

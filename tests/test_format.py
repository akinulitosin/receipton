"""
Unit tests for receipton — pure format tests, no network required.
Run with: python3 -m pytest tests/  (or: python3 tests/test_format.py)
"""

import re
import sys
import os

# Add parent dir to path so we can import scripts/
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import receipt  # noqa: E402


SAMPLE = {
    "tx_hash": "0xabc1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcd",
    "network": {
        "name": "mainnet", "displayName": "Pharos Pacific Ocean Mainnet",
        "chainId": 1672, "nativeToken": "PROS",
        "rpcUrl": "https://rpc.pharos.xyz", "explorerUrl": "https://www.pharosscan.xyz/",
    },
    "status": "SUCCESS",
    "block": 8527764, "block_ts_iso": "2026-04-15 14:23:11 UTC",
    "block_ts_iso_safe": "2026-04-15T14:23:11+00:00",
    "from": "0x67992af9a87f2d6a3062c333d8a06abbe3929438",
    "to": "0x7a31dd32a880827477ab2bbeff47db188c896815",
    "value_wei": 105000000000000000000, "value_native": 105.0,
    "value_human": "105.0000 PROS",
    "gas_used": 207347, "gas_price_wei": 10000000000, "gas_price_gwei": "10.00",
    "fee_wei": 2073470000000000, "fee_native": 0.00207347,
    "fee_human": "0.002073 PROS",
    "nonce": 359, "input_selector": "0xccf50a51",
    "usd_price": 0.123, "usd_price_source": "coingecko-history",
    "usd_value": "$12.92", "usd_fee": "$0.000255",
    "explorer_link": "https://www.pharosscan.xyz/tx/0xabc...",
    "generated_at": "2026-06-06 16:00:00 UTC",
}


def test_md_invoice_has_all_fields():
    out = receipt.render_md(SAMPLE, "invoice")
    for field in ["Pharos Pacific Ocean Mainnet", "chain 1672", "SUCCESS", "8,527,764",
                  "0x67992af9", "0x7a31dd32", "105.0000 PROS", "0.002073 PROS",
                  "0xccf50a51", "https://www.pharosscan.xyz", "$12.92"]:
        assert field in out, f"MD invoice missing {field!r}"


def test_md_donation_appends_thankyou():
    out = receipt.render_md(SAMPLE, "donation")
    assert "Thank you" in out
    assert SAMPLE["tx_hash"] in out


def test_md_audit_appends_json():
    out = receipt.render_md(SAMPLE, "audit")
    assert "```json" in out
    assert '"tx_hash"' in out
    assert SAMPLE["tx_hash"] in out


def test_md_tax_appends_8949_hint():
    out = receipt.render_md(SAMPLE, "tax")
    assert "8949" in out
    assert "Cost basis" in out


def test_txt_invoice_has_all_fields():
    out = receipt.render_txt(SAMPLE, "invoice")
    for field in ["PHAROS RECEIPT", "Pharos Pacific Ocean Mainnet", "chain 1672",
                  "8,527,764", "SUCCESS", "0x67992af9", "105.0000 PROS",
                  "0.002073 PROS", "https://www.pharosscan.xyz"]:
        assert field in out, f"TXT invoice missing {field!r}"


def test_html_invoice_has_table_and_styles():
    out = receipt.render_html(SAMPLE, "invoice", qr_png_b64=None)
    assert "<!doctype html>" in out
    assert "Pharos Pacific Ocean Mainnet" in out
    assert "<code>" in out
    assert "8,527,764" in out
    assert "PHAROS RECEIPT" in out
    # QR placeholder should be shown when no png is provided
    assert "QR generation requires" in out


def test_html_invoice_inlines_qr_when_provided():
    out = receipt.render_html(SAMPLE, "invoice", qr_png_b64="iVBORw0KGgo=")
    assert "data:image/png;base64,iVBORw0KGgo=" in out


def test_html_failed_status_uses_fail_class():
    bad = {**SAMPLE, "status": "FAILED"}
    out = receipt.render_html(bad, "invoice")
    assert "status-fail" in out
    assert "FAILED" in out


def test_all_templates_render_without_exception():
    for fmt, fn in [("md", receipt.render_md), ("txt", receipt.render_txt), ("html", receipt.render_html)]:
        for tpl in ["invoice", "donation", "audit", "tax"]:
            out = fn(SAMPLE, tpl, qr_png_b64=None) if fmt == "html" else fn(SAMPLE, tpl)
            assert isinstance(out, str) and len(out) > 0


if __name__ == "__main__":
    tests = [v for k, v in globals().items() if k.startswith("test_") and callable(v)]
    failed = 0
    for t in tests:
        try:
            t()
            print(f"  ✓ {t.__name__}")
        except AssertionError as e:
            print(f"  ✗ {t.__name__}: {e}")
            failed += 1
    print()
    if failed:
        print(f"{failed} test(s) failed")
        sys.exit(1)
    else:
        print(f"{len(tests)} test(s) passed")

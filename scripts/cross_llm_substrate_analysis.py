#!/usr/bin/env python3
"""
M613 chapter 一百七十六 §176.17 — Cross-LLM substrate optimization
analyzer. Joins Mac Gemma JSONL + iPhone AFM JSONL by
(stride, mutationSeed, iter) and produces:

1. Substrate cross-platform determinism (Mac vs iPhone same permit?)
2. Cross-LLM body comparison (AFM vs Gemma length / refusal pattern)
3. Anomaly clusters (where LLMs agree but substrate doesn't)
4. Per-tone fingerprint validation (chapter 175 angry → 100% block)
5. Substrate optimization candidate list

Usage:
  python3 cross_llm_substrate_analysis.py \
      --iphone /tmp/iphone-afm-bench-snapshot \
      --mac /tmp/gemma-cross-8h \
      --report /tmp/cross-llm-report.md
"""

import argparse
import json
import os
import sys
from collections import Counter, defaultdict
from glob import glob


def load_jsonl_dir(dir_path):
    """Load all *.jsonl files in dir as list of dicts."""
    rows = []
    if not os.path.isdir(dir_path):
        return rows
    for path in sorted(glob(os.path.join(dir_path, "*.jsonl"))):
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return rows


def make_join_key(row):
    """Compute join key: (stride, mutationSeed, iteration)."""
    return (
        row.get("stride"),
        row.get("mutationSeed"),
        row.get("iteration"),
    )


def signature_summary(row):
    """Extract (tone, domain, stake) tuple for fingerprint analysis."""
    sig = row.get("signature") or {
        "tone": row.get("tone"),
        "domain": row.get("domain"),
        "stake": row.get("stake"),
    }
    if isinstance(sig, dict):
        return (
            sig.get("tone"),
            sig.get("domain"),
            sig.get("stake"),
        )
    return (None, None, None)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--iphone", required=True)
    parser.add_argument("--mac", required=True)
    parser.add_argument("--report", default="/tmp/cross-llm-report.md")
    args = parser.parse_args()

    iphone_rows = load_jsonl_dir(args.iphone)
    mac_rows = load_jsonl_dir(args.mac)
    print(f"iPhone rows: {len(iphone_rows)}")
    print(f"Mac rows:    {len(mac_rows)}")

    iphone_by_key = {make_join_key(r): r for r in iphone_rows}
    mac_by_key = {make_join_key(r): r for r in mac_rows}
    common_keys = set(iphone_by_key.keys()) & set(mac_by_key.keys())
    print(f"Joined keys: {len(common_keys)}")

    if not common_keys:
        print("⚠️  No overlap. Check that both runs use same defaults.")
        sys.exit(0)

    # Metric 1: Substrate cross-platform determinism
    determinism_match = 0
    determinism_diff = 0
    perm_disagreements = []
    for k in common_keys:
        ip = iphone_by_key[k]
        mc = mac_by_key[k]
        ip_perm = ip.get("permitMode")
        mc_perm = mc.get("substratePermit")
        if ip_perm == mc_perm:
            determinism_match += 1
        else:
            determinism_diff += 1
            if len(perm_disagreements) < 5:
                perm_disagreements.append((k, ip_perm, mc_perm))

    # Metric 2: Cross-LLM body length compare
    afm_lens = []
    gemma_lens = []
    afm_errors = 0
    gemma_errors = 0
    for k in common_keys:
        ip = iphone_by_key[k]
        mc = mac_by_key[k]
        if ip.get("afmStatus") == "ok":
            afm_lens.append(ip.get("afmBodyLength", 0))
        elif "error" in ip.get("afmStatus", ""):
            afm_errors += 1
        if mc.get("status") == "ok":
            gemma_lens.append(mc.get("bodyLength", 0))
        else:
            gemma_errors += 1

    def stats(arr):
        if not arr:
            return (0, 0, 0, 0)
        n = len(arr)
        avg = sum(arr) / n
        srt = sorted(arr)
        return (n, srt[0], avg, srt[-1])

    afm_stat = stats(afm_lens)
    gemma_stat = stats(gemma_lens)

    # Metric 3: Per-tone fingerprint (validate chapter 175 angry → block)
    tone_perm = defaultdict(Counter)
    for k in common_keys:
        sig = signature_summary(iphone_by_key[k])
        tone = sig[0]
        ip_perm = iphone_by_key[k].get("permitMode", "?")
        if tone:
            tone_perm[tone][ip_perm] += 1

    # Metric 4: Anomaly cluster — LLM body present but substrate refused
    # Heuristic: refused = permitMode in {block} (delay still answered);
    # body present = afmStatus=ok with body length >= 100
    anomalies = []
    for k in common_keys:
        ip = iphone_by_key[k]
        if (
            ip.get("permitMode") == "block"
            and ip.get("afmStatus") == "ok"
            and ip.get("afmBodyLength", 0) >= 100
        ):
            anomalies.append(k)

    # Metric 5: Cross-LLM agreement signal
    # Both LLMs produced output of comparable length → "answered"
    # Both errored / refused → "refused"
    both_answered = 0
    both_refused = 0
    afm_only_answered = 0
    gemma_only_answered = 0
    for k in common_keys:
        ip = iphone_by_key[k]
        mc = mac_by_key[k]
        afm_ok = ip.get("afmStatus") == "ok" and ip.get("afmBodyLength", 0) >= 50
        gem_ok = mc.get("status") == "ok" and mc.get("bodyLength", 0) >= 50
        if afm_ok and gem_ok:
            both_answered += 1
        elif (not afm_ok) and (not gem_ok):
            both_refused += 1
        elif afm_ok:
            afm_only_answered += 1
        elif gem_ok:
            gemma_only_answered += 1

    # Build report
    lines = []
    lines.append("# Cross-LLM Substrate Optimization Report")
    lines.append("")
    lines.append(
        "Generated by `cross_llm_substrate_analysis.py` "
        f"(joined {len(common_keys)} prompts).")
    lines.append("")
    lines.append("## Data sources")
    lines.append(f"- iPhone AFM bench: `{args.iphone}` ({len(iphone_rows)} rows)")
    lines.append(f"- Mac Gemma+substrate: `{args.mac}` ({len(mac_rows)} rows)")
    lines.append(f"- Joined on (stride, mutationSeed, iteration): {len(common_keys)} prompts")
    lines.append("")
    lines.append("## 1. Substrate cross-platform determinism")
    lines.append("")
    lines.append("Substrate routes the SAME prompt with the SAME signature; ")
    lines.append("Mac and iPhone should produce identical permit decisions ")
    lines.append("(determinism invariant).")
    lines.append("")
    total = determinism_match + determinism_diff
    rate = (determinism_match / total * 100) if total else 0
    lines.append(f"- Match: {determinism_match}/{total} ({rate:.1f}%)")
    lines.append(f"- Diff:  {determinism_diff}/{total}")
    if perm_disagreements:
        lines.append("- Sample disagreements:")
        for k, ip_p, mc_p in perm_disagreements[:5]:
            lines.append(f"  - key={k} iphone={ip_p} mac={mc_p}")
    lines.append("")
    lines.append("## 2. Cross-LLM body length comparison")
    lines.append("")
    lines.append(
        f"- AFM (iPhone): n={afm_stat[0]} min={afm_stat[1]} "
        f"avg={afm_stat[2]:.0f} max={afm_stat[3]}")
    lines.append(
        f"- Gemma (Mac): n={gemma_stat[0]} min={gemma_stat[1]} "
        f"avg={gemma_stat[2]:.0f} max={gemma_stat[3]}")
    lines.append(f"- AFM errors: {afm_errors}")
    lines.append(f"- Gemma errors: {gemma_errors}")
    if afm_stat[2] and gemma_stat[2]:
        ratio = afm_stat[2] / gemma_stat[2]
        lines.append(
            f"- Length ratio AFM/Gemma: {ratio:.2f} "
            f"({'AFM verbose' if ratio > 1.2 else 'Gemma verbose' if ratio < 0.83 else 'comparable'})")
    lines.append("")
    lines.append("## 3. Per-tone permit fingerprint (chapter 175 validation)")
    lines.append("")
    lines.append("| Tone | Block | Delay | Other | Total | Block% |")
    lines.append("|---|---|---|---|---|---|")
    for tone in sorted(tone_perm.keys() or []):
        if not tone:
            continue
        c = tone_perm[tone]
        block = c.get("block", 0)
        delay = c.get("delay", 0)
        total_t = sum(c.values())
        other = total_t - block - delay
        rate_b = (block / total_t * 100) if total_t else 0
        lines.append(f"| {tone} | {block} | {delay} | {other} | {total_t} | {rate_b:.1f}% |")
    lines.append("")
    lines.append(
        "Compare to chapter 175: `angry` was 100% block / others were "
        "~57/43 delay/block. If `angry → 100% block` validates here too, "
        "doctrine fingerprint is robust.")
    lines.append("")
    lines.append("## 4. Anomaly clusters")
    lines.append("")
    lines.append(
        f"Substrate routed `block` BUT AFM produced ≥100 char body "
        f"(potential over-blocking): **{len(anomalies)}** prompts")
    lines.append("")
    lines.append("These are candidates for substrate threshold tuning — ")
    lines.append("either substrate is too restrictive OR AFM is permitting ")
    lines.append("content substrate intends to block.")
    lines.append("")
    lines.append("## 5. Cross-LLM agreement matrix")
    lines.append("")
    lines.append("| | AFM ok | AFM err/short |")
    lines.append("|---|---|---|")
    lines.append(f"| Gemma ok | both answered: {both_answered} | gemma-only: {gemma_only_answered} |")
    lines.append(f"| Gemma err/short | afm-only: {afm_only_answered} | both refused: {both_refused} |")
    lines.append("")
    lines.append("**Both-answered + Both-refused = high LLM consensus.**")
    lines.append("**afm-only / gemma-only = LLM disagreement (substrate could lean to consensus).**")
    lines.append("")
    lines.append("## Substrate optimization candidates (heuristic)")
    lines.append("")
    consensus_total = both_answered + both_refused
    disagree_total = afm_only_answered + gemma_only_answered
    if consensus_total + disagree_total > 0:
        consensus_rate = consensus_total / (consensus_total + disagree_total) * 100
        lines.append(f"- LLM consensus rate: {consensus_rate:.1f}%")
    lines.append(
        f"- Anomalies (substrate block + AFM produced body): {len(anomalies)}"
    )
    if total:
        lines.append(
            f"- Substrate determinism (Mac vs iPhone): {rate:.1f}% — "
            f"{'STRONG' if rate >= 99 else 'CHECK' if rate >= 95 else 'WEAK'}")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("Doctrine pin: this report is empirical evidence + ")
    lines.append("candidate suggestions only. Real substrate doctrine ")
    lines.append("changes still require chapter-level walkback + typed-pin ")
    lines.append("tests. Auto-tuning out of scope.")

    with open(args.report, "w") as f:
        f.write("\n".join(lines))
    print(f"\nReport: {args.report}")
    print(f"Determinism: {rate:.1f}% / Anomalies: {len(anomalies)} / "
          f"LLM consensus: {consensus_rate:.1f}%" if consensus_total + disagree_total else "")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""qinao_device — flip the device-bound perf metrics (#65-72) from scaffold to COMPUTED.

Parses a pulled BASEnduranceAppRunner log (device run; grep-able 📊 lines) and writes
/tmp/qinao_values_<tag>.json entries in the harness convention (build_verdict.py reads them).

Metrics produced (registry keys):
  decode_tok_s (#65)        ← 📊 ch1025 mlx-decode decode_tps (mean over iterations)
  ttft_ms (#66, proxy)      ← 📊 ch1025 mlx-decode prefill_ms (mean; true TTFT = prefill + 1st decode step)
  prefill_tok_s (#67)       ← 📊 ch1025 mlx-decode prefill_tps (mean)
  peak_ram_mb (#68)         ← FINAL memory ... peak= / 📊 mlx-mem peak (max seen)
  thermal_drift_pct (#71)   ← first-quartile vs last-quartile iter_ms drift (the cold-vs-warm discipline)
  latency_p50_ms / latency_p95_ms (#72) ← FINAL p50/p99_iter_ms (p99 stored as p95 slot pessimistically —
                                           the runner emits p99; a pessimistic p95 keeps the gate honest)
SYSTEM-EFFICIENCY campaign additions (Docs/SYSTEM_EFFICIENCY_CAMPAIGN_2026-07.md, T1/T2):
  llm_invocation_rate       ← FINAL mlx_total_inferences / iters (reads 1.0 until a routing gate exists)
  turn_p50_ms / turn_p95_ms ← FINAL p50/p99_iter_ms (agent-turn latency; iter = full brain turn)
  substrate_pct_mean        ← 📊 turn-breakdown substrate_pct (mean; the substrate-vs-LLM split)

Usage:
  python3 qinao_device.py <endurance_log> --tag <tag> [--merge]
  python3 qinao_device.py --selftest
--merge: update an existing /tmp/qinao_values_<tag>.json in place (device values join eval values).
"""
import json
import re
import statistics
import sys


def parse(text: str) -> dict:
    out: dict = {}
    dec = [float(m) for m in re.findall(r"mlx-decode .*?decode_tps=([\d.]+)", text)]
    pre_tps = [float(m) for m in re.findall(r"mlx-decode .*?prefill_tps=([\d.]+)", text)]
    pre_ms = [float(m) for m in re.findall(r"mlx-decode .*?prefill_ms=([\d.]+)", text)]
    if dec:
        out["decode_tok_s"] = round(statistics.mean(dec), 1)
    if pre_tps:
        out["prefill_tok_s"] = round(statistics.mean(pre_tps), 1)
    if pre_ms:
        out["ttft_ms"] = round(statistics.mean(pre_ms), 1)

    peaks = [float(m) for m in re.findall(r"mlx-mem .*?peak_mb=([\d.]+)", text)]
    peaks += [float(m) for m in re.findall(r"rss_mb=[\d.]+→([\d.]+)", text)]
    fin_peak = re.search(r"FINAL .*?peak[_= ]([\d.]+)", text)
    if fin_peak:
        peaks.append(float(fin_peak.group(1)))
    if peaks:
        out["peak_ram_mb"] = round(max(peaks), 0)

    iters_ms = [float(m) for m in re.findall(r"scorecard iter=\d+ iter_ms=([\d.]+)", text)]
    if len(iters_ms) >= 8:
        q = max(1, len(iters_ms) // 4)
        first, last = statistics.mean(iters_ms[:q]), statistics.mean(iters_ms[-q:])
        out["thermal_drift_pct"] = round((last - first) / first * 100, 1)

    p50 = re.search(r"p50_iter_ms=([\d.]+)", text)
    p99 = re.search(r"p99_iter_ms=([\d.]+)", text)
    if p50:
        out["turn_p50_ms"] = float(p50.group(1))
        out["latency_p50_ms"] = float(p50.group(1))
    if p99:
        out["turn_p95_ms"] = float(p99.group(1))          # pessimistic: runner emits p99
        out["latency_p95_ms"] = float(p99.group(1))
    elif iters_ms:                                        # FINAL absent (early stop) → compute from series
        srt = sorted(iters_ms)
        out["turn_p50_ms"] = srt[len(srt) // 2]
        out["turn_p95_ms"] = srt[min(len(srt) - 1, int(len(srt) * 0.95))]
        out.setdefault("latency_p50_ms", out["turn_p50_ms"])
        out.setdefault("latency_p95_ms", out["turn_p95_ms"])

    inf = re.search(r"mlx_total_inferences=(\d+)", text)
    itr = re.search(r"\biters=(\d+)", text) or re.search(r"total_iters=(\d+)", text)
    if inf and itr and int(itr.group(1)) > 0:
        out["llm_invocation_rate"] = round(int(inf.group(1)) / int(itr.group(1)), 3)
    else:                                                 # FINAL absent → engagement rate from turn-breakdown
        tb = re.findall(r"turn-breakdown iter=\d+ .*?mlx_ms=([\d.]+)", text)
        if tb:
            engaged = sum(1 for m in tb if float(m) > 0)
            out["llm_invocation_rate"] = round(engaged / len(tb), 3)
    brain = [float(m) for m in re.findall(r"turn-breakdown .*?brain_ms=([\d.]+)", text)]
    if brain:
        out["substrate_brain_ms_mean"] = round(sum(brain) / len(brain), 1)

    sub = [float(m) for m in re.findall(r"turn-breakdown .*?substrate_pct=([\d.]+)", text)]
    if sub:
        out["substrate_pct_mean"] = round(statistics.mean(sub), 1)

    # substrate #77 — per-stage p95 from 📊 layer-latency lines (stage=ms pairs).
    stage_samples: dict = {}
    for line in re.findall(r"layer-latency iter=\d+ ([^\n]+)", text):
        for k, v in re.findall(r"(\w+)=([\d.]+)", line):
            stage_samples.setdefault(k, []).append(float(v))
    for k, vals in stage_samples.items():
        if len(vals) >= 4:
            srt = sorted(vals)
            out[f"layer_{k}_p95_ms"] = round(srt[min(len(srt) - 1, int(len(srt) * 0.95))], 1)
    return out


# Real 2026-07-04 endurance-runner line formats (p0_baseline run).
SELFTEST_LOG = """
📊 ch1025 mlx-decode prefill_ms=412.0 decode_ms=3120.0 prompt_tokens=58 gen_tokens=64 prefill_tps=140.8 decode_tps=20.5
📊 ch1025 mlx-mem iter=1 active_mb=2512.6 cache_mb=402.0 peak_mb=2651.8
📊 ch1025 scorecard iter=1 iter_ms=4980 est_tokens=210 thermal=nominal→nominal rss_mb=2937.4→2983.1 avail_mb=3330→3018
📊 ch1025 turn-breakdown iter=1 iter_ms=4980 brain_ms=27 mlx_ms=4953 other_ms=9 substrate_pct=0.5 mlx_pct=99.3
📊 ch1025 mlx-decode prefill_ms=395.5 decode_ms=3260.0 prompt_tokens=61 gen_tokens=64 prefill_tps=154.2 decode_tps=19.6
📊 ch1025 scorecard iter=2 iter_ms=5100 est_tokens=150 thermal=nominal→fair rss_mb=2950.0→2960.0 avail_mb=3000→2950
📊 ch1025 scorecard iter=3 iter_ms=5150 est_tokens=150 thermal=fair→fair rss_mb=2950.0→2961.0 avail_mb=2950→2920
📊 ch1025 scorecard iter=4 iter_ms=5610 est_tokens=150 thermal=fair→serious rss_mb=2950.0→2962.0 avail_mb=2920→2900
📊 ch1025 scorecard iter=5 iter_ms=6420 est_tokens=150 thermal=serious→serious rss_mb=2950.0→2963.0 avail_mb=2900→2880
📊 ch1025 scorecard iter=6 iter_ms=6390 est_tokens=150 thermal=serious→serious rss_mb=2950.0→2963.0 avail_mb=2880→2870
📊 ch1025 scorecard iter=7 iter_ms=6455 est_tokens=150 thermal=serious→serious rss_mb=2950.0→2963.0 avail_mb=2870→2860
📊 ch1025 scorecard iter=8 iter_ms=6470 est_tokens=150 thermal=serious→serious rss_mb=2950.0→2963.0 avail_mb=2860→2850
FINAL avg_iter_ms=5820 p50_iter_ms=5610 p99_iter_ms=6470 mlx_total_inferences=8 iters=8 memory endpoint=3080 max=3082 peak=3101 thermal_trajectory=nominal→serious
"""


def main() -> None:
    if "--selftest" in sys.argv:
        vals = parse(SELFTEST_LOG)
        expect = {
            "decode_tok_s": 20.1, "prefill_tok_s": 147.5, "ttft_ms": 403.8,
            "peak_ram_mb": 3101, "thermal_drift_pct": 28.2,
            "turn_p50_ms": 5610.0, "turn_p95_ms": 6470.0,
            "latency_p50_ms": 5610.0, "latency_p95_ms": 6470.0,
            "llm_invocation_rate": 1.0, "substrate_pct_mean": 0.5,
        }
        ok = all(abs(vals.get(k, -1e9) - v) < 0.51 for k, v in expect.items())
        print(json.dumps(vals, indent=2))
        print("SELFTEST", "PASS" if ok else f"FAIL (expected ≈ {expect})")
        sys.exit(0 if ok else 1)

    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    log_path = sys.argv[1]
    tag = sys.argv[sys.argv.index("--tag") + 1] if "--tag" in sys.argv else "device"
    text = open(log_path, errors="replace").read()
    vals = parse(text)
    if not vals:
        print("no 📊/FINAL lines recognized — is this an endurance-runner log?")
        sys.exit(1)
    out_path = f"/tmp/qinao_values_{tag}.json"
    merged = {}
    if "--merge" in sys.argv:
        try:
            merged = json.load(open(out_path))
        except FileNotFoundError:
            pass
    merged.update(vals)
    json.dump(merged, open(out_path, "w"), indent=2)
    print(f"wrote {len(vals)} device metrics → {out_path}")
    for k, v in vals.items():
        print(f"  {k} = {v}")


if __name__ == "__main__":
    main()

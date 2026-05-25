#!/usr/bin/env python3
# chapter 九百五十二.7 / M3465.7
#
# Parse /tmp/ch952-10hr/iter-NNN.log files (226 of them after the
# 10hr run) and detect performance drift over time。 The 10hr run's
# "0 perf regression" claim in the ch 952.6 RESULTS commit was based
# on iter-1 vs iter-226 snapshot comparison — but a gradual climb of
# 10% per hour would be missed by snapshot comparison。 This script
# does the actual linear-regression。
#
# Usage:
#   python3 scripts/analyze-ch952-trend.py [/tmp/ch952-10hr]
#
# Output:
#   - Per-metric series (iter# → p99 value)
#   - Linear regression slope: % change per hour
#   - Flag any metric with > 10% drift per hour as「potential drift」
#   - Verdict per metric:STABLE / DRIFT / NOISY
#
# Greppable scorecards parsed:
#   📊 ch952.4-scorecard | suite=X op=Y p50=... p99=... ceiling=... margin=...× n=...
#   📊 ch952.7-memory | label=L rss=X.YMB
#   ch952-bench X: p50=...ms p95=...ms p99=...ms ceiling=...ms n=...
#   ch952.1-real-mlx: load_time=...ms
#   ch952.1-real-mlx: infer_time=...ms tokens=N tok/s=X.YY

import os
import re
import sys
import glob
from collections import defaultdict

LOG_DIR = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ch952-10hr"

# ---- Patterns ---------------------------------------------------------

# 📊 ch952.4-scorecard | suite=L8 op=AtomLifecycle.append
# p50=0.073ms p99=0.311ms ceiling=5.0ms margin=16.1× n=200
SCORECARD_RE = re.compile(
    r"ch952\.4-scorecard \| suite=(\S+) op=(\S+) "
    r"p50=([\d.]+)(\w+) p99=([\d.]+)\w+ "
    r"ceiling=([\d.]+)\w+ margin=([\d.]+)× n=(\d+)"
)

# ch952-bench L8.append: p50=0.04ms p95=0.05ms p99=0.07ms
# ceiling=50.0ms n=1000
BENCH_RE = re.compile(
    r"ch952-bench (\S+?): p50=([\d.]+)ms "
    r"p95=([\d.]+)ms p99=([\d.]+)ms "
    r"ceiling=([\d.]+)ms n=(\d+)"
)

# ch952.1-real-mlx: load_time=2982.937167ms
LOAD_RE = re.compile(r"ch952\.1-real-mlx: load_time=([\d.]+)ms")

# ch952.1-real-mlx: infer_time=810.389792ms tokens=45 tok/s=55.53
INFER_RE = re.compile(
    r"ch952\.1-real-mlx: infer_time=([\d.]+)ms "
    r"tokens=(\d+) tok/s=([\d.]+)"
)

# ch952.1-real-mlx-bench: n=5 p50=217ms p99=5907ms avg_tok/s=19.60
MLX_BENCH_RE = re.compile(
    r"ch952\.1-real-mlx-bench: n=(\d+) "
    r"p50=([\d.]+)ms p99=([\d.]+)ms avg_tok/s=([\d.]+)"
)

# ch952.1-real-mlx-stream: first_token=173.5295ms
# last_token=390.003958ms chunks=10
STREAM_RE = re.compile(
    r"ch952\.1-real-mlx-stream: first_token=([\d.]+)ms "
    r"last_token=([\d.]+)ms chunks=(\d+)"
)

# 🧠 ch952.7-memory | label=L8.append.after rss=125.3MB
MEM_RE = re.compile(
    r"ch952\.7-memory \| label=(\S+) rss=([\d.]+)MB"
)


# ---- Parser -----------------------------------------------------------

def parse_iter_log(path):
    """Returns dict: {metric_key → first_value} for one iter file。"""
    out = {}
    try:
        with open(path, encoding="utf-8", errors="ignore") as f:
            for line in f:
                m = SCORECARD_RE.search(line)
                if m:
                    suite, op, p50, _, p99, ceiling, margin, n = m.groups()
                    key = f"scorecard:{suite}.{op}"
                    out.setdefault(f"{key}.p50", float(p50))
                    out.setdefault(f"{key}.p99", float(p99))
                    out.setdefault(f"{key}.margin", float(margin))
                    continue
                m = BENCH_RE.search(line)
                if m:
                    op, p50, p95, p99, ceiling, n = m.groups()
                    out.setdefault(f"bench:{op}.p50", float(p50))
                    out.setdefault(f"bench:{op}.p99", float(p99))
                    continue
                m = LOAD_RE.search(line)
                if m:
                    out.setdefault("mlx.load_ms", float(m.group(1)))
                    continue
                m = INFER_RE.search(line)
                if m:
                    t, tok, tps = m.groups()
                    out.setdefault("mlx.infer_ms", float(t))
                    out.setdefault("mlx.tokens", int(tok))
                    out.setdefault("mlx.tok_per_sec", float(tps))
                    continue
                m = MLX_BENCH_RE.search(line)
                if m:
                    n, p50, p99, tps = m.groups()
                    out.setdefault("mlx-bench.p50", float(p50))
                    out.setdefault("mlx-bench.p99", float(p99))
                    out.setdefault(
                        "mlx-bench.avg_tok_per_sec", float(tps))
                    continue
                m = STREAM_RE.search(line)
                if m:
                    first, last, chunks = m.groups()
                    out.setdefault(
                        "mlx-stream.first_token", float(first))
                    out.setdefault(
                        "mlx-stream.last_token", float(last))
                    continue
                m = MEM_RE.search(line)
                if m:
                    label, mb = m.groups()
                    out.setdefault(f"memory:{label}.MB", float(mb))
    except IOError as e:
        return {"_error": str(e)}
    return out


# ---- Linear regression -----------------------------------------------

def slope(xs, ys):
    """Simple OLS slope。 Returns (slope, intercept)。"""
    n = len(xs)
    if n < 2:
        return 0.0, ys[0] if ys else 0.0
    mean_x = sum(xs) / n
    mean_y = sum(ys) / n
    num = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys))
    den = sum((x - mean_x) ** 2 for x in xs)
    if den == 0:
        return 0.0, mean_y
    m = num / den
    b = mean_y - m * mean_x
    return m, b


def coefficient_of_variation(ys):
    """CoV = std-dev / mean,as percent。"""
    n = len(ys)
    if n < 2:
        return 0.0
    mean = sum(ys) / n
    if mean == 0:
        return 0.0
    var = sum((y - mean) ** 2 for y in ys) / n
    return (var ** 0.5) / mean * 100.0


# ---- Main -------------------------------------------------------------

def main():
    log_files = sorted(glob.glob(f"{LOG_DIR}/iter-*.log"))
    if not log_files:
        print(f"No iter-*.log files in {LOG_DIR}")
        sys.exit(1)

    print(f"=== ch952.7 trend analysis ===")
    print(f"Parsing {len(log_files)} iter logs in {LOG_DIR}\n")

    # series[metric_name] = [(iter_num, value), ...]
    series = defaultdict(list)
    for path in log_files:
        m = re.search(r"iter-(\d+)\.log$", path)
        if not m:
            continue
        iter_num = int(m.group(1))
        metrics = parse_iter_log(path)
        for k, v in metrics.items():
            if k.startswith("_"):
                continue
            series[k].append((iter_num, v))

    print(f"Metrics found: {len(series)}\n")

    # For each metric: compute slope (% change per 100 iters) +
    # CoV (% std/mean) + verdict
    results = []
    for key in sorted(series.keys()):
        points = series[key]
        if len(points) < 10:
            continue
        xs = [float(p[0]) for p in points]
        ys = [p[1] for p in points]
        m, b = slope(xs, ys)
        first_val = ys[0]
        last_val = ys[-1]
        mean_val = sum(ys) / len(ys)
        # Drift % per 100 iters = (slope × 100) / mean × 100
        drift_per_100 = (m * 100.0) / max(abs(mean_val), 1e-9) \
            * 100.0
        cov = coefficient_of_variation(ys)
        # Verdict
        if abs(drift_per_100) < 5.0:
            verdict = "STABLE"
        elif abs(drift_per_100) < 15.0:
            verdict = "MILD-DRIFT"
        else:
            verdict = "🔴 DRIFT"
        if cov > 50.0:
            verdict += " (NOISY)"
        results.append({
            "key": key,
            "n": len(points),
            "first": first_val,
            "last": last_val,
            "mean": mean_val,
            "drift_per_100_iters_pct": drift_per_100,
            "cov_pct": cov,
            "verdict": verdict,
        })

    # Print table
    print(f"{'METRIC':<55} {'n':>4} {'first':>10} "
          f"{'last':>10} {'mean':>10} {'drift%/100i':>12} "
          f"{'CoV%':>6}  VERDICT")
    print("-" * 130)
    for r in sorted(results, key=lambda r: r["verdict"]):
        print(f"{r['key']:<55} {r['n']:>4} "
              f"{r['first']:>10.3f} {r['last']:>10.3f} "
              f"{r['mean']:>10.3f} "
              f"{r['drift_per_100_iters_pct']:>+12.2f} "
              f"{r['cov_pct']:>6.1f}  {r['verdict']}")

    # Headlines
    print("\n=== HEADLINES ===")
    drift_count = sum(
        1 for r in results if "DRIFT" in r["verdict"]
        and "MILD" not in r["verdict"])
    mild_count = sum(
        1 for r in results if "MILD-DRIFT" in r["verdict"])
    stable_count = sum(
        1 for r in results if r["verdict"].startswith("STABLE"))
    print(f"  STABLE     : {stable_count}")
    print(f"  MILD-DRIFT : {mild_count}")
    print(f"  DRIFT (🔴) : {drift_count}")
    print(f"  TOTAL      : {len(results)}")

    if drift_count == 0:
        print("\n✅ NO DRIFT detected across all metrics — " +
              "'0 perf regression' claim CONFIRMED by 226-iter " +
              "linear-regression analysis (not just iter-1 vs " +
              "iter-226 snapshot)")
    else:
        drift_metrics = [
            r["key"] for r in results if "DRIFT" in r["verdict"]
            and "MILD" not in r["verdict"]]
        print(f"\n🔴 DRIFT detected on: {drift_metrics}")


if __name__ == "__main__":
    main()

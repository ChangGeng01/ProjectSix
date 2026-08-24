"""Shared side-file → values merge (H23 wire-1 / wire-2, 2026-07-09).

THE 'metric names not wired' defect: build_verdict reads ONLY the single
`/tmp/qinao_values_<tag>.json`, but the harnesses that compute several CRITICAL
gates write ORPHAN side-files (`/tmp/qinao_read_<tag>.json`,
`/tmp/qinao_bench_<tag>.json`, …) that were never ingested — so gates
#20/#21/#26/#28/#29/#30/#31/#32/#38 stayed PENDING in the verdict forever, even
after every harness ran.

This folds a side-file into the values file. Coupled requirement (wire-2): a
MODEL_CRITICAL metric merged WITHOUT `_prov[n]={"kind":"computed"}` is routed to
ATTEST by build_verdict (build_verdict.py:62 — a bare literal is not a verified
pass), so the merge MUST stamp computed provenance for every CRITICAL metric it
ingests, or a genuine pass silently fails to count toward release_ok_model.

Pure + immutable (read → new dict → write); no in-place mutation.
"""
import json
import os
import re
import sys
from typing import Any

sys.path.insert(0, os.path.dirname(__file__))
from qinao_humaneval_evidence import validate_humaneval_evidence  # noqa: E402
from registry import MODEL_CRITICAL  # noqa: E402

# A pure metric-number key ("26"); skips diagnostic keys (_leak / _N / 28_err).
_METRIC_KEY = re.compile(r"^\d+$")

# Harness side-files that carry metric values but were never ingested by
# build_verdict. Prefix (between `qinao_` and `_<tag>.json`) -> runner label.
# qinao_eval / qinao_device / qinao_judge_honesty already write the values file
# (or --merge into it) themselves, so they are intentionally NOT listed here.
KNOWN_SIDEFILES: dict[str, str] = {
    "read": "qinao_reading",
    "reading_hard": "qinao_reading_hard",
    "bench": "qinao_bench",
    "bench_zh": "qinao_bench_zh",
    "cmmlu": "qinao_cmmlu",
    "gsm8k_fair": "qinao_gsm8k_fair",
    "humaneval": "qinao_humaneval",
    "humaneval_paired": "qinao_humaneval_paired",
    "calib": "qinao_calib",
    "forget": "qinao_forget",
    "safety": "qinao_safety",  # #86 prompt_injection, #87 PII_leak (deterministic)
}

_HUMANEVAL_PREFIXES = {
    "humaneval": False,
    "humaneval_paired": True,
}


def _humaneval_pairing_for_runner(runner: str) -> bool | None:
    basename = os.path.basename(runner)
    if runner == "qinao_humaneval_paired" or basename.startswith(
        "qinao_humaneval_paired_"
    ):
        return True
    if runner == "qinao_humaneval" or basename.startswith("qinao_humaneval_"):
        return False
    return None


def _without_humaneval(values: dict[str, Any]) -> dict[str, Any]:
    merged = dict(values)
    merged.pop("30", None)
    prov = dict(values["_prov"]) if isinstance(values.get("_prov"), dict) else {}
    prov.pop("30", None)
    merged["_prov"] = prov
    return merged


def merge_sidefile_into_values(
    values: dict[str, Any], sidefile: dict[str, Any], runner: str
) -> dict[str, Any]:
    """Return a NEW values dict with `sidefile`'s metric-number keys folded in
    and `_prov` stamped 'computed' for every MODEL_CRITICAL metric ingested.
    Existing values / `_prov` are preserved; diagnostic (`_`-prefixed / `*_err`)
    keys are ignored. Does not mutate the inputs."""
    pairing = _humaneval_pairing_for_runner(runner)
    if pairing is not None:
        summary = validate_humaneval_evidence(sidefile, paired=pairing)
        if summary is None:
            return _without_humaneval(values)
        metric_values: dict[str, Any] = {"30": summary.score}
    else:
        metric_values = sidefile

    merged = dict(values)
    prov = dict(values["_prov"]) if isinstance(values.get("_prov"), dict) else {}
    for k, v in metric_values.items():
        if not (isinstance(k, str) and _METRIC_KEY.match(k)):
            continue
        merged[k] = v
        if int(k) in MODEL_CRITICAL:
            prov[k] = {"kind": "computed", "runner": runner}
    merged["_prov"] = prov
    return merged


def merge_known_sidefiles(
    values: dict[str, Any], tag: str, tmpdir: str = "/tmp"
) -> dict[str, Any]:
    """Fold every present KNOWN_SIDEFILE for `tag` into `values` (NEW dict).
    Warns to stderr if two side-files set the same metric to different values
    (last wins) so a silent conflict never masquerades as a clean number."""
    merged = dict(values)
    seen: dict[str, tuple[Any, str]] = {}
    humaneval_present = False
    humaneval_invalid = False
    humaneval_candidates: list[tuple[dict[str, Any], str, Any]] = []
    for prefix, runner in sorted(KNOWN_SIDEFILES.items()):
        path = os.path.join(tmpdir, f"qinao_{prefix}_{tag}.json")
        if not os.path.exists(path):
            continue
        pairing = _HUMANEVAL_PREFIXES.get(prefix)
        if pairing is not None:
            humaneval_present = True
        try:
            with open(path) as fh:
                side = json.load(fh)
        except (json.JSONDecodeError, OSError) as e:
            if pairing is not None:
                humaneval_invalid = True
                sys.stderr.write(
                    f"qinao_merge: HumanEval evidence unavailable at {path}: {e}\n"
                )
            else:
                sys.stderr.write(f"qinao_merge: skipping unreadable {path}: {e}\n")
            continue
        if pairing is not None:
            summary = validate_humaneval_evidence(side, paired=pairing)
            if summary is None:
                humaneval_invalid = True
            else:
                humaneval_candidates.append((side, runner, summary))
            continue
        for k, v in side.items():
            if isinstance(k, str) and _METRIC_KEY.match(k) and k in seen and seen[k][0] != v:
                sys.stderr.write(
                    f"qinao_merge: WARNING metric #{k} conflict: "
                    f"{seen[k][1]}={seen[k][0]} vs {runner}={v} (last wins)\n"
                )
        merged = merge_sidefile_into_values(merged, side, runner)
        for k, v in side.items():
            if isinstance(k, str) and _METRIC_KEY.match(k):
                seen[k] = (v, runner)

    if humaneval_present:
        accepted: tuple[dict[str, Any], str, Any] | None = None
        summaries = {
            (candidate[2].score, candidate[2].sample_count)
            for candidate in humaneval_candidates
        }
        if len(summaries) > 1:
            humaneval_invalid = True
            sys.stderr.write(
                "qinao_merge: WARNING conflicting validated HumanEval evidence; "
                "metric #30 revoked\n"
            )
        if not humaneval_invalid and humaneval_candidates:
            accepted = next(
                (
                    candidate
                    for candidate in humaneval_candidates
                    if candidate[1] == "qinao_humaneval_paired"
                ),
                humaneval_candidates[0],
            )
        if accepted is None:
            merged = _without_humaneval(merged)
        else:
            side, runner, _summary = accepted
            merged = merge_sidefile_into_values(merged, side, runner)
    return merged


def main() -> None:
    if len(sys.argv) < 2:
        sys.stderr.write("usage: qinao_merge.py <tag> [sidefile.json ...]\n")
        sys.exit(2)
    tag = sys.argv[1]
    vpath = f"/tmp/qinao_values_{tag}.json"
    values = json.load(open(vpath)) if os.path.exists(vpath) else {}
    if len(sys.argv) > 2:
        for sf in sys.argv[2:]:
            with open(sf) as fh:
                values = merge_sidefile_into_values(values, json.load(fh), os.path.basename(sf))
    else:
        values = merge_known_sidefiles(values, tag)
    with open(vpath, "w") as fh:
        json.dump(values, fh, indent=1)
    n = len([k for k in values if isinstance(k, str) and k.isdigit()])
    print(f"qinao_merge: {vpath} now carries {n} metric values")


if __name__ == "__main__":
    main()

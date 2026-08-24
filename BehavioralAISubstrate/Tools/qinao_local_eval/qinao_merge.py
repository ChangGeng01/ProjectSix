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

Pure + immutable (read → new dict → write); no in-place mutation. Generic
metric conflicts retain the historical last-wins warning, but metric 30 is
reserved to validated HumanEval evidence: any ownership or validated-summary
conflict revokes it instead of choosing a winner.
"""
import json
import os
import re
import sys
from typing import Any, Iterable

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


def _merge_sidefile_set(
    values: dict[str, Any], sidefiles: Iterable[tuple[object, str]]
) -> dict[str, Any]:
    """Merge one complete observation set with metric-30 invalidation sticky."""

    merged = dict(values)
    prov = dict(values["_prov"]) if isinstance(values.get("_prov"), dict) else {}
    seen: dict[str, tuple[Any, str]] = {}
    humaneval_observed = False
    humaneval_invalid = False
    humaneval_candidates: list[tuple[str, Any]] = []

    for sidefile, runner in sidefiles:
        pairing = _humaneval_pairing_for_runner(runner)
        if pairing is not None:
            humaneval_observed = True
            summary = validate_humaneval_evidence(sidefile, paired=pairing)
            if summary is None:
                humaneval_invalid = True
            else:
                humaneval_candidates.append((runner, summary))
            continue

        if not isinstance(sidefile, dict):
            continue
        if "30" in sidefile:
            humaneval_observed = True
            humaneval_invalid = True
            sys.stderr.write(
                "qinao_merge: WARNING metric #30 claimed by non-HumanEval "
                f"producer {runner}; evidence revoked\n"
            )

        for key, value in sidefile.items():
            if not (
                isinstance(key, str)
                and _METRIC_KEY.match(key)
                and key != "30"
            ):
                continue
            if key in seen and seen[key][0] != value:
                sys.stderr.write(
                    f"qinao_merge: WARNING metric #{key} conflict: "
                    f"{seen[key][1]}={seen[key][0]} vs {runner}={value} "
                    "(last wins)\n"
                )
            merged[key] = value
            if int(key) in MODEL_CRITICAL:
                prov[key] = {"kind": "computed", "runner": runner}
            seen[key] = (value, runner)

    merged["_prov"] = prov
    if not humaneval_observed:
        return merged

    summaries = {
        (candidate.score, candidate.sample_count)
        for _runner, candidate in humaneval_candidates
    }
    if len(summaries) > 1:
        humaneval_invalid = True
        sys.stderr.write(
            "qinao_merge: WARNING conflicting validated HumanEval evidence; "
            "metric #30 revoked\n"
        )

    if humaneval_invalid or not humaneval_candidates:
        return _without_humaneval(merged)

    runner, summary = next(
        (
            candidate
            for candidate in humaneval_candidates
            if _humaneval_pairing_for_runner(candidate[0]) is True
        ),
        humaneval_candidates[0],
    )
    merged["30"] = summary.score
    prov = dict(merged["_prov"])
    prov["30"] = {"kind": "computed", "runner": runner}
    merged["_prov"] = prov
    return merged


def merge_sidefile_into_values(
    values: dict[str, Any], sidefile: dict[str, Any], runner: str
) -> dict[str, Any]:
    """Return a NEW values dict with `sidefile`'s metric-number keys folded in
    and `_prov` stamped 'computed' for every MODEL_CRITICAL metric ingested.
    Existing values / `_prov` are preserved; diagnostic (`_`-prefixed / `*_err`)
    keys are ignored. Does not mutate the inputs."""
    return _merge_sidefile_set(values, [(sidefile, runner)])


def merge_explicit_sidefiles(
    values: dict[str, Any], sidefile_paths: Iterable[str | os.PathLike[str]]
) -> dict[str, Any]:
    """Load and aggregate an explicit file list before making metric decisions."""

    observations: list[tuple[object, str]] = []
    for sidefile_path in sidefile_paths:
        path = os.fspath(sidefile_path)
        runner = os.path.basename(path)
        try:
            with open(path) as sidefile_handle:
                sidefile = json.load(sidefile_handle)
        except (json.JSONDecodeError, OSError) as error:
            if _humaneval_pairing_for_runner(runner) is None:
                raise
            sys.stderr.write(
                f"qinao_merge: HumanEval evidence unavailable at {path}: {error}\n"
            )
            sidefile = None
        observations.append((sidefile, runner))
    return _merge_sidefile_set(values, observations)


def merge_known_sidefiles(
    values: dict[str, Any], tag: str, tmpdir: str = "/tmp"
) -> dict[str, Any]:
    """Fold every present known sidefile as one immutable observation set.

    Generic metric conflicts warn and retain last-wins compatibility. Metric 30
    is different: only validated HumanEval owners may certify it, and any
    invalid owner/evidence/conflict observation revokes it for the whole set.
    """
    observations: list[tuple[object, str]] = []
    for prefix, runner in sorted(KNOWN_SIDEFILES.items()):
        path = os.path.join(tmpdir, f"qinao_{prefix}_{tag}.json")
        if not os.path.exists(path):
            continue
        pairing = _HUMANEVAL_PREFIXES.get(prefix)
        try:
            with open(path) as fh:
                side = json.load(fh)
        except (json.JSONDecodeError, OSError) as e:
            if pairing is not None:
                sys.stderr.write(
                    f"qinao_merge: HumanEval evidence unavailable at {path}: {e}\n"
                )
                observations.append((None, runner))
            else:
                sys.stderr.write(f"qinao_merge: skipping unreadable {path}: {e}\n")
            continue
        observations.append((side, runner))
    return _merge_sidefile_set(values, observations)


def main() -> None:
    if len(sys.argv) < 2:
        sys.stderr.write("usage: qinao_merge.py <tag> [sidefile.json ...]\n")
        sys.exit(2)
    tag = sys.argv[1]
    vpath = f"/tmp/qinao_values_{tag}.json"
    values = json.load(open(vpath)) if os.path.exists(vpath) else {}
    if len(sys.argv) > 2:
        values = merge_explicit_sidefiles(values, sys.argv[2:])
    else:
        values = merge_known_sidefiles(values, tag)
    with open(vpath, "w") as fh:
        json.dump(values, fh, indent=1)
    n = len([k for k in values if isinstance(k, str) and k.isdigit()])
    print(f"qinao_merge: {vpath} now carries {n} metric values")


if __name__ == "__main__":
    main()

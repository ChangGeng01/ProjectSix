"""Typed side-file aggregation for QINAO local-model metrics.

Generic metrics retain the historical last-wins compatibility. Metric #30 is
different: only a typed HumanEval producer selected by the internal known-file
mapping (or the explicit typed API) can certify it. An arbitrary explicit path
is always generic, regardless of its basename.
"""

from __future__ import annotations

import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

sys.path.insert(0, os.path.dirname(__file__))
from qinao_humaneval_evidence import (  # noqa: E402
    HumanEvalEvidenceSummary,
    HumanEvalProducer,
    HumanEvalRunContext,
    optional_humaneval_run_context_from_env,
    validate_humaneval_evidence,
)
from registry import MODEL_CRITICAL  # noqa: E402


_METRIC_KEY = re.compile(r"^\d+$")


@dataclass(frozen=True)
class _ProducerSpec:
    runner: str
    humaneval: HumanEvalProducer | None = None


# The mapping supplies producer identity. Paths and evidence payloads do not.
KNOWN_SIDEFILES: dict[str, _ProducerSpec] = {
    "read": _ProducerSpec("qinao_reading"),
    "reading_hard": _ProducerSpec("qinao_reading_hard"),
    "bench": _ProducerSpec("qinao_bench"),
    "bench_zh": _ProducerSpec("qinao_bench_zh"),
    "cmmlu": _ProducerSpec("qinao_cmmlu"),
    "gsm8k_fair": _ProducerSpec("qinao_gsm8k_fair"),
    "humaneval": _ProducerSpec(
        HumanEvalProducer.STANDARD.runner, HumanEvalProducer.STANDARD
    ),
    "humaneval_paired": _ProducerSpec(
        HumanEvalProducer.PAIRED.runner, HumanEvalProducer.PAIRED
    ),
    "calib": _ProducerSpec("qinao_calib"),
    "forget": _ProducerSpec("qinao_forget"),
    "safety": _ProducerSpec("qinao_safety"),
}


def _without_humaneval(values: dict[str, Any]) -> dict[str, Any]:
    merged = dict(values)
    merged.pop("30", None)
    prov = dict(values["_prov"]) if isinstance(values.get("_prov"), dict) else {}
    prov.pop("30", None)
    merged["_prov"] = prov
    return merged


def _cross_producer_identity(summary: HumanEvalEvidenceSummary) -> tuple[object, ...]:
    """Facts that standard and paired observations of one subject must share."""

    return (
        summary.score,
        summary.sample_count,
        summary.run_id,
        summary.tag,
        summary.subject_sha256,
        summary.dataset_id,
        summary.dataset_split,
        summary.dataset_fingerprint,
        summary.sample_set_sha256,
    )


def _merge_sidefile_set(
    values: dict[str, Any],
    sidefiles: Iterable[tuple[object, _ProducerSpec]],
    *,
    humaneval_context: HumanEvalRunContext | None = None,
    tag: str | None = None,
) -> dict[str, Any]:
    """Merge one complete observation set with sticky metric-30 invalidation."""

    merged = dict(values)
    prov = dict(values["_prov"]) if isinstance(values.get("_prov"), dict) else {}
    seen: dict[str, tuple[Any, str]] = {}
    humaneval_observed = False
    humaneval_invalid = False
    humaneval_candidates: list[tuple[_ProducerSpec, HumanEvalEvidenceSummary]] = []

    for sidefile, producer in sidefiles:
        if producer.humaneval is not None:
            humaneval_observed = True
            if humaneval_context is None or tag is None:
                humaneval_invalid = True
                continue
            summary = validate_humaneval_evidence(
                sidefile,
                producer=producer.humaneval,
                context=humaneval_context,
                tag=tag,
            )
            if summary is None:
                humaneval_invalid = True
            else:
                humaneval_candidates.append((producer, summary))
            continue

        if not isinstance(sidefile, dict):
            continue
        if "30" in sidefile:
            humaneval_observed = True
            humaneval_invalid = True
            sys.stderr.write(
                "qinao_merge: WARNING metric #30 claimed by non-HumanEval "
                f"producer {producer.runner}; evidence revoked\n"
            )

        for key, value in sidefile.items():
            if not (isinstance(key, str) and _METRIC_KEY.match(key) and key != "30"):
                continue
            if key in seen and seen[key][0] != value:
                sys.stderr.write(
                    f"qinao_merge: WARNING metric #{key} conflict: "
                    f"{seen[key][1]}={seen[key][0]} vs {producer.runner}={value} "
                    "(last wins)\n"
                )
            merged[key] = value
            if int(key) in MODEL_CRITICAL:
                prov[key] = {"kind": "computed", "runner": producer.runner}
            seen[key] = (value, producer.runner)

    merged["_prov"] = prov
    if not humaneval_observed:
        return _without_humaneval(merged)

    identities = {
        _cross_producer_identity(summary) for _producer, summary in humaneval_candidates
    }
    if len(identities) > 1:
        humaneval_invalid = True
        sys.stderr.write(
            "qinao_merge: WARNING conflicting validated HumanEval evidence; "
            "metric #30 revoked\n"
        )

    if humaneval_invalid or not humaneval_candidates:
        return _without_humaneval(merged)

    selected_producer, selected_summary = next(
        (
            candidate
            for candidate in humaneval_candidates
            if candidate[0].humaneval is HumanEvalProducer.PAIRED
        ),
        humaneval_candidates[0],
    )
    merged["30"] = selected_summary.score
    prov = dict(merged["_prov"])
    prov["30"] = {
        "kind": "computed",
        "runner": selected_producer.runner,
        "evidence": selected_summary.provenance(),
    }
    merged["_prov"] = prov
    return merged


def merge_sidefile_into_values(
    values: dict[str, Any], sidefile: dict[str, Any], runner: str
) -> dict[str, Any]:
    """Merge one generic producer; a runner string never grants #30 ownership."""

    return _merge_sidefile_set(values, [(sidefile, _ProducerSpec(runner))])


def merge_humaneval_sidefile_into_values(
    values: dict[str, Any],
    sidefile: object,
    *,
    producer: HumanEvalProducer,
    context: HumanEvalRunContext,
    tag: str,
) -> dict[str, Any]:
    """Typed in-memory HumanEval aggregation API used by controlled callers."""

    if not isinstance(producer, HumanEvalProducer):
        raise TypeError("producer must be a HumanEvalProducer")
    return _merge_sidefile_set(
        values,
        [(sidefile, _ProducerSpec(producer.runner, producer))],
        humaneval_context=context,
        tag=tag,
    )


def merge_explicit_sidefiles(
    values: dict[str, Any], sidefile_paths: Iterable[str | os.PathLike[str]]
) -> dict[str, Any]:
    """Aggregate explicit arbitrary files; their basenames carry no authority."""

    observations: list[tuple[object, _ProducerSpec]] = []
    for sidefile_path in sidefile_paths:
        path = os.fspath(sidefile_path)
        with open(path, encoding="utf-8") as sidefile_handle:
            sidefile = json.load(sidefile_handle)
        observations.append((sidefile, _ProducerSpec(os.path.basename(path))))
    return _merge_sidefile_set(values, observations)


def merge_known_sidefiles(
    values: dict[str, Any],
    tag: str,
    tmpdir: str = "/tmp",
    *,
    humaneval_context: HumanEvalRunContext | None = None,
) -> dict[str, Any]:
    """Fold known producers, binding HumanEval to the explicit current run.

    Generic sidefiles retain their historical ``tmpdir`` location. HumanEval
    files are read only from ``humaneval_context.evidence_dir``; legacy /tmp
    files and filename-shaped explicit files are never considered evidence.
    """

    observations: list[tuple[object, _ProducerSpec]] = []
    for prefix, producer in sorted(KNOWN_SIDEFILES.items()):
        if producer.humaneval is not None:
            if humaneval_context is None:
                continue
            path = humaneval_context.evidence_dir / f"qinao_{prefix}_{tag}.json"
        else:
            path = Path(tmpdir) / f"qinao_{prefix}_{tag}.json"
        if not path.exists():
            continue
        try:
            with path.open(encoding="utf-8") as handle:
                sidefile = json.load(handle)
        except (json.JSONDecodeError, OSError) as error:
            if producer.humaneval is not None:
                sys.stderr.write(
                    f"qinao_merge: HumanEval evidence unavailable at {path}: {error}\n"
                )
                observations.append((None, producer))
            else:
                sys.stderr.write(f"qinao_merge: skipping unreadable {path}: {error}\n")
            continue
        observations.append((sidefile, producer))
    return _merge_sidefile_set(
        values,
        observations,
        humaneval_context=humaneval_context,
        tag=tag,
    )


def main() -> None:
    if len(sys.argv) < 2:
        sys.stderr.write("usage: qinao_merge.py <tag> [sidefile.json ...]\n")
        sys.exit(2)
    tag = sys.argv[1]
    values_path = Path("/tmp") / f"qinao_values_{tag}.json"
    values = (
        json.loads(values_path.read_text(encoding="utf-8"))
        if values_path.exists()
        else {}
    )
    if len(sys.argv) > 2:
        values = merge_explicit_sidefiles(values, sys.argv[2:])
    else:
        try:
            context = optional_humaneval_run_context_from_env(required_tags=(tag,))
        except ValueError as error:
            sys.stderr.write(f"qinao_merge: invalid current-run context: {error}\n")
            sys.exit(2)
        values = merge_known_sidefiles(values, tag, humaneval_context=context)
    values_path.write_text(json.dumps(values, indent=1), encoding="utf-8")
    count = len([key for key in values if isinstance(key, str) and key.isdigit()])
    print(f"qinao_merge: {values_path} now carries {count} metric values")


if __name__ == "__main__":
    main()

"""M657 chapter 一百八十三 — single-source Python feature schema.

Mirror of `SampleHost/ChengluFeatureEncoder.swift` (chapter 一百
八十二 M652). All Python training scripts import alphabet
constants + featurize from THIS module instead of duplicating
their own copy.

Pre-this-batch: 4 Python train scripts each had their own
TONES/DOMAINS/STAKES/etc. arrays + their own featurize_row, all
identical. Adding a tone meant editing 4 files + 1 Swift file.

Post-this-batch: Python alphabet lives once in this module.
Adding a tone means editing 2 files (this + Swift). Cross-language
single-source via YAML codegen is chapter 一百八十四+ candidate.

Schema MUST stay byte-identical to Swift's
`ChengluFeatureEncoder` arrays. The dimensional invariant is
asserted at import time so any drift fails fast.
"""

from __future__ import annotations

from typing import Iterable

# Order MUST match Swift `ChengluFeatureEncoder.tones` etc.
# 7 alphabets, total 43 dimensions.
TONES = [
    "anxious", "authoritative", "vulnerable", "agentic",
    "confused", "grieving", "curious", "angry",
]
DOMAINS = [
    "financial", "medical", "relational", "work", "parenting",
    "identity", "ethical", "existential", "trauma", "creative",
]
STAKES = [
    "low", "modest", "high", "very-high",
    "irreversible", "non-reversible-after-act",
]
TIMEFRAMES = [
    "minutes", "hours", "days", "weeks",
    "months", "lifetime", "past-unresolved",
]
CONFIDANTS = ["friend", "expert", "stranger", "decision-system"]
ASKSHAPES = ["narrative", "decision-tree", "single-action"]
MUTATIONS = list(range(5))

FEATURE_COUNT = 43


def _build_feature_names() -> list[str]:
    """Generate feature name list in canonical order. Used by
    train scripts for sklearn feature_names_in_ + by debug
    inspection."""
    names: list[str] = []
    for t in TONES:
        names.append(f"tone_{t}")
    for d in DOMAINS:
        names.append(f"domain_{d}")
    for s in STAKES:
        names.append(f"stake_{s}")
    for t in TIMEFRAMES:
        names.append(f"timeframe_{t}")
    for c in CONFIDANTS:
        names.append(f"confidant_{c}")
    for a in ASKSHAPES:
        names.append(f"askshape_{a}")
    for m in MUTATIONS:
        names.append(f"mutation_{m}")
    return names


FEATURE_NAMES = _build_feature_names()

# Compile-time invariant: alphabet sums to feature count.
_alphabet_sum = (
    len(TONES) + len(DOMAINS) + len(STAKES) + len(TIMEFRAMES)
    + len(CONFIDANTS) + len(ASKSHAPES) + len(MUTATIONS)
)
assert _alphabet_sum == FEATURE_COUNT == len(FEATURE_NAMES), (
    f"Schema dimension drift: alphabet={_alphabet_sum}, "
    f"FEATURE_COUNT={FEATURE_COUNT}, names={len(FEATURE_NAMES)}"
)


def featurize_row(row: dict) -> list[float]:
    """Encode a chapter-176 bench JSONL row's signature into the
    canonical 43-dim float one-hot vector. Order matches
    Swift's `ChengluFeatureEncoder.encode(_:)`.

    Returns a list[float] (not np.ndarray) for compatibility with
    sklearn's input_fn pattern in v0.x training scripts.
    """
    sig = row.get("signature") or {}
    if not isinstance(sig, dict):
        sig = {}
    tone = sig.get("tone")
    domain = sig.get("domain")
    stake = sig.get("stake")
    timeframe = sig.get("timeframe")
    confidant = sig.get("confidant")
    ask_shape = sig.get("askShape")
    mutation_seed = row.get("mutationSeed")

    features: list[float] = []
    features += [1.0 if tone == t else 0.0 for t in TONES]
    features += [1.0 if domain == d else 0.0 for d in DOMAINS]
    features += [1.0 if stake == s else 0.0 for s in STAKES]
    features += [1.0 if timeframe == t else 0.0 for t in TIMEFRAMES]
    features += [1.0 if confidant == c else 0.0 for c in CONFIDANTS]
    features += [1.0 if ask_shape == a else 0.0 for a in ASKSHAPES]
    features += [1.0 if mutation_seed == m else 0.0 for m in MUTATIONS]
    assert len(features) == FEATURE_COUNT
    return features


def label_afm_ok(row: dict) -> int:
    """Binary label: 1 if AFM returned 'ok', else 0 (guardrail/error)."""
    return 1 if row.get("afmStatus") == "ok" else 0


def label_block(row: dict) -> int:
    """Binary label: 1 if substrate routed to .block, else 0."""
    return 1 if row.get("permitMode") == "block" else 0


def label_body_length(row: dict) -> float:
    val = row.get("afmBodyLength")
    return float(val) if val is not None else 0.0


def label_duration_ms(row: dict) -> float:
    val = row.get("afmDurationMs")
    return float(val) if val is not None else 0.0


def label_verbosity_class(row: dict, threshold: int = 1500) -> int:
    """Binary label: 1 if AFM body > threshold chars, else 0.

    Threshold 1500 chars = chapter 175/176 corpus median (post-
    chapter 一百八十一 audit). M661 5th CoreML head trains on
    this label. Useful UI hint: 'this prompt likely produces a
    long response' before LLM call completes.
    """
    val = row.get("afmBodyLength")
    if val is None:
        return 0
    return 1 if int(val) > threshold else 0


def schema_summary() -> dict:
    """Diagnostic summary used by sanity scripts + tests."""
    return {
        "feature_count": FEATURE_COUNT,
        "alphabet_sizes": {
            "tones": len(TONES),
            "domains": len(DOMAINS),
            "stakes": len(STAKES),
            "timeframes": len(TIMEFRAMES),
            "confidants": len(CONFIDANTS),
            "askshapes": len(ASKSHAPES),
            "mutations": len(MUTATIONS),
        },
        "feature_names_first_5": FEATURE_NAMES[:5],
        "feature_names_last_5": FEATURE_NAMES[-5:],
    }

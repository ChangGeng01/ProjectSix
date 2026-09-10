"""M665 chapter 一百八十四 — Python-side fix-pin tests.

Pytest-style tests for `chenglu_feature_schema.py` and
`check_chenglu_schema_parity.py`. Closes finding C24 (Python
schema had no unit tests).

Run via:
    /tmp/coreml-py312/bin/python3 -m pytest scripts/test_chenglu_feature_schema.py -v

Or as a smoke script:
    /tmp/coreml-py312/bin/python3 scripts/test_chenglu_feature_schema.py
"""

from __future__ import annotations

import os
import sys
import json
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, os.path.dirname(__file__))

from chenglu_feature_schema import (  # noqa: E402
    TONES, DOMAINS, STAKES, TIMEFRAMES,
    CONFIDANTS, ASKSHAPES, MUTATIONS,
    FEATURE_COUNT, FEATURE_NAMES,
    VERBOSITY_THRESHOLD_CHARS,
    featurize_row,
    label_afm_ok, label_block,
    label_body_length, label_duration_ms,
    label_verbosity_class,
    schema_summary,
)
from check_chenglu_schema_parity import (  # noqa: E402
    parse_swift_array,
    _strip_swift_comments,
)


# === Schema invariants ===

def test_feature_count_matches_alphabet_sum() -> None:
    """C3 fix: invariant must NOT be assert (strippable by -O).
    The schema module already enforces this at import; this test
    re-asserts it for documentation."""
    total = (
        len(TONES) + len(DOMAINS) + len(STAKES) + len(TIMEFRAMES)
        + len(CONFIDANTS) + len(ASKSHAPES) + len(MUTATIONS)
    )
    assert total == FEATURE_COUNT == 43


def test_feature_names_count() -> None:
    assert len(FEATURE_NAMES) == FEATURE_COUNT


def test_verbosity_threshold_constant() -> None:
    """C5 fix: single source for verbosity threshold."""
    assert VERBOSITY_THRESHOLD_CHARS == 1500


def test_schema_summary_smoke() -> None:
    summary = schema_summary()
    assert summary["feature_count"] == 43
    assert sum(summary["alphabet_sizes"].values()) == 43


# === featurize_row ===

def test_featurize_canonical_input() -> None:
    """All-first values produces 7-active one-hot."""
    row = {
        "signature": {
            "tone": TONES[0], "domain": DOMAINS[0],
            "stake": STAKES[0], "timeframe": TIMEFRAMES[0],
            "confidant": CONFIDANTS[0], "askShape": ASKSHAPES[0],
        },
        "mutationSeed": MUTATIONS[0],
    }
    v = featurize_row(row)
    assert len(v) == 43
    assert sum(v) == 7.0


def test_featurize_unknown_values() -> None:
    """Out-of-vocab → all zeros (degenerate but non-crashing).

    Mirrors Swift `testFeatureEncoderUnknownValuesAllZero`.
    """
    row = {
        "signature": {
            "tone": "INVALID", "domain": "INVALID",
            "stake": "INVALID", "timeframe": "INVALID",
            "confidant": "INVALID", "askShape": "INVALID",
        },
        "mutationSeed": 99,
    }
    v = featurize_row(row)
    assert len(v) == 43
    assert sum(v) == 0.0


def test_featurize_missing_signature() -> None:
    """No signature key → empty signature, all zeros."""
    v = featurize_row({})
    assert len(v) == 43
    assert sum(v) == 0.0


# === label functions ===

def test_label_afm_ok() -> None:
    assert label_afm_ok({"afmStatus": "ok"}) == 1
    assert label_afm_ok({"afmStatus": "guardrailViolation"}) == 0
    assert label_afm_ok({}) == 0


def test_label_block() -> None:
    assert label_block({"permitMode": "block"}) == 1
    assert label_block({"permitMode": "delay"}) == 0
    assert label_block({"permitMode": "BLOCK"}) == 0  # case-sensitive
    assert label_block({}) == 0


def test_label_body_length() -> None:
    assert label_body_length({"afmBodyLength": 1500}) == 1500.0
    assert label_body_length({"afmBodyLength": 1500.5}) == 1500.5
    assert label_body_length({}) == 0.0


def test_label_duration_ms() -> None:
    assert label_duration_ms({"afmDurationMs": 5000}) == 5000.0
    assert label_duration_ms({}) == 0.0


def test_label_verbosity_class() -> None:
    """C4 fix: float input must work (was: int(val) raised on
    scientific-notation strings)."""
    assert label_verbosity_class({"afmBodyLength": 2000}) == 1
    assert label_verbosity_class({"afmBodyLength": 1500}) == 0
    assert label_verbosity_class({"afmBodyLength": 1500.5}) == 1
    assert label_verbosity_class({"afmBodyLength": "1.5e3"}) == 0
    assert label_verbosity_class({"afmBodyLength": "oops"}) == 0
    assert label_verbosity_class({}) == 0


def test_label_verbosity_class_threshold_param() -> None:
    """Threshold can be overridden."""
    row = {"afmBodyLength": 1000}
    assert label_verbosity_class(row, threshold=500) == 1
    assert label_verbosity_class(row, threshold=2000) == 0


# === parity check helpers ===

def test_strip_swift_comments_line() -> None:
    src = '"a", // "old-name" deprecated\n"b"'
    stripped = _strip_swift_comments(src)
    assert "old-name" not in stripped


def test_strip_swift_comments_block() -> None:
    src = '"a", /* "drop" */ "b"'
    stripped = _strip_swift_comments(src)
    assert "drop" not in stripped


def test_parse_swift_array_basic() -> None:
    src = 'public static let stakes: [String] = ["low", "high"]'
    assert parse_swift_array(src, "stakes") == ["low", "high"]


def test_parse_swift_array_strips_comments() -> None:
    """C2 fix: inline comment with quoted text shouldn't leak
    into parsed alphabet."""
    src = '''
public static let tones: [String] = [
    "anxious",  // "old-name" was deprecated
    "angry",
]
'''
    items = parse_swift_array(src, "tones")
    assert items == ["anxious", "angry"]


def test_parse_swift_array_rejects_duplicates() -> None:
    """C1 fix: duplicate declaration must raise (drift detection
    ambiguous)."""
    src = '''
public static let tones: [String] = ["a"]
public static let tones: [String] = ["b"]
'''
    with pytest.raises(ValueError, match="expected exactly 1"):
        parse_swift_array(src, "tones")


def test_parse_swift_array_rejects_missing() -> None:
    with pytest.raises(ValueError, match="could not locate"):
        parse_swift_array("", "nonexistent")


# === smoke entry point ===

if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))

#!/usr/bin/env python3
"""M660 chapter 一百八十三 — cross-language schema parity check.

Reads `SampleHost/ChengluFeatureEncoder.swift` and parses the 7
alphabet arrays + featureCount from it via simple regex (the
file is small + stable). Compares against Python's
`chenglu_feature_schema.py` constants. Asserts they match.

Run as part of CI / local sanity to catch alphabet drift between
Swift and Python sides:
    python3 scripts/check_chenglu_schema_parity.py

Exit 0 = match, exit 1 = drift detected.

Why a script-level check (not a Swift unit test): Swift can't
reach into Python, and vice versa. A small Python parser of the
Swift file is the cheapest cross-language sanity gate. The
"production" boundary check is at training time (training script
imports Python schema; inference reads same Swift schema; if
they drift, the trained .mlpackage's input-feature ordering will
be wrong and predictions will be garbage — easier to catch here).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SWIFT_FILE = REPO / "SampleHost" / "ChengluFeatureEncoder.swift"
SCHEMA_MODULE_DIR = REPO / "scripts"
sys.path.insert(0, str(SCHEMA_MODULE_DIR))
from chenglu_feature_schema import (  # noqa: E402
    TONES, DOMAINS, STAKES, TIMEFRAMES,
    CONFIDANTS, ASKSHAPES, MUTATIONS, FEATURE_COUNT,
)


def _strip_swift_comments(swift_src: str) -> str:
    """M665 chapter 一百八十四 deep-review fix C2 (HIGH):
    strip Swift comments BEFORE regex extraction so an inline
    `// "old-name" deprecated` comment containing a quoted string
    doesn't pollute the parsed alphabet. Removes:
      - line comments: `// ... \n`
      - block comments: `/* ... */`
    """
    src = re.sub(r"//[^\n]*", "", swift_src)
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.DOTALL)
    return src


def parse_swift_array(swift_src: str, name: str) -> list[str]:
    """Parse a `public static let X: [String] = ["a", "b", ...]`
    declaration. Tolerates multi-line, whitespace, trailing
    comma. M665 chapter 一百八十四 deep-review fix C1 + C2:
    asserts EXACTLY one declaration matches (so a stray
    duplicate elsewhere in the source can't silently shadow);
    strips Swift comments first so quoted strings inside
    comments don't leak into the alphabet."""
    src = _strip_swift_comments(swift_src)
    # Match "public static let NAME: [String] = [ ... ]"
    pattern = (
        r"public\s+static\s+let\s+" + re.escape(name)
        + r"\s*:\s*\[String\]\s*=\s*\[(.*?)\]"
    )
    matches = re.findall(pattern, src, re.DOTALL)
    if len(matches) == 0:
        raise ValueError(
            f"could not locate {name} in Swift source")
    if len(matches) > 1:
        raise ValueError(
            f"{name}: expected exactly 1 declaration, "
            f"found {len(matches)} — drift detection ambiguous"
        )
    body = matches[0]
    # Extract all "..." quoted strings
    items = re.findall(r'"([^"]+)"', body)
    return items


def parse_swift_range(swift_src: str, name: str) -> tuple[int, int]:
    """Parse `public static let mutationSeedRange: Range<Int> =
    0..<5` — returns (lo, hi)."""
    pattern = (
        r"public\s+static\s+let\s+" + re.escape(name)
        + r"\s*:\s*Range<Int>\s*=\s*(\d+)\s*\.\.<\s*(\d+)"
    )
    m = re.search(pattern, swift_src)
    if not m:
        raise ValueError(f"could not locate {name} in Swift source")
    return int(m.group(1)), int(m.group(2))


def parse_swift_int(swift_src: str, name: str) -> int:
    pattern = (
        r"public\s+static\s+let\s+" + re.escape(name)
        + r"\s*:\s*Int\s*=\s*(\d+)"
    )
    m = re.search(pattern, swift_src)
    if not m:
        raise ValueError(f"could not locate {name} in Swift source")
    return int(m.group(1))


def main() -> int:
    if not SWIFT_FILE.exists():
        print(f"ERROR: Swift file missing at {SWIFT_FILE}",
              file=sys.stderr)
        return 1
    swift_src = SWIFT_FILE.read_text()

    swift_tones = parse_swift_array(swift_src, "tones")
    swift_domains = parse_swift_array(swift_src, "domains")
    swift_stakes = parse_swift_array(swift_src, "stakes")
    swift_timeframes = parse_swift_array(swift_src, "timeframes")
    swift_confidants = parse_swift_array(swift_src, "confidants")
    swift_askshapes = parse_swift_array(swift_src, "askShapes")
    swift_mutation_lo, swift_mutation_hi = parse_swift_range(
        swift_src, "mutationSeedRange"
    )
    swift_feature_count = parse_swift_int(swift_src, "featureCount")

    failures: list[str] = []

    def check(name: str, swift_val, py_val):
        if swift_val != py_val:
            failures.append(
                f"  {name}: Swift={swift_val} vs Python={py_val}"
            )

    check("tones", swift_tones, TONES)
    check("domains", swift_domains, DOMAINS)
    check("stakes", swift_stakes, STAKES)
    check("timeframes", swift_timeframes, TIMEFRAMES)
    check("confidants", swift_confidants, CONFIDANTS)
    check("askShapes", swift_askshapes, ASKSHAPES)
    swift_mutation_range = list(
        range(swift_mutation_lo, swift_mutation_hi)
    )
    check("mutationSeed range",
          swift_mutation_range, MUTATIONS)
    check("featureCount", swift_feature_count, FEATURE_COUNT)

    if failures:
        print("Schema parity FAILED — drift detected:",
              file=sys.stderr)
        for f in failures:
            print(f, file=sys.stderr)
        print(
            "\nFix: edit Swift `ChengluFeatureEncoder.swift` and "
            "Python `chenglu_feature_schema.py` to match. They "
            "MUST be byte-identical for trained CoreML models to "
            "receive features in the correct dimensional order.",
            file=sys.stderr,
        )
        return 1

    print(
        f"check_chenglu_schema_parity: clean — "
        f"Swift + Python schemas match across "
        f"7 alphabets + {swift_feature_count}-dim featureCount."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""measure_loc.py — chapter 七百二 第四刀 / M2170

Comment-aware language LOC counter for the BehavioralAISubstrate.
Implements the user directive 「不要 计算 commented 代码」 by stripping
language-appropriate comments before counting.

## Strip rules

  - Swift / C / C++ / Objective-C / Metal : strip `//` line comments
                                            AND `/* */` block comments
                                            (block comments nest in Swift)
  - SQL                                   : strip `--` line comments
                                            AND `/* */` block comments
  - Rust                                  : strip `//` line comments
                                            AND `/* */` block comments
                                            (block comments nest in Rust too)

After stripping comments, blank lines are excluded from the count.

## Languages tallied

  - Swift  (.swift, in Sources/)
  - Rust   (.rs,   in Cargo/)
  - SQL    (.sql,  in Sources/)
  - Metal  (.metal,in Sources/)
  - C      (.c .h, in Sources/)
  - C++    (.cpp .mm .hh, in Sources/)

## Output

  - Per-language total LOC (comments stripped)
  - Percentage of total
  - Diff vs target ratios (Swift 70%, Rust 15%, SQL 5%,
    Metal 5%, C+C++ 5%)
"""
from __future__ import annotations
import os
import sys
from pathlib import Path
from typing import Tuple

ROOT = Path(__file__).resolve().parent.parent

# (extension, language, search dirs)
LANG_MAP = [
    (("swift",),                 "Swift", ["Sources"]),
    (("rs",),                    "Rust",  ["Cargo"]),
    (("sql",),                   "SQL",   ["Sources"]),
    (("metal",),                 "Metal", ["Sources"]),
    (("c", "h"),                 "C",     ["Sources"]),
    (("cpp", "mm", "hh", "cc"),  "C++",   ["Sources"]),
]


def strip_swift_or_cstyle(text: str) -> str:
    """Strip // line comments AND nesting /* */ block comments."""
    out: list[str] = []
    i = 0
    n = len(text)
    in_string = False
    string_delim = ""
    in_line_comment = False
    block_depth = 0
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if in_line_comment:
            if c == "\n":
                in_line_comment = False
                out.append("\n")
            i += 1
            continue
        if block_depth > 0:
            if c == "/" and nxt == "*":
                block_depth += 1
                i += 2
                continue
            if c == "*" and nxt == "/":
                block_depth -= 1
                i += 2
                continue
            if c == "\n":
                out.append("\n")
            i += 1
            continue
        if in_string:
            if c == "\\" and nxt:
                out.append(c)
                out.append(nxt)
                i += 2
                continue
            if c == string_delim:
                in_string = False
            out.append(c)
            i += 1
            continue
        # Not in any state: check for state transitions
        if c == "/" and nxt == "/":
            in_line_comment = True
            i += 2
            continue
        if c == "/" and nxt == "*":
            block_depth = 1
            i += 2
            continue
        if c == '"':
            in_string = True
            string_delim = '"'
            out.append(c)
            i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def strip_sql(text: str) -> str:
    """Strip -- line comments AND /* */ block comments (non-nesting)."""
    out: list[str] = []
    i = 0
    n = len(text)
    in_string = False
    in_line_comment = False
    in_block_comment = False
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if in_line_comment:
            if c == "\n":
                in_line_comment = False
                out.append("\n")
            i += 1
            continue
        if in_block_comment:
            if c == "*" and nxt == "/":
                in_block_comment = False
                i += 2
                continue
            if c == "\n":
                out.append("\n")
            i += 1
            continue
        if in_string:
            if c == "'" and nxt == "'":
                out.append("''")
                i += 2
                continue
            if c == "'":
                in_string = False
            out.append(c)
            i += 1
            continue
        if c == "-" and nxt == "-":
            in_line_comment = True
            i += 2
            continue
        if c == "/" and nxt == "*":
            in_block_comment = True
            i += 2
            continue
        if c == "'":
            in_string = True
            out.append(c)
            i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def count_loc(path: Path, ext: str) -> int:
    """Count non-blank, non-comment lines."""
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        return 0
    if ext == "sql":
        stripped = strip_sql(text)
    else:
        stripped = strip_swift_or_cstyle(text)
    return sum(1 for ln in stripped.split("\n") if ln.strip())


def main() -> int:
    totals: dict[str, int] = {}
    file_counts: dict[str, int] = {}
    for exts, lang, dirs in LANG_MAP:
        lang_total = 0
        files = 0
        for d in dirs:
            base = ROOT / d
            if not base.exists():
                continue
            for ext in exts:
                for path in base.rglob(f"*.{ext}"):
                    lang_total += count_loc(path, ext)
                    files += 1
        totals[lang] = lang_total
        file_counts[lang] = files

    grand = sum(totals.values())
    if grand == 0:
        print("no LOC found", file=sys.stderr)
        return 1

    target = {
        "Swift": 70.0,
        "Rust":  15.0,
        "SQL":    5.0,
        "Metal":  5.0,
        "C":      2.5,
        "C++":    2.5,
    }
    print()
    print("chapter 七百二 第四刀 / M2170 — comment-stripped LOC report")
    print(f"  measured from: {ROOT}")
    print(f"  comment-stripping: // line + /* */ block (nesting where applicable),"
          " -- + /* */ for SQL")
    print()
    print(f"  {'Language':<8} {'files':>6} {'LOC':>10} {'pct':>8}"
          f"  {'target':>7}  {'gap':>8}")
    print(f"  {'-'*8} {'-'*6} {'-'*10} {'-'*8}  {'-'*7}  {'-'*8}")
    for _exts, lang, _dirs in LANG_MAP:
        loc = totals[lang]
        pct = loc * 100.0 / grand
        tgt = target.get(lang, 0.0)
        gap = pct - tgt
        sign = "+" if gap >= 0 else ""
        print(f"  {lang:<8} {file_counts[lang]:>6} {loc:>10} {pct:>7.2f}%"
              f"  {tgt:>6.2f}%  {sign}{gap:>7.2f}%")
    print(f"  {'-'*8} {'-'*6} {'-'*10} {'-'*8}")
    print(f"  {'TOTAL':<8} {sum(file_counts.values()):>6} {grand:>10}"
          f"  100.00%")
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

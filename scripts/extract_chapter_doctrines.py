#!/usr/bin/env python3
"""
chapter 四百六十六 / M1241 — Phase 3 of doctrine collapse。

One-off extractor that parses every BASChapter###EntropyDoctrine.swift
file in the BAS RuntimeCore source directory + emits a single Swift
file containing literal BASChapterDoctrineRecord constructors for all
chapters。

USAGE:
  1. Edit DIR below if your BASRuntimeCore location differs
  2. python3 Scripts/extract_chapter_doctrines.py
  3. Output written to BASChapterDoctrineRegistry+AllLiterals.swift

Committed for reproducibility (chapter 473 fix #4 of chapter 466
self-audit)。 Output is canonical going forward;the script is
build-time-not-required。

Known limitations:
  - Misses non-standard static lets beyond the 10-field schema
    (chapter 404 v2/v3/v4 milestone fields surfaced via test fail)
  - Swift escape handling:" \\\\ n t ' only
"""
import re
import os
import glob
import sys

DIR = "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore"

def extract_swift_string(text, start_idx):
    """
    Starting at start_idx (after a '='), parse out a Swift string literal that
    may span multiple lines via '+' concatenation. Returns (string_value, end_idx).
    Multi-line example:
        = "foo" +
          " bar" +
          " baz"
    """
    s = ""
    i = start_idx
    while i < len(text):
        # Skip whitespace
        while i < len(text) and text[i] in " \t\n":
            i += 1
        if i >= len(text) or text[i] != '"':
            break
        # Find closing quote with Swift escape handling
        i += 1  # past opening "
        seg = ""
        while i < len(text):
            if text[i] == '\\' and i + 1 < len(text):
                # Swift escape sequence — convert to literal char
                nxt = text[i+1]
                if nxt == '"':
                    seg += '"'
                elif nxt == '\\':
                    seg += '\\'
                elif nxt == 'n':
                    seg += '\n'
                elif nxt == 't':
                    seg += '\t'
                elif nxt == "'":
                    seg += "'"
                else:
                    seg += nxt  # unknown escape, take literal
                i += 2
            elif text[i] == '"':
                i += 1  # past closing "
                break
            else:
                seg += text[i]
                i += 1
        s += seg
        # Check for + continuation
        j = i
        while j < len(text) and text[j] in " \t\n":
            j += 1
        if j < len(text) and text[j] == '+':
            i = j + 1
        else:
            break
    return s, i


def extract_string_list(text, start_idx):
    """
    Extract a Swift string array literal: [ "a", "b" + " c", ... ]
    Each element may be multi-line concatenated. Returns (list, end_idx after ']').
    """
    i = start_idx
    # Find opening [
    while i < len(text) and text[i] != '[':
        i += 1
    if i >= len(text):
        return [], i
    i += 1
    out = []
    while i < len(text):
        # Skip whitespace
        while i < len(text) and text[i] in " \t\n,":
            i += 1
        if i >= len(text):
            break
        if text[i] == ']':
            i += 1
            return out, i
        if text[i] == '"':
            s, i = extract_swift_string(text, i)
            out.append(s)
        else:
            # Skip comment (until newline)
            if text[i:i+2] == '//':
                eol = text.find('\n', i)
                if eol == -1:
                    break
                i = eol + 1
            else:
                # Skip unknown char
                i += 1
    return out, i


def extract_knives(text, start_idx):
    """
    Extract knives: [(Int, "...", "..." + "..."), ...]
    Each tuple is (mNumber, knife, concept).
    """
    i = start_idx
    while i < len(text) and text[i] != '[':
        i += 1
    if i >= len(text):
        return [], i
    i += 1
    out = []
    while i < len(text):
        # Skip whitespace and commas
        while i < len(text) and text[i] in " \t\n,":
            i += 1
        if i >= len(text):
            break
        if text[i] == ']':
            i += 1
            return out, i
        if text[i] == '(':
            # Parse tuple
            i += 1
            # Skip whitespace
            while i < len(text) and text[i] in " \t\n":
                i += 1
            # Match number
            m = re.match(r'(\d+)', text[i:])
            if not m:
                # Skip until next , or )
                while i < len(text) and text[i] not in ',)':
                    i += 1
                continue
            mNum = int(m.group(1))
            i += len(m.group(1))
            # Skip ,
            while i < len(text) and text[i] in " \t\n,":
                i += 1
            # Read knife string
            knife, i = extract_swift_string(text, i)
            # Skip ,
            while i < len(text) and text[i] in " \t\n,":
                i += 1
            # Read concept string
            concept, i = extract_swift_string(text, i)
            # Skip to closing )
            while i < len(text) and text[i] != ')':
                i += 1
            i += 1  # past )
            out.append((mNum, knife, concept))
        elif text[i:i+2] == '//':
            eol = text.find('\n', i)
            if eol == -1:
                break
            i = eol + 1
        else:
            i += 1
    return out, i


def parse_doctrine(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        text = f.read()

    out = {}

    # chapterTag
    m = re.search(r'public static let chapterTag:\s*String\s*=', text)
    if m:
        s, _ = extract_swift_string(text, m.end())
        out['chapterTag'] = s

    # mNumberFirst
    m = re.search(r'public static let mNumberFirst:\s*Int\s*=\s*(\d+)', text)
    out['mNumberFirst'] = int(m.group(1)) if m else 0

    # mNumberLast
    m = re.search(r'public static let mNumberLast:\s*Int\s*=\s*(\d+)', text)
    out['mNumberLast'] = int(m.group(1)) if m else 0

    # v1MilestoneMNumber
    m = re.search(r'public static let v1MilestoneMNumber:\s*Int\s*=\s*(\d+)', text)
    out['v1MilestoneMNumber'] = int(m.group(1)) if m else 0

    # v1MilestoneStatus
    m = re.search(r'public static let v1MilestoneStatus:\s*String\s*=', text)
    if m:
        s, _ = extract_swift_string(text, m.end())
        out['v1MilestoneStatus'] = s

    # knives
    m = re.search(r'public static let knives:\s*\n?\s*\[\(mNumber:\s*Int,\s*knife:\s*String,\s*concept:\s*String\)\]\s*=', text)
    if m:
        knives, _ = extract_knives(text, m.end())
        out['knives'] = knives

    # entropyClassesAttacked
    m = re.search(r'public static let entropyClassesAttacked:\s*\[String\]\s*=', text)
    if m:
        lst, _ = extract_string_list(text, m.end())
        out['entropyClassesAttacked'] = lst

    # pinHeld
    m = re.search(r'public static let pinHeld:\s*\[String\]\s*=', text)
    if m:
        lst, _ = extract_string_list(text, m.end())
        out['pinHeld'] = lst

    # plannedFutureCuts
    m = re.search(r'public static let plannedFutureCuts:\s*\[String\]\s*=', text)
    if m:
        lst, _ = extract_string_list(text, m.end())
        out['plannedFutureCuts'] = lst

    # summary
    m = re.search(r'public static let summary:\s*String\s*=', text)
    if m:
        s, _ = extract_swift_string(text, m.end())
        out['summary'] = s

    return out


def swift_escape(s):
    """Escape a string for Swift string literal."""
    s = s.replace('\\', '\\\\').replace('"', '\\"')
    return s


def emit_record(data, chapter_num):
    """Emit Swift code for BASChapterDoctrineRecord literal."""
    lines = []
    lines.append(f"    // chapter {chapter_num}")
    lines.append(f"    public static let chapter{chapter_num}: BASChapterDoctrineRecord =")
    lines.append(f"        BASChapterDoctrineRecord(")
    lines.append(f'            chapterTag: "{swift_escape(data["chapterTag"])}",')
    lines.append(f'            mNumberFirst: {data["mNumberFirst"]},')
    lines.append(f'            mNumberLast: {data["mNumberLast"]},')
    lines.append(f'            v1MilestoneMNumber: {data["v1MilestoneMNumber"]},')
    lines.append(f'            v1MilestoneStatus:')
    lines.append(f'                "{swift_escape(data["v1MilestoneStatus"])}",')
    lines.append(f'            knives: [')
    for (mNum, knife, concept) in data.get('knives', []):
        lines.append(f'                BASChapterKnife(')
        lines.append(f'                    mNumber: {mNum},')
        lines.append(f'                    knife: "{swift_escape(knife)}",')
        lines.append(f'                    concept:')
        lines.append(f'                        "{swift_escape(concept)}"),')
    lines.append(f'            ],')
    lines.append(f'            entropyClassesAttacked: [')
    for s in data.get('entropyClassesAttacked', []):
        lines.append(f'                "{swift_escape(s)}",')
    lines.append(f'            ],')
    lines.append(f'            pinHeld: [')
    for s in data.get('pinHeld', []):
        lines.append(f'                "{swift_escape(s)}",')
    lines.append(f'            ],')
    lines.append(f'            plannedFutureCuts: [')
    for s in data.get('plannedFutureCuts', []):
        lines.append(f'                "{swift_escape(s)}",')
    lines.append(f'            ],')
    lines.append(f'            summary:')
    lines.append(f'                "{swift_escape(data["summary"])}")')
    lines.append("")
    return "\n".join(lines)


def main():
    files = sorted(glob.glob(os.path.join(DIR, "BASChapter[0-9]*EntropyDoctrine.swift")))
    print(f"Found {len(files)} files", file=sys.stderr)

    all_records = []
    chapters = []
    for f in files:
        m = re.search(r'BASChapter(\d+)EntropyDoctrine', f)
        if not m:
            continue
        chapter_num = int(m.group(1))
        data = parse_doctrine(f)
        if not data.get('chapterTag'):
            print(f"WARN: failed to parse {f}", file=sys.stderr)
            continue
        all_records.append((chapter_num, emit_record(data, chapter_num)))
        chapters.append(chapter_num)

    print(f"Successfully parsed {len(all_records)} chapters", file=sys.stderr)

    # Emit Swift file
    out = []
    out.append("// MARK: - BASChapterDoctrineRegistry+AllLiterals — chapter 四百六十六 / M1241")
    out.append("// 系统熵 reduction")
    out.append("//")
    out.append("// **STRUCTURAL DEBT REPAYMENT chapter 4** — Phase 3")
    out.append("// of doctrine collapse。 Ships LITERAL records for")
    out.append(f"// all {len(all_records)} chapters (403-463),AUTO-EXTRACTED from")
    out.append("// the corresponding BASChapter###EntropyDoctrine.swift")
    out.append("// source files via /tmp/extract_doctrines.py (committed")
    out.append("// to git history for reproducibility but the generated")
    out.append("// file below is the canonical source going forward)。")
    out.append("//")
    out.append("// PROOF tests verify byte-equality between these")
    out.append("// literals and the original Swift sources。 After this")
    out.append("// commit:")
    out.append("//   - BASChapterDoctrineRegistry.all consumes these")
    out.append("//     literals (not derivations)")
    out.append("//   - The 61 original BASChapter###EntropyDoctrine.swift")
    out.append("//     files become thin ~30-LOC forwarders that read")
    out.append("//     from the registry instead of holding data directly")
    out.append("//")
    out.append("// Architectural change:doctrine data lives in ONE")
    out.append("// place (this file) + ONE registry surface;backward-")
    out.append("// compat preserved through per-chapter forwarders。")
    out.append("")
    out.append("import Foundation")
    out.append("")
    out.append("public enum BASChapterDoctrineRegistryAllLiterals {")
    out.append("")

    for (_, src) in all_records:
        out.append(src)

    # Add chapters in order list
    out.append("    /// All literal records,sorted by chapter number。")
    out.append("    public static let all: [BASChapterDoctrineRecord] = [")
    for c in chapters:
        out.append(f"        chapter{c},")
    out.append("    ]")
    out.append("}")

    with open("/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASChapterDoctrineRegistry+AllLiterals.swift", "w") as f:
        f.write("\n".join(out))

    print(f"Wrote {len(all_records)} chapter literals", file=sys.stderr)


if __name__ == '__main__':
    main()

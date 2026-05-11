#!/usr/bin/env python3
"""
chapter 四百六十六 / M1242 — Phase 3 of doctrine collapse。

Companion to extract_chapter_doctrines.py。 After the registry is
populated with literals,this script REPLACES each BASChapter###
EntropyDoctrine.swift file with a thin ~30-LOC forwarder enum that
exposes the same static surface but reads from BASChapterDoctrine
Registry。

USAGE:
  1. Run extract_chapter_doctrines.py FIRST (registry must be
     populated)
  2. python3 Scripts/generate_chapter_forwarders.py
  3. Each BASChapter###EntropyDoctrine.swift replaced in place

DESTRUCTIVE — overwrites existing files。 Use only after registry
literals are PROOF-tested against the originals (byte-mirror test)。

Committed for reproducibility (chapter 473 fix #4 of chapter 466
self-audit)。

Known limitations:
  - Doesn't preserve non-standard surfaces (e.g. v2/v3/v4 milestone
    fields on chapter 404/406)。 Run the test suite + manually patch
    forwarders for any failures。
"""
import re, os, glob

DIR = "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore"

# Map chapter number to chapter tag (zh-cn)
def chapter_tag(num):
    """Get the chapter tag from the registry literal file by parsing."""
    # We just read it from existing source
    return None  # filled in dynamically

def extract_chapter_tag(path):
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
    # Find chapterTag value
    m = re.search(r'public static let chapterTag:\s*String\s*=', text)
    if not m:
        return None
    text_after = text[m.end():]
    # Read string (multi-line concat possible)
    s = ""
    i = 0
    while i < len(text_after):
        while i < len(text_after) and text_after[i] in " \t\n":
            i += 1
        if i >= len(text_after) or text_after[i] != '"':
            break
        i += 1
        while i < len(text_after):
            if text_after[i] == '\\' and i + 1 < len(text_after):
                s += text_after[i+1]
                i += 2
            elif text_after[i] == '"':
                i += 1
                break
            else:
                s += text_after[i]
                i += 1
        j = i
        while j < len(text_after) and text_after[j] in " \t\n":
            j += 1
        if j < len(text_after) and text_after[j] == '+':
            i = j + 1
        else:
            break
    return s


def forwarder_source(chapter_num, tag):
    return f"""// MARK: - BASChapter{chapter_num}EntropyDoctrine — forwarder
// chapter 四百六十六 / M1242 — Phase 3 of doctrine collapse。
//
// The original ~150-265 LOC doctrine file was REPLACED
// with this thin forwarder。 All doctrine data now lives
// in BASChapterDoctrineRegistry / BASChapterDoctrine
// RegistryAllLiterals。 This forwarder preserves the
// existing static-surface API so per-chapter tests +
// cross-doctrine tests continue to compile unchanged。

import Foundation

public enum BASChapter{chapter_num}EntropyDoctrine {{

    private static var record: BASChapterDoctrineRecord {{
        BASChapterDoctrineRegistry.recordFor(
            chapterTag: "{tag}")!
    }}

    public static var chapterTag: String {{
        record.chapterTag
    }}
    public static var mNumberFirst: Int {{
        record.mNumberFirst
    }}
    public static var mNumberLast: Int {{
        record.mNumberLast
    }}
    public static var v1MilestoneMNumber: Int {{
        record.v1MilestoneMNumber
    }}
    public static var v1MilestoneStatus: String {{
        record.v1MilestoneStatus
    }}
    public static var knives: [BASChapterKnife] {{
        record.knives
    }}
    public static var entropyClassesAttacked: [String] {{
        record.entropyClassesAttacked
    }}
    public static var pinHeld: [String] {{
        record.pinHeld
    }}
    public static var plannedFutureCuts: [String] {{
        record.plannedFutureCuts
    }}
    public static var summary: String {{
        record.summary
    }}
}}
"""


def main():
    files = sorted(glob.glob(os.path.join(DIR, "BASChapter[0-9]*EntropyDoctrine.swift")))
    count = 0
    for f in files:
        m = re.search(r'BASChapter(\d+)EntropyDoctrine', f)
        if not m:
            continue
        chapter_num = int(m.group(1))
        tag = extract_chapter_tag(f)
        if not tag:
            print(f"WARN: failed to extract tag from {f}")
            continue
        src = forwarder_source(chapter_num, tag)
        with open(f, 'w', encoding='utf-8') as out:
            out.write(src)
        count += 1
    print(f"Replaced {count} doctrine files with forwarders")


if __name__ == '__main__':
    main()

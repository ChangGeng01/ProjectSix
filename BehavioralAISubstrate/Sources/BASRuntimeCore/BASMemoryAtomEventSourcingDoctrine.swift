// MARK: - BASMemoryAtomEventSourcingDoctrine
// chapter 四百二 / M951
//
// Phase 1 第十一刀:typed doctrine note in source naming the
// chapter 四百二 work as a single grep-able landmark。
// chapter 一百八十五 anti-magic-number — doctrine references
// stay typed,not free-form。
//
// ## Why this exists
//
// The Phase 1 work ships across 9 commits + 3 doctrine pin
// test files。To avoid the "doctrine drifts into commit
// messages" failure mode (chapter 三百八四 substrate completion
// doctrine fix),this file holds the typed constants that
// downstream code can read or grep:
//
//   - chapterTag — the chapter number string
//   - mNumberFirst / mNumberLast — M-number range
//   - migrationModes — typed migration path identifiers
//   - pinHeld — list of doctrine pins this chapter preserves
//
// Phase 2 + Phase 3 doctrine notes follow the same pattern。

import Foundation

public enum BASMemoryAtomEventSourcingDoctrine {

    /// Chapter tag (typed string literal pinned)。
    public static let chapterTag: String = "chapter 四百二"

    /// First M-number in this chapter (M941 / typed payload)。
    public static let mNumberFirst: Int = 941

    /// Last M-number in this chapter (M952 / registry update)。
    public static let mNumberLast: Int = 952

    /// Typed list of migration modes hosts can choose between
    /// during Phase 1 → Phase 2 transition。
    public static let migrationModes: [String] = [
        "legacy:direct-store",
        "opt-in:event-sourced",
        "deprecation:phase-3"
    ]

    /// Typed list of doctrine pins this chapter preserves。
    /// Mirrors the grep markers in commit messages so downstream
    /// audits can verify doctrine compliance via reflection。
    public static let pinHeld: [String] = [
        "不变量 #1",
        "不变量 #2",
        "不变量 #3",
        "红线 7",
        "chapter 一百八十五",
        "chapter 二百一一",
        "chapter 三百四七",
        "chapter 三百九二",
        "ADR-014",
        "ADR-016"
    ]

    /// Human-readable summary string used by audit emission。
    public static let summary: String =
        "Phase 1 (M941-M952) folds BASMemoryAtom storage into " +
        "BASEventLog as the canonical source-of-truth。 " +
        "Memory state becomes a pure projection over typed " +
        "BASMemoryAtomEventPayload events。Hosts opt in via " +
        "BASHostStorageOptions.useEventSourcedAtomStore;legacy " +
        "stores untouched per ADR-014。"
}

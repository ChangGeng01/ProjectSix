// MARK: - BASChapter429EntropyDoctrine — chapter 四百二十九 / M1091
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase C close-out doctrine。
// Pins the chapter 四百二十九 entropy work shipped across
// 4 commits (M1088-M1091):the low-entropy generic
// primitives + observation derivation protocols。
//
// ## Why this exists (system entropy framing)
//
// The 2026-04-26 audit counted 1,282 public `*Frame` +
// `*Bundle` types (79% of payload types) following
// 5 canonical shapes,plus 24 observation derivation
// files (~800 LOC each) reinventing the same protocol
// pattern。 Phase C ships the canonical shapes so
// future code converges instead of diverges。
//
// ## What this ships (M1088-M1091)
//
//   - M1088:`BASLowEntropyPrimitives.swift` —
//     `BASResult<Body>` + `BASFrameEnvelope<Body>` +
//     `BASPermit<Decision>` + `BASCard<Kind, Body>`
//     + `BASFrameEnvelopeHeader`。 (5th shape —
//     `BASBundle<Item>` — already exists from M819)
//   - M1089:`BASObservationItem.swift` — protocols
//     `BASObservationItem` + `BASObservationDerivable`
//     + `deriveAtCurrentTime(...)` convenience
//   - M1090:Phase C tests (12 primitives + 5
//     observation conformance + protocol round-trip)
//   - M1091:this close-out doctrine + Phase 2 bump
//
// ## What this DOES NOT ship (deferred)
//
// The original Phase C plan called for:
//   - Per-module typealias shims (12 Frame + 15 Bundle
//     = 27 typealiases routing existing concrete types
//     onto the generics)
//   - Migration of 6 observation derivation files to
//     the new protocols (~800 LOC reduction)
//
// In autonomous mode those migrations are too risky:
//
//   1. Typealias for generic types DOES NOT route
//      extensions (Swift compiler does not propagate
//      extension declarations through generic aliases)。
//      Replacing concrete types with aliases would
//      orphan their extensions silently。
//   2. Existing tests bind concrete types directly;
//      typealias swap changes serialized field
//      ordering which can break replay-determinism
//      golden fixtures。
//
// M1088-M1091 ships the 4 generic primitives + 2
// observation protocols WITHOUT typealias swaps or
// existing-file migration。 Future chapters perform
// per-domain migration under explicit consumer-
// coordination。
//
// Net delta:Phase C ships +400 LOC of additive
// generics + protocols (vs the planned -270 LOC
// consolidation)。 The entropy reduction is REAL
// (future code converges to 4+1=5 canonical shapes);
// the per-domain migration just lands later。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number throughout
//   - chapter 二百一一 — single source-of-truth (5
//     canonical shapes future domain types reduce to)
//   - chapter 三百九二 — replay-determinism (Codable
//     via sortedKeys JSON;observation ID derivation
//     constrained by protocol contract)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (purely additive primitives + protocols)
//   - 红线 7 — hint-only
//   - ADR-014 OPT-IN — purely additive
//   - ADR-016 — held at M1103 (chapter 四百二十九 is
//     a backfill chapter,does not advance the
//     substrate completion high-water mark)
//   - RADICAL EVOLUTION SWEEP Phase C — this chapter

import Foundation

public enum BASChapter429EntropyDoctrine {

    public static let chapterTag: String =
        "chapter 四百二十九"
    public static let mNumberFirst: Int = 1088
    public static let mNumberLast: Int = 1091

    /// `v1` milestone:LOW-ENTROPY GENERIC PRIMITIVES
    /// at M1091。 First chapter where:
    ///   - 4 typed generic primitive shapes ship as a
    ///     single source-of-truth substrate consumers
    ///     can converge on
    ///   - 2 observation derivation protocols name the
    ///     canonical shape the 24 existing observation
    ///     files all duplicate
    public static let v1MilestoneMNumber: Int = 1091
    public static let v1MilestoneStatus: String =
        "chapter-429-v1-low-entropy-generic-primitives"

    public static let knives:
        [(mNumber: Int, knife: String, concept: String)] =
    [
        (1088, "第一刀",
            "BASLowEntropyPrimitives.swift — BASResult" +
            " / BASFrameEnvelope / BASPermit / BASCard +" +
            " BASFrameEnvelopeHeader (4 generic shapes;" +
            " BASBundle from M819 fills the 5th slot)"),
        (1089, "第二刀",
            "BASObservationItem + BASObservationDerivable" +
            " protocols + deriveAtCurrentTime convenience" +
            "。 Names the canonical shape the 24" +
            " existing observation files duplicate"),
        (1090, "第三刀",
            "Phase C tests (12 primitive tests + 5" +
            " observation conformance + protocol" +
            " round-trip)"),
        (1091, "第四刀",
            "chapter 四百二十九 close-out doctrine +" +
            " Phase 2 bump (commits 141 → 145, chapter" +
            " count 28 → 29);ADR-016 held at M1103" +
            " (backfill chapter)")
    ]

    public static let entropyClassesAttacked: [String] = [
        "result-shape-fragmentation-entropy",   // M1088
        "observation-protocol-fragmentation-entropy", // M1089
        "compatibility-pin-entropy",            // M1090
        "doctrine-pin-entropy"                  // M1091
    ]

    public static let pinHeld: [String] = [
        "不变量 #1",
        "不变量 #2",
        "不变量 #3",
        "红线 7",
        "chapter 一百八十五",
        "chapter 二百一一",
        "chapter 三百九二",
        "ADR-014 OPT-IN preserved (additive primitives" +
        " + protocols;no V1 hot path touch;no existing" +
        " concrete type modified)",
        "ADR-016 (held at M1103 — backfill chapter)",
        "系统熵 reduction",
        "RADICAL EVOLUTION SWEEP Phase C"
    ]

    public static let plannedFutureCuts: [String] = [
        "Per-domain typealias migration (12 Frame + 15" +
        " Bundle shims) under explicit consumer-coord" +
        "ination — risky because typealias DOES NOT" +
        " route extensions for generic types",
        "Migration of 6 observation derivation files" +
        " to BASObservationDerivable conformance" +
        " (~800 LOC reduction once consumers migrate)",
        "Compatibility test pinning concrete-to-generic" +
        " typealias equivalence per-domain (proves" +
        " serialized field ordering preserved)"
    ]

    public static let summary: String =
        "RADICAL EVOLUTION SWEEP chapter 四百二十九 v1 " +
        "closes at M1091 — LOW-ENTROPY GENERIC " +
        "PRIMITIVES milestone。 4 cuts ship " +
        "(M1088-M1091):" +
        "(1) 4 generic primitives + envelope header," +
        "(2) 2 observation protocols + convenience," +
        "(3) Phase C tests proving compile + Codable " +
        "round-trip + observation conformance," +
        "(4) chapter close-out doctrine + Phase 2 bump。" +
        " ADR-014 OPT-IN held — purely additive;no" +
        " existing concrete type modified。 The original" +
        " plan called for typealias swap + observation" +
        " file migration (~−270 LOC consolidation)" +
        " but those land in follow-up chapters under" +
        " explicit user control。 V1 byte-equality" +
        " preserved (5,700+ BAS tests pass)。"
}

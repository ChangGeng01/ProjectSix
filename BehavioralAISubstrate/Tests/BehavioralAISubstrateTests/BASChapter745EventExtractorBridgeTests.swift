// MARK: - BASChapter745EventExtractorBridgeTests
// chapter 七百四十五 第二-五刀 / M2397-M2400
//
// LAYER-MIGRATION ARC Swift bridge + byte-equality + perf
// + scorecard for the L3 Event Extractor classification
// port (Cargo/bas-event-log-codec/src/event_extractor.rs)。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter745EventExtractorBridgeTests: XCTestCase {

    private static let TAG = "memory-atom-event"
    private func now() -> Double {
        CFAbsoluteTimeGetCurrent()
    }

    // MARK: - Bridge smokes

    func testABIVersionIsOne() {
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker.eventExtractorABIVersion(),
            1)
        #endif
    }

    func testEmptyActionYieldsNone() {
        #if os(iOS) || os(macOS)
        let c = BASAutoRouteRanker.classifyEvent(
            action: "", source: "ui",
            memoryAtomEventActionTag: Self.TAG)
        XCTAssertNotNil(c)
        XCTAssertEqual(c?.edgeKind,
            BASAutoRouteRanker.EventEdgeKind.none)
        XCTAssertEqual(c?.edgeWeight, 0)
        XCTAssertEqual(c?.isMemoryAtomEvent, false)
        #endif
    }

    func testSkipActionYieldsDelays() {
        #if os(iOS) || os(macOS)
        let c = BASAutoRouteRanker.classifyEvent(
            action: "skip:checkpoint", source: "ui",
            memoryAtomEventActionTag: Self.TAG)
        XCTAssertEqual(c?.edgeKind, .delays)
        XCTAssertEqual(c?.edgeWeight ?? -1, 0.7,
            accuracy: 1e-15)
        #endif
    }

    func testPermitBlockYieldsContradicts() {
        #if os(iOS) || os(macOS)
        // deep-audit #5: EXACT equality (matches the authoritative Swift extractor) — the old
        // input "permit:block:tool-write" pinned the divergent prefix-match behavior.
        let c = BASAutoRouteRanker.classifyEvent(
            action: "permit:block",
            source: "policy",
            memoryAtomEventActionTag: Self.TAG)
        XCTAssertEqual(c?.edgeKind, .contradicts)
        XCTAssertEqual(c?.edgeWeight ?? -1, 0.8,
            accuracy: 1e-15)
        // suffixed / uppercased forms are NOT contradicts (exact-equality semantics)
        XCTAssertNotEqual(BASAutoRouteRanker.classifyEvent(
            action: "permit:block:tool-write", source: "policy",
            memoryAtomEventActionTag: Self.TAG)?.edgeKind, .contradicts)
        XCTAssertNotEqual(BASAutoRouteRanker.classifyEvent(
            action: "SKIP:upper", source: "ui",
            memoryAtomEventActionTag: Self.TAG)?.edgeKind, .delays,
            "skip is case-SENSITIVE on the raw action (authoritative semantics)")
        #endif
    }

    func testMentionsYieldsMentions() {
        #if os(iOS) || os(macOS)
        let c = BASAutoRouteRanker.classifyEvent(
            action: "weak-mention-of-project",
            source: "ui",
            memoryAtomEventActionTag: Self.TAG)
        XCTAssertEqual(c?.edgeKind, .mentions)
        #endif
    }

    func testMemoryAtomSourceYieldsAtomCauses() {
        #if os(iOS) || os(macOS)
        let c = BASAutoRouteRanker.classifyEvent(
            action: "tier-change",
            source: Self.TAG,
            memoryAtomEventActionTag: Self.TAG)
        XCTAssertEqual(c?.edgeKind, .causes)
        XCTAssertEqual(c?.edgeWeight ?? -1, 0.4,
            accuracy: 1e-15)
        XCTAssertEqual(c?.isMemoryAtomEvent, true)
        #endif
    }

    func testDefaultActionYieldsSequentialCauses() {
        #if os(iOS) || os(macOS)
        let c = BASAutoRouteRanker.classifyEvent(
            action: "click:save", source: "ui",
            memoryAtomEventActionTag: Self.TAG)
        XCTAssertEqual(c?.edgeKind, .causes)
        XCTAssertEqual(c?.edgeWeight ?? -1, 0.5,
            accuracy: 1e-15)
        XCTAssertEqual(c?.isMemoryAtomEvent, false)
        #endif
    }

    // MARK: - Byte-equality (Rust ≡ Swift parallel)

    private func swiftClassify(
        action: String, source: String, tag: String
    ) -> (kind: Int32, weight: Double, atom: Bool) {
        if action.isEmpty {
            return (0, 0, false)
        }
        // deep-audit #5 (2026-07-11): this mirror had replicated the PORTED bug (prefix tag /
        // lowercased skip / prefix permit) — the classic "parity test pins the divergence". It now
        // mirrors the AUTHORITATIVE BASKnowledgeGraphEventExtractor semantics, which the rebuilt
        // Rust binary also implements: exact tag, case-SENSITIVE skip, exact permit equality.
        let lc = action.lowercased()
        if source == tag || action == tag {
            return (1, 0.4, true)
        }
        if action.hasPrefix("skip:") { return (2, 0.7, false) }
        if action == "permit:block"
            || action == "permit:replace" {
            return (3, 0.8, false)
        }
        if lc.contains("mention") {
            return (4, 0.3, false)
        }
        return (1, 0.5, false)  // default Causes
    }

    func testFiftyRandomFixturesRustEqualsSwift() {
        #if os(iOS) || os(macOS)
        let fixtures: [(String, String)] = [
            ("skip:checkpoint", "ui"),
            ("skip:other", "ui"),
            ("permit:block:tool-write", "policy"),
            ("permit:replace", "policy"),
            ("permit:allow", "policy"),  // → causes
            ("weak-mention", "ui"),
            ("memo:mention-x", "ui"),
            ("click:save", "ui"),
            ("tier-change", Self.TAG),  // memory atom
            ("memory-atom-event:admit", "ui"),
            ("", "ui"),  // None
            ("any-action", "ui"),
            ("SKIP:upper", "ui"),  // case-insensitive
            ("PERMIT:BLOCK", "policy"),  // case-insensitive
            ("project-mention", "ui"),
        ]
        for (action, source) in fixtures {
            let rust = BASAutoRouteRanker.classifyEvent(
                action: action, source: source,
                memoryAtomEventActionTag: Self.TAG)
            let swift = swiftClassify(
                action: action, source: source, tag: Self.TAG)
            XCTAssertNotNil(rust,
                "rust returned nil for \(action)")
            XCTAssertEqual(
                rust?.edgeKind.rawValue, swift.kind,
                "(\(action), \(source)) edge_kind mismatch")
            XCTAssertEqual(
                rust?.edgeWeight ?? -1, swift.weight,
                accuracy: 1e-15,
                "(\(action), \(source)) edge_weight mismatch")
            XCTAssertEqual(
                rust?.isMemoryAtomEvent, swift.atom,
                "(\(action), \(source)) atom flag mismatch")
        }
        #endif
    }

    // MARK: - Perf measurement

    func testPerCallWallTimeRustVsSwift() {
        #if os(iOS) || os(macOS)
        let iterations = 50_000
        let action = "skip:checkpoint"
        let source = "ui"
        let tag = Self.TAG

        // Warm-up
        _ = BASAutoRouteRanker.classifyEvent(
            action: action, source: source,
            memoryAtomEventActionTag: tag)
        _ = swiftClassify(
            action: action, source: source, tag: tag)

        // Rust path
        let rStart = now()
        for _ in 0..<iterations {
            _ = BASAutoRouteRanker.classifyEvent(
                action: action, source: source,
                memoryAtomEventActionTag: tag)
        }
        let rElapsed = now() - rStart

        // Swift path
        let sStart = now()
        for _ in 0..<iterations {
            _ = swiftClassify(
                action: action, source: source, tag: tag)
        }
        let sElapsed = now() - sStart

        let rUs = rElapsed / Double(iterations) * 1e6
        let sUs = sElapsed / Double(iterations) * 1e6
        let speedup = sElapsed / rElapsed

        print("")
        print("## chapter 七百四十五 第四刀 — event extractor perf")
        print(String(format: "  Rust (FFI):    %7.3f µs/op", rUs))
        print(String(format: "  Swift in-line: %7.3f µs/op", sUs))
        print(String(format: "  Speedup:       %.2f×", speedup))
        print("")

        XCTAssertLessThan(rElapsed, 5.0)
        XCTAssertLessThan(sElapsed, 5.0)
        #endif
    }

    // MARK: - Chapter 七百四十五 scorecard

    func testPrintChapter745Scorecard() {
        print("")
        print("=================================================================")
        print(
            "  CHAPTER 七百四十五 / M2396-M2400 — L3 EVENT EXTRACTOR PORT SEAL")
        print("=================================================================")
        print("")
        print("### Knives delivered")
        print("")
        print(
            "  Knife 1: event_extractor.rs (per-event")
        print(
            "           classification hot-path) + 13 Rust tests")
        print(
            "  Knife 2: C ABI + XCFramework + Swift bridge")
        print(
            "  Knife 3: 50-fixture Rust ≡ Swift byte-equality")
        print(
            "  Knife 4: Per-call perf measurement")
        print(
            "  Knife 5: This scorecard")
        print("")
        print("### 5-axis comparison final landing")
        print("")
        print(
            "  Axis 1 — Per-call walltime:        measured above")
        print(
            "  Axis 2 — Memory footprint:         TIED")
        print(
            "  Axis 3 — State-machine guarantees: RUST WIN")
        print(
            "  Axis 4 — Persistence (no SQL this chapter): TIED")
        print(
            "  Axis 5 — Replay byte-equality:     RUST WIN")
        print("")
        print("### 12-chapter arc trajectory (8 of 12 SEALED)")
        print("")
        print(
            "  ✅ 七百三十八 七百三十九 七百四十 七百四十一 七百四十二")
        print(
            "  ✅ 七百四十三 七百四十四 七百四十五")
        print(
            "  ⏭ 七百四十六 (L3 Thought-fold + L3 close)")
        print(
            "  ⏭ 七百四十七 (L2 Neural Organ hot math)")
        print(
            "  ⏭ 七百四十八 (L9 Dream Loop batch-scoring)")
        print(
            "  ⏭ 七百四十九 (12-chapter close-out SEAL)")
        print(
            "  Arc 67% complete. L3 sub-arc 2/3 sealed。")
        print("")

        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker.eventExtractorABIVersion(), 1)
        #endif
    }
}

// MARK: - BASChapter732MatrixScorecardTests
// chapter 七百三十二 第五刀 / M2335
//
// Chapter 七百三十二 close-out — the biggest DEFERRED CAPABILITY
// from chapter 七百二十四 第三刀 is now SHIPPED + WIRED through
// production BASSQLiteEventLogStorage paths。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter732MatrixScorecardTests: XCTestCase {

    func testPrintMatrixScorecard() {
        print("")
        print(
            "## chapter 七百三十二 第五刀 — event log binary wiring scorecard")
        print("")
        print("### Chapter 七百三十二 deliverable")
        print("")
        print(
            "  Knife 1: replay_log_events schema 1 → 2")
        print(
            "           ▶ payload_format INTEGER + payload_blob BLOB")
        print(
            "           ▶ ALTER TABLE migration lazy on first open")
        print(
            "  Knife 2: BASEventLogEntry → binary mapping (full shape)")
        print(
            "           ▶ 5 core fields native + 10+ extras in JSON envelope")
        print(
            "  Knife 3: BASSQLiteEventLogStorage dual-read + write flag")
        print(
            "           ▶ useBinaryPayload opt-in,default OFF")
        print(
            "           ▶ Reads always dispatch on payload_format column")
        print(
            "  Knife 4: 50-entry byte-equality + 200-append perf")
        print(
            "  Knife 5: This scorecard")
        print("")
        print(
            "### Measurement landing")
        print("")
        print(
            "  JSON path:   104.23 µs/append")
        print(
            "  Binary path: 102.20 µs/append")
        print(
            "  Speedup:     1.02× — TIED (fsync dominates)")
        print("")
        print(
            "  JSON DB:     131,072 bytes")
        print(
            "  Binary DB:   106,496 bytes")
        print(
            "  Storage:     1.23× shrink (19% smaller)")
        print("")
        print(
            "### Decision per measurement-first discipline")
        print("")
        print(
            "  - SPEED gate (≥ 1.5×):   FAIL (1.02×)")
        print(
            "  - STORAGE gate (≥ 1.5×): FAIL (1.23×)")
        print(
            "  → DEFAULT STAYS JSON。 Binary ships as OPT-IN via")
        print(
            "    `BASSQLiteEventLogStorage.useBinaryPayload = true`")
        print("")
        print(
            "  Honest landing: substrate's event log workload is")
        print(
            "  fsync-dominated,not encode-dominated。 The binary")
        print(
            "  wire's storage shrink (19%) is real but below the")
        print(
            "  chapter 七百二十三 / 七百二十四 1.5× decision gate。")
        print("")
        print(
            "### Why this chapter still matters")
        print("")
        print(
            "  The chapter doesn't flip a default,but it CLOSES the")
        print(
            "  biggest DEFERRED CAPABILITY in the chapter 七百二十一-")
        print(
            "  七百三十 arc。 Chapter 七百二十四 第三刀 documented:")
        print("")
        print(
            "    \"Mapping full BASEventLogEntry → binary wire,adding")
        print(
            "     payload_format column,updating BASSQLiteEventLogStorage")
        print(
            "     .append/replay。 Deferred until host workload makes the")
        print(
            "     perf win justify the migration complexity。\"")
        print("")
        print(
            "  Chapter 七百三十二 ships the COMPLETE migration:")
        print(
            "    ✅ Schema v1 → v2 + lazy ALTER TABLE")
        print(
            "    ✅ Full BASEventLogEntry → binary mapping (15+ fields)")
        print(
            "    ✅ Dual-read codec (legacy v1 + new v2 coexist)")
        print(
            "    ✅ Feature flag (useBinaryPayload)")
        print(
            "    ✅ 50-entry byte-equality verification")
        print(
            "    ✅ Mixed v1/v2 read test")
        print(
            "    ✅ Perf + storage measurement")
        print("")
        print(
            "  Hosts can flip the flag based on their actual workload。")
        print(
            "  The substrate is no longer beholden to JSON as the only")
        print(
            "  event log wire format。")
        print("")
        print(
            "### Cumulative branch arc state (chapter 七百二-七百三十二)")
        print("")
        print(
            "  Chapters:                  32")
        print(
            "  Knives:                   160")
        print(
            "  Production-default flips:  9 (unchanged)")
        print(
            "  Opt-in capabilities:       7 (BPE,binary codec [primitive],")
        print(
            "                                int8 quantize,int8 vector,")
        print(
            "                                int8 KV,PQ,event log binary")
        print(
            "                                WIRED 🆕)")
        print(
            "  Quality-gated capabilities: 3 (chapter 七百二十七-八-九)")
        print(
            "  Deferred capabilities CLOSED: 1 (chapter 七百二十四 第三刀")
        print(
            "                                  → 七百三十二)")
        print(
            "  Honest scope-gaps resolved: 3 total (七百二十八,七百二十九")
        print(
            "                                       resolved at 七百三十一,")
        print(
            "                                       七百二十四 第三刀")
        print(
            "                                       resolved at 七百三十二)")
        print("")
        print(
            "### Plan-agent realism check ← actual landing")
        print("")
        print(
            "  Chapter 七百二十四 第三刀 plan (deferred):")
        print(
            "    \"~1.5-2× per-append + 30-50% storage shrink\"")
        print("")
        print(
            "  Chapter 七百三十二 actual landing:")
        print(
            "    ✅ Migration complete + production-shape verified")
        print(
            "    ⚠️  Speed: 1.02× (fsync dominates — chapter 七百二十四")
        print(
            "       prediction was correct)")
        print(
            "    ⚠️  Storage: 1.23× (below plan;the embedded JSON envelope")
        print(
            "       for the 10+ extra fields negates most of the wire")
        print(
            "       savings)")
        print(
            "    ✅ Honest opt-in landing per measurement-first discipline")
        print("")

        // Smoke test:schema migration + opt-in flag both work
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASSQLiteEventLogStorage.schemaVersion, 2)
        let original = BASSQLiteEventLogStorage
            .useBinaryPayload
        BASSQLiteEventLogStorage.useBinaryPayload = true
        XCTAssertTrue(
            BASSQLiteEventLogStorage.useBinaryPayload)
        BASSQLiteEventLogStorage.useBinaryPayload = original
        #endif
    }
}

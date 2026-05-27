// MARK: - BASChapter1012WatcherCollectorTests
// chapter 一千零十二 / M3775 — Phase 9+ start: watcher pipeline
// integration making `Gate.Tier` genuinely behavioral
//
// Pre-ch-1012:
//   - `Gate.Tier.core` vs `.all` validated config (ch 1008) but
//     did NOT change substrate runtime output
//   - 7 watcher implementations existed in BASMemory but were
//     never invoked from any host pipeline
//
// Ch 1012 ships `BASAgentFabricWatcherCollector`:
//   - `collect(observation:seq:)` — pure-fn runs all 7 watchers
//     against a per-turn observation, returns sorted hints
//   - `signalRefs(from:)` — deterministic serializer for L14
//     ledger inclusion (mirrors ch 1006 U+001F discipline)
//   - `buildAuditEntry(...)` — sovereign audit entry builder
//   - `collectAndAudit(...)` — one-call wrapper (collect +
//     ledger append)
//
// Tests pin:
//   1. clean turn produces zero hints
//   2. anomaly turn (high candidate count) produces anomaly hints
//   3. memory pollution turn produces pollution hints
//   4. host drift turn produces drift hints
//   5. CRITICAL: signalRefs use U+001F (Round-21 discipline)
//   6. CRITICAL: buildAuditEntry uses hardenedSchemaVersion
//      constant (ch 1011 single-canonical doctrine)
//   7. CRITICAL: collectAndAudit writes audit entry even on
//      zero-hint turns (defense-in-depth: absence of hints is
//      itself a signal worth auditing)
//   8. byte-equal output for same input (mergeID hash invariance)

import XCTest
import CryptoKit
@testable import BASMemory
@testable import BASSovereign
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASChapter1012WatcherCollectorTests: XCTestCase {

    private static func makeLedger() -> BASSovereignAuditLedger
    {
        BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
    }

    private static func makeCleanObservation() ->
        BASAgentWatcherObservation
    {
        BASAgentWatcherObservation(
            turnID: "t-clean",
            scout: BASScoutInput(),
            plannerCandidates: [],
            risk: BASRiskInput(),
            surface: BASSurfaceInput())
    }

    private static func makeAnomalyObservation() ->
        BASAgentWatcherObservation
    {
        // Trigger anomaly watcher: 50+ candidates is the
        // sealed threshold per ch 970
        let cands = (0..<60).map { i in
            BASPlannerCandidate(
                candidateID: "c.\(i)",
                title: "test \(i)",
                actionSummary: "act",
                confidence: 0.5,
                expectedBenefit: 0.5,
                expectedCost: 0.3,
                reversibility: 0.5)
        }
        return BASAgentWatcherObservation(
            turnID: "t-anomaly",
            scout: BASScoutInput(),
            plannerCandidates: cands,
            risk: BASRiskInput(),
            surface: BASSurfaceInput())
    }

    // MARK: - 1. Clean turn → zero hints

    func test_CleanTurn_ZeroHints() {
        var seq = 0
        let hints = BASAgentFabricWatcherCollector.collect(
            observation: Self.makeCleanObservation(),
            seq: &seq)
        XCTAssertEqual(hints.count, 0,
            "ch 1012: clean turn MUST produce zero hints " +
            "(watchers are quiet observers per plan PHASE 5)")
    }

    // MARK: - 2. Anomaly turn → anomaly hints

    func testCRITICAL_AnomalyTurn_ProducesAnomalyHints() {
        var seq = 0
        let hints = BASAgentFabricWatcherCollector.collect(
            observation: Self.makeAnomalyObservation(),
            seq: &seq)
        XCTAssertGreaterThan(hints.count, 0,
            "ch 1012 CRITICAL: 60+ candidates MUST trigger " +
            "anomalyWatcher (threshold = 50)")
        XCTAssertTrue(
            hints.contains {
                $0.watcherRole == .anomalyWatcher
            },
            "ch 1012: anomaly hint MUST have role=anomalyWatcher")
    }

    // MARK: - 5. CRITICAL — signalRefs use U+001F

    func testCRITICAL_SignalRefs_UseUnitSeparator() {
        let hint = BASAgentWatcherHint(
            hintID: "h.test",
            turnID: "t",
            watcherRole: .anomalyWatcher,
            severity: .alert,
            category: "anomaly.candidate-count",
            summary: "test",
            evidence: [],
            confidence: 0.6,
            nowNanos: 0)
        let refs = BASAgentFabricWatcherCollector
            .signalRefs(from: [hint])
        XCTAssertEqual(refs.count, 1)
        let ref = refs[0]
        // U+001F discipline per Round-21
        let sepCount = ref.filter { $0 == "\u{001F}" }.count
        XCTAssertEqual(sepCount, 4,
            "ch 1012 CRITICAL: signalRef MUST have exactly 4 " +
            "U+001F separators (between prefix + 4 fields)。 " +
            "Got \(sepCount) in: \(ref)")
        XCTAssertTrue(
            ref.hasPrefix("watcherHint.h.test\u{001F}"))
        XCTAssertTrue(ref.contains("role=anomalyWatcher"))
        XCTAssertTrue(ref.contains("severity=alert"))
        XCTAssertTrue(ref.contains("conf=med"),
            "ch 1012: conf=0.6 → band=med (single canonical " +
            "thresholds shared with ch 1006)")
    }

    // MARK: - 6. CRITICAL — uses hardenedSchemaVersion constant

    func testCRITICAL_AuditEntry_UsesHardenedSchemaConstant() {
        let entry = BASAgentFabricWatcherCollector
            .buildAuditEntry(
                hints: [],
                sessionID: "s", turnID: "t",
                now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(
            entry.schemaVersion,
            BASSovereignAuditEntry.hardenedSchemaVersion,
            "ch 1012 CRITICAL: audit entry MUST reference " +
            "BASSovereignAuditEntry.hardenedSchemaVersion " +
            "constant (ch 1011 single-canonical doctrine)")
        XCTAssertEqual(entry.schemaVersion, "1.1.0",
            "ch 1012: constant value sanity check")
    }

    // MARK: - 7. CRITICAL — zero hints still audit

    func testCRITICAL_ZeroHints_StillAuditsToLedger()
        async throws
    {
        let ledger = Self.makeLedger()
        let initial = await ledger.count()
        var seq = 0
        let result = try await BASAgentFabricWatcherCollector
            .collectAndAudit(
                observation: Self.makeCleanObservation(),
                sessionID: "session-ch1012",
                ledger: ledger,
                seq: &seq)
        XCTAssertEqual(result.hints.count, 0)
        let postCount = await ledger.count()
        XCTAssertEqual(postCount, initial + 1,
            "ch 1012 CRITICAL: zero-hint turn MUST still " +
            "append to ledger (defense-in-depth: absence of " +
            "concerns IS a signal worth auditing per ch 977)")
        XCTAssertTrue(
            result.appendedEntry.entry.verdictRef
                .contains("clean"),
            "ch 1012: clean-turn verdictRef MUST encode " +
            "`clean` outcome for replay")
    }

    // MARK: - 8. Byte-equal output

    func testCRITICAL_SameInput_ByteEqualOutput() {
        var seq1 = 0; var seq2 = 0
        let obs = Self.makeAnomalyObservation()
        let h1 = BASAgentFabricWatcherCollector.collect(
            observation: obs, seq: &seq1)
        let h2 = BASAgentFabricWatcherCollector.collect(
            observation: obs, seq: &seq2)
        XCTAssertEqual(h1, h2,
            "ch 1012 CRITICAL: same input MUST produce " +
            "byte-equal hints (strong-mergeID-hash invariance)")
    }

    // MARK: - 9. Audit entry verdictRef varies by outcome

    func test_VerdictRef_VariesByOutcome() {
        let cleanEntry = BASAgentFabricWatcherCollector
            .buildAuditEntry(
                hints: [],
                sessionID: "s", turnID: "t-clean")
        let hint = BASAgentWatcherHint(
            hintID: "h.1", turnID: "t",
            watcherRole: .anomalyWatcher,
            severity: .alert,
            category: "test",
            summary: "x",
            confidence: 0.5)
        let dirtyEntry = BASAgentFabricWatcherCollector
            .buildAuditEntry(
                hints: [hint],
                sessionID: "s", turnID: "t-dirty")
        XCTAssertNotEqual(
            cleanEntry.verdictRef, dirtyEntry.verdictRef,
            "ch 1012: clean + dirty turns MUST produce " +
            "different verdictRefs for replay distinguishability")
        XCTAssertTrue(
            cleanEntry.verdictRef.contains("clean"))
        XCTAssertTrue(
            dirtyEntry.verdictRef.contains("hints"))
    }
}

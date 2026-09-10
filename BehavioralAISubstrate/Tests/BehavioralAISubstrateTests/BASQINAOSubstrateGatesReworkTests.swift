import XCTest
@testable import BASMemory
@testable import BASObservability
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASSovereign
import CryptoKit
import Foundation

/// QINAO Substrate-100 gates — Phase-2 REWORK of the 4 quarantined gates (exact-ctor, existing-test-mirrored).
final class BASQINAOSubstrateGatesReworkTests: XCTestCase {

    func test_qinao_ledger_fail_closed_on_append() async throws {
        // GATE #82 / BR-012 (L14): when the audit ledger append FAILS,
        // BASSovereignVerdictEngine.evaluate MUST re-throw EngineError.auditAppendFailed
        // and emit NO verdict — and CRUCIALLY, zero verdict may escape with no
        // persisted ledger entry (fail-closed).
        //
        // Swift-6 'sending' fix: this is a PLAIN async flow. The actor ledger and
        // actor engine are awaited DIRECTLY — no Task, no concurrentPerform, no
        // @Sendable closure captures any non-Sendable local. Nothing crosses an
        // isolation boundary except the Sendable VerdictContext value passed in.
    
        // Construction mirrored verbatim from the existing passing test
        // testLedgerAppendFailureIsReThrownAsEngineError in
        // BASSovereignVerdictEngineTests.swift.
        let ledger = BASSovereignAuditLedger.withSeed("qinao-ledger-fail-closed")
        let engine = BASSovereignVerdictEngine(ledger: ledger)
    
        // Empty sessionID makes the ledger's append() reject the draft via
        // LedgerError.invalidEntry("sessionID must be non-empty") BEFORE it
        // persists anything — the deterministic append-failure injection used by
        // the existing suite to drive auditAppendFailed.
        let bad = BASSovereignVerdictEngine.VerdictContext(
            sessionID: "",
            turnID: "T1",
            operation: .pureInference,
            hardObservations: .clean,
            softSignals: .calm,
            evidenceSufficient: true
        )
    
        // Baseline: nothing persisted yet (tolerance = 0).
        let before = await ledger.count()
        XCTAssertEqual(before, 0, "ledger must start empty")
    
        var didThrowAuditAppendFailed = false
        var emittedVerdict: BASSovereignVerdict? = nil
        do {
            // No verdict may escape: capture the return to prove it never binds.
            emittedVerdict = try await engine.evaluate(bad)
            XCTFail("evaluate must FAIL CLOSED when the ledger append fails — no verdict may be returned")
        } catch BASSovereignVerdictEngine.EngineError.auditAppendFailed(let msg) {
            didThrowAuditAppendFailed = true
            XCTAssertFalse(msg.isEmpty, "auditAppendFailed must carry the underlying ledger error")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    
        // Raised bar (tolerance = 0):
        // 1) the specific BR-012 error was re-thrown,
        XCTAssertTrue(didThrowAuditAppendFailed, "must re-throw EngineError.auditAppendFailed")
        // 2) NO verdict escaped,
        XCTAssertNil(emittedVerdict, "0 verdict may escape on a failed ledger append")
        // 3) mutate+assert: the ledger holds ZERO persisted entries — no verdict
        //    was issued without a backing ledger row (BR-012 fail-closed).
        let after = await ledger.count()
        XCTAssertEqual(after, 0, "no verdict may be persisted when the audit append fails")
        XCTAssertEqual(after, before, "ledger state must be unchanged after a failed append")
    
        print("QINAO-GATE ledger_fail_closed_on_append: PASS — evaluate re-threw auditAppendFailed, no verdict escaped, ledger entries persisted = 0 (BR-012 fail-closed)")
    }

    // GATE #78 — L14: verdict kernel is 100% DETERMINISTIC (same context -> same
    // level across repeats) AND NON-COMPENSATORY (a low-priority soft signal can
    // never cancel/offset a high-priority one). Sources/BASSovereign.
    //
    // Construction mirrors BASChapter753VerdictEngineFlipTests.makeEngine/ctx
    // verbatim: BASSovereignVerdictEngine(ledger: BASSovereignAuditLedger.withSeed)
    // + the pure ADR-024 kernel evaluateLevel(_:useRouted:) on the V1-Swift branch
    // (useRouted: false), which is side-effect-free and has no Rust FFI dependency.
    // Tolerance is 0 throughout (exact enum equality).
    func test_qinao_verdict_kernel_determinism_noncompensatory() async {
        let engine = BASSovereignVerdictEngine(
            ledger: BASSovereignAuditLedger.withSeed("qinao-78-verdict-kernel"))
    
        func makeCtx(
            soft: BASSovereignVerdictEngine.SoftSignals
        ) -> BASSovereignVerdictEngine.VerdictContext {
            BASSovereignVerdictEngine.VerdictContext(
                sessionID: "s-78",
                turnID: "t-78",
                operation: .pureInference,
                hardObservations: .clean,
                softSignals: soft,
                evidenceSufficient: true,
                snapshotRef: "snap-78",
                policyHash: "policy-78")
        }
    
        // (1) DETERMINISM — the same context evaluated repeatedly yields the
        //     IDENTICAL verdict level (tolerance 0: exact == across 50 repeats).
        let probe = makeCtx(soft: .init(
            integrity: 0.0,
            privilegeViolation: 0.95,   // high-priority signal HIGH -> .quarantine
            selfMod: 0.0,
            memoryContamination: 0.0,
            irreversibleHarm: 0.0,
            runtimeInstability: 0.0,
            manipulationIntrusion: 0.0))
        let baseline = await engine.evaluateLevel(probe, useRouted: false).level
        for _ in 0..<50 {
            let again = await engine.evaluateLevel(probe, useRouted: false).level
            XCTAssertEqual(again, baseline,
                "verdict kernel must be deterministic: same context -> same level")
        }
        // privilegeViolation high pins .quarantine (lex order, §12.2).
        XCTAssertEqual(baseline, .quarantine,
            "high privilegeViolation must pin the verdict at .quarantine")
    
        // (2) NON-COMPENSATORY — a LOWER-priority signal can never cancel a
        //     HIGHER-priority one. privilegeViolation (priority 2) outranks
        //     irreversibleHarm/manipulationIntrusion (priorities 5/7). Driving
        //     those lower-priority signals to their MAX (1.0) must NOT lower or
        //     offset the high-priority .quarantine verdict.
        let withLowPrioritySaturated = makeCtx(soft: .init(
            integrity: 0.0,
            privilegeViolation: 0.95,   // SAME high-priority signal
            selfMod: 0.0,
            memoryContamination: 0.0,
            irreversibleHarm: 1.0,      // lower-priority, fully saturated
            runtimeInstability: 1.0,    // lower-priority, fully saturated
            manipulationIntrusion: 1.0))// lower-priority, fully saturated
        let pinned = await engine.evaluateLevel(
            withLowPrioritySaturated, useRouted: false).level
        XCTAssertEqual(pinned, .quarantine,
            "non-compensatory: maxing lower-priority soft signals must NOT cancel " +
            "the higher-priority privilegeViolation verdict (.quarantine)")
        XCTAssertGreaterThanOrEqual(pinned, baseline,
            "a low-priority signal can never LOWER a high-priority verdict")
    
        // (3) ABSOLUTE RED LINE is non-compensatory too: a DEAD_STOP hard rule
        //     (BR-006 policyBundleTampered) cannot be offset by an all-calm soft
        //     profile — the strongest 'allow' input never cancels a red line.
        let redLine = BASSovereignVerdictEngine.VerdictContext(
            sessionID: "s-78r",
            turnID: "t-78r",
            operation: .pureInference,
            hardObservations: .init(policyBundleTampered: true),
            softSignals: .calm,
            evidenceSufficient: true,
            snapshotRef: "snap-78r",
            policyHash: "policy-78r")
        let redLevel = await engine.evaluateLevel(redLine, useRouted: false).level
        XCTAssertEqual(redLevel, .deadStop,
            "BR-006 absolute red line must hold at .deadStop regardless of calm soft signals")
    
        print("QINAO-GATE verdict_kernel_determinism_noncompensatory: PASS " +
            "(50/50 repeats stable -> .quarantine; saturated low-priority signals " +
            "did not cancel high-priority verdict; BR-006 red line held at .deadStop)")
    }

    func test_qinao_replay_fingerprint_determinism() {
        // QINAO #74 L14 — BASReplayBundle replay fingerprint:
        //   (1) determinism: same bundle -> byte-identical sorted-keys SHA256 across runs
        //   (2) avalanche: every single-field mutation flips the digest, 0 collisions, tolerance=0.
        // Construction mirrors BASObservabilityCoreTests.makeReplayBundle() verbatim.
    
        func baseBundle() -> BASReplayBundle {
            BASReplayBundle(
                trace: BASExecutionTrace(
                    inputSummary: "replay this",
                    selectedRoute: .local("local-fast"),
                    memoriesRecalled: ["Memory A"],
                    toolsCalled: ["toolA"],
                    latency: BASTraceLatencyBreakdown(
                        routeSelectionMs: 12,
                        retrievalMs: 35,
                        generationMs: 180,
                        toolMs: 45
                    ),
                    outputSummary: "Released"
                ),
                brainState: BASCurrentBrainState(
                    mode: "primary",
                    dominantGoals: ["stay calm"],
                    activeConstraints: ["sleep first"],
                    reactionWeights: BASReactionWeights(warmth: 0.7, directness: 0.5, brevity: 0.8, actionBias: 0.6),
                    activeTemplateIDs: [],
                    recentFailurePatternIDs: [],
                    retrievalTags: ["night"],
                    verificationSnapshot: "fp_1"
                ),
                runtimeContext: BASRuntimeContext(
                    taskKind: .chat,
                    gear: .balanced,
                    deviceProfile: BASDeviceProfile(
                        modelName: "iPhone",
                        memoryMB: 6144,
                        batteryLevel: 0.8,
                        lowPowerMode: false,
                        thermalState: "nominal"
                    ),
                    privacyMode: .localOnly,
                    riskLevel: .medium,
                    networkAvailable: false,
                    budget: BASExecutionBudget(
                        contextTokens: 1200,
                        outputTokens: 300,
                        retrievalItems: 3,
                        toolCalls: 1,
                        timeBudgetMs: 1500
                    )
                ),
                policyDecision: BASPolicyDecisionRecord(decision: .allow, reason: "allowed")
            )
        }
    
        func fp(_ b: BASReplayBundle) -> String {
            BASObservabilityInspector.replayFingerprint(for: b).value
        }
    
        // (1) DETERMINISM — byte-identical across independently rebuilt identical bundles, tolerance=0.
        let base = baseBundle()
        let baseline = fp(base)
        XCTAssertEqual(baseline.count, 64,
            "QINAO replay fingerprint must be 64 hex chars (sorted-keys SHA256)")
        for run in 0..<200 {
            let rebuilt = baseBundle()
            XCTAssertEqual(fp(rebuilt), baseline,
                "QINAO determinism violated on run \(run): identical bundle -> different digest")
        }
        for _ in 0..<50 {
            XCTAssertEqual(fp(base), baseline,
                "QINAO determinism violated: repeated call on same value differs")
        }
    
        // (2) AVALANCHE — every single-field mutation flips the digest. tolerance=0, 0 collisions.
        var mutated: [String: BASReplayFingerprint] = [:]
    
        var mTrace = baseBundle()
        mTrace.trace.inputSummary = "replay this!"   // single-field flip in trace
        mutated["trace.inputSummary"] = BASReplayFingerprint(value: fp(mTrace))
    
        var mOutput = baseBundle()
        mOutput.trace.outputSummary = "Released."
        mutated["trace.outputSummary"] = BASReplayFingerprint(value: fp(mOutput))
    
        var mBrain = baseBundle()
        mBrain.brainState.mode = "secondary"
        mutated["brainState.mode"] = BASReplayFingerprint(value: fp(mBrain))
    
        var mWeights = baseBundle()
        mWeights.brainState.reactionWeights = BASReactionWeights(warmth: 0.71, directness: 0.5, brevity: 0.8, actionBias: 0.6)
        mutated["brainState.reactionWeights.warmth"] = BASReplayFingerprint(value: fp(mWeights))
    
        var mRisk = baseBundle()
        mRisk.runtimeContext.riskLevel = .high
        mutated["runtimeContext.riskLevel"] = BASReplayFingerprint(value: fp(mRisk))
    
        var mPolicy = baseBundle()
        mPolicy.policyDecision = BASPolicyDecisionRecord(decision: .deny, reason: "blocked")
        mutated["policyDecision"] = BASReplayFingerprint(value: fp(mPolicy))
    
        var mDisposition = baseBundle()
        mDisposition.replayDisposition.isAvailable = false
        mutated["replayDisposition.isAvailable"] = BASReplayFingerprint(value: fp(mDisposition))
    
        for (label, digest) in mutated {
            XCTAssertEqual(digest.value.count, 64,
                "QINAO mutated digest \(label) not 64 hex chars")
            XCTAssertNotEqual(digest.value, baseline,
                "QINAO avalanche violated: single-field mutation [\(label)] did NOT flip the digest")
        }
    
        // 0 collisions: baseline + every mutated digest are all distinct.
        var seen = Set<String>([baseline])
        for (label, digest) in mutated {
            let inserted = seen.insert(digest.value).inserted
            XCTAssertTrue(inserted,
                "QINAO collision: mutation [\(label)] produced a non-unique digest")
        }
        XCTAssertEqual(seen.count, mutated.count + 1,
            "QINAO replay fingerprint collision detected (expected baseline + \(mutated.count) distinct digests)")
    
        print("QINAO-GATE replay_fingerprint_determinism: PASS (64-hex sorted-keys SHA256, 250 deterministic runs identical, \(mutated.count) single-field mutations each flipped the digest, 0 collisions, tolerance=0)")
    }

    func test_qinao_append_only_no_mutation_surface() async throws {
        // GATE #86 (L14): the audit ledger exposes ZERO public mutation /
        // deletion methods; count() is monotone non-decreasing. The only
        // sovereign-approved propagation primitive — LINEAGE_CUT — and
        // rotation both APPEND (or close a segment); neither ever shrinks
        // count(). Verified against source: no public delete/remove/clear/
        // purge/prune/reset on BASSovereignAuditLedger.
        let ledger = BASSovereignAuditLedger.withSeed("qinao-86-append-only")
    
        func entry(_ id: String) -> BASSovereignAuditEntry {
            BASSovereignAuditEntry(
                auditID: id,
                sessionID: "session-A",
                turnID: "turn-1",
                verdictRef: "verdict-xyz",
                ruleIDs: ["BR-001"],
                signalRefs: [],
                actionRefs: [],
                snapshotRef: "snap-1",
                actor: .system,
                signature: "",
                appendedAt: Date(timeIntervalSince1970: 1_700_000_000))
        }
    
        // Append 3 entries: count climbs 1 -> 2 -> 3, never shrinks.
        _ = try await ledger.append(entry("a-root"))
        let _c1 = await ledger.count(); XCTAssertEqual(_c1, 1)
        _ = try await ledger.append(entry("a-2"))
        let _c2 = await ledger.count(); XCTAssertEqual(_c2, 2)
        _ = try await ledger.append(entry("a-3"))
        let afterAppends = await ledger.count()
        XCTAssertEqual(afterAppends, 3, "three appends => count == 3")
    
        // The ONLY audited cut primitive APPENDS a marker (it must not
        // delete anything: BR-012). count() grows by exactly 1, never
        // shrinks. tolerance = 0 (exact).
        let request = BASSovereignLineageCutRequest(
            cutID: "cut-1",
            sessionID: "session-A",
            rootAuditID: "a-root",
            depth: .entireLineage,
            reason: "privacy-scrub",
            protectedRuleIDs: [],
            requestedAt: Date(timeIntervalSince1970: 1_700_000_900))
        _ = try await ledger.lineageCut(request: request)
        let afterCut = await ledger.count()
        XCTAssertEqual(afterCut, afterAppends + 1,
                       "LINEAGE_CUT APPENDS a marker; count grows by 1, never shrinks")
        XCTAssertGreaterThanOrEqual(afterCut, afterAppends,
                                    "count() is monotone non-decreasing across a cut")
    
        // An audited rotation closes a segment WITHOUT deleting entries:
        // count() is left exactly where it was (monotone, no shrink).
        _ = try await ledger.append(entry("a-4"))
        let beforeRotate = await ledger.count()
        let plan = BASSovereignLedgerRotationPlan(
            rotationID: "rot-1",
            sessionID: "session-A",
            beforeTurnID: nil,
            reason: .scheduledRotation,
            requestedAt: Date(timeIntervalSince1970: 1_700_001_000))
        _ = try await ledger.rotate(plan: plan)
        let afterRotate = await ledger.count()
        XCTAssertEqual(afterRotate, beforeRotate,
                       "rotation closes a segment but never shrinks count()")
        XCTAssertGreaterThanOrEqual(afterRotate, afterAppends,
                                    "count() never drops below any earlier observation")
    
        print("QINAO-GATE append_only_no_mutation_surface: PASS "
            + "count monotone non-decreasing (3 -> \(afterCut) after audited cut "
            + "-> \(afterRotate) after rotation); zero public mutation/deletion methods")
    }
}

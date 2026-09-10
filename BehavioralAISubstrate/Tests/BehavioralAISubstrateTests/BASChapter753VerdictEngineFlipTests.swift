// MARK: - BASChapter753VerdictEngineFlipTests
// chapter 七百五十三 第一刀 / M2433
//
// MATURATION ARC L14 Verdict engine production swap。 Verifies
// the routed Stage 2+3 path is default-on AND produces byte-
// identical verdict levels to the legacy Swift 3-stage logic
// across a 100-case random fixture。

import XCTest
@testable import BASSovereign
@testable import BASRuntimeCore

final class BASChapter753VerdictEngineFlipTests: XCTestCase {

    // MARK: - Default flip pin

    func testUseRoutedVerdictLevelDefaultIsTrue() {
        XCTAssertTrue(
            BASSovereignVerdictEngine.useRoutedVerdictLevel,
            "chapter 七百五十三 第一刀: useRoutedVerdictLevel " +
            "flipped default → true per 13.84× win + " +
            "chapter 七百四十二 byte-equality pin")
    }

    // MARK: - Helper:make engine + ledger (mirrors in-tree pattern)

    private func makeEngine(
        seed: String = "chapter-753-flip"
    ) -> BASSovereignVerdictEngine {
        let ledger = BASSovereignAuditLedger.withSeed(seed)
        return BASSovereignVerdictEngine(ledger: ledger)
    }

    private func ctx(
        hard: BASSovereignVerdictEngine.HardObservations =
            .clean,
        soft: BASSovereignVerdictEngine.SoftSignals = .calm,
        operation:
            BASSovereignVerdictEngine.OperationDomain =
                .pureInference,
        evidenceSufficient: Bool = true
    ) -> BASSovereignVerdictEngine.VerdictContext {
        return BASSovereignVerdictEngine.VerdictContext(
            sessionID: "s1",
            turnID: "t1",
            operation: operation,
            hardObservations: hard,
            softSignals: soft,
            evidenceSufficient: evidenceSufficient,
            snapshotRef: "snap-1",
            policyHash: "policy-1")
    }

    // MARK: - Byte-equality:routed vs V1 Swift across 100 random cases

    /// Deterministic SplitMix64 PRNG for stable random fixture。
    private struct SplitMix64 {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &+ 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        mutating func nextDouble() -> Double {
            return Double(next() >> 11)
                / Double(UInt64(1) << 53)
        }
        mutating func nextBool(prob: Double = 0.5) -> Bool {
            return nextDouble() < prob
        }
    }

    private func makeRandomHard(
        _ rng: inout SplitMix64
    ) -> BASSovereignVerdictEngine.HardObservations {
        return .init(
            artifactSignatureInvalid:     rng.nextBool(prob: 0.05),
            thoughtFoldChecksumBroken:    rng.nextBool(prob: 0.05),
            externalSideEffectWithoutSCT: rng.nextBool(prob: 0.05),
            memoryOrHostWriteBypass:      rng.nextBool(prob: 0.05),
            hostRemovalBypassed:          rng.nextBool(prob: 0.05),
            policyBundleTampered:         rng.nextBool(prob: 0.05),
            unauthorizedSelfMutation:     rng.nextBool(prob: 0.05),
            irreversibleHighGSIWithoutEvidence:
                rng.nextBool(prob: 0.05),
            runtimeUnstableInHighRisk:    rng.nextBool(prob: 0.05),
            riskPermitHeadConflict:       rng.nextBool(prob: 0.05),
            hostAttemptsBaseBoundaryOverride:
                rng.nextBool(prob: 0.05),
            auditAppendFailed:            rng.nextBool(prob: 0.05))
    }

    private func makeRandomSoft(
        _ rng: inout SplitMix64
    ) -> BASSovereignVerdictEngine.SoftSignals {
        return .init(
            integrity:             rng.nextDouble(),
            privilegeViolation:    rng.nextDouble(),
            selfMod:               rng.nextDouble(),
            memoryContamination:   rng.nextDouble(),
            irreversibleHarm:      rng.nextDouble(),
            runtimeInstability:    rng.nextDouble(),
            manipulationIntrusion: rng.nextDouble())
    }

    /// 100-case byte-equality test:routed vs V1 Swift。 The
    /// routed level + the V1 Swift level MUST agree for every
    /// (hard,soft,operation,evidence) input。 Per chapter
    /// 七百四十二 第三刀 fixture this is already pinned for the
    /// Rust port in isolation;this test pins it at the LIVE
    /// production seam (evaluate() with the flag flipped)。
    func testRoutedVerdictMatchesV1SwiftAcross100Cases() async {
        var rng = SplitMix64(state: 0xDEAD_BEEF_F00D_CAFE)
        let domains: [BASSovereignVerdictEngine
            .OperationDomain] = [
            .pureInference, .toolRead, .toolWrite,
            .hostMutate, .memoryPromote, .rulePromotion]

        let engine = makeEngine()

        var failures: [(idx: Int, routed: String, swift: String)]
            = []

        for i in 0..<100 {
            let hard = makeRandomHard(&rng)
            let soft = makeRandomSoft(&rng)
            let domain = domains[
                Int(rng.next() % UInt64(domains.count))]
            let evidence = rng.nextBool(prob: 0.5)

            let context = ctx(
                hard: hard,
                soft: soft,
                operation: domain,
                evidenceSufficient: evidence)

            // Compare the routed vs the V1-Swift level via the PURE kernel
            // (the single source of truth that `evaluate()` builds around,
            // ADR-024), passing the routing choice EXPLICITLY. This pins the
            // exact branch the production global selects, WITHOUT mutating the
            // shared `useRoutedVerdictLevel` static — so the test no longer
            // races with any other suite reading that flag under parallel
            // execution (the verdict engine is the safety arbiter)。
            let routed = await engine.evaluateLevel(
                context, useRouted: true).level
            let v1 = await engine.evaluateLevel(
                context, useRouted: false).level

            if routed != v1 {
                failures.append((
                    idx: i,
                    routed: routed.rawValue,
                    swift: v1.rawValue))
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Verdict level disagreements: " +
            failures.map { "\($0.idx)" }
                .joined(separator: ","))
    }

    // MARK: - Perf scorecard print

// chapter 八百二十八 / M2791-M2795 — #if false BODY ARCHIVED (was 89 LOC) → Archive/Deactivated/Tests/BehavioralAISubstrateTests/BASChapter753VerdictEngineFlipTests_IfFalseBody.txt
}

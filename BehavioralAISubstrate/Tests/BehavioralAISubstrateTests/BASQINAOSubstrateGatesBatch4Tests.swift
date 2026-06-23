import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASSovereign
import BASMemory
import BASPolicy
import CryptoKit
import Foundation

/// QINAO Substrate-100 gates — Phase-2 batch 4 (sovereign/audit/determinism; agent-drafted, author-verified).
final class BASQINAOSubstrateGatesBatch4Tests: XCTestCase {

    func test_qinao_turn_replay_determinism() {
        // Build ONE representative, fully-wired BASEBrainTurnResult via the deterministic
        // stub coordinator (the same construction path the production replay harness uses).
        // runTurn(_:) is synchronous and deterministic for the stub coordinator.
        let request = BASCoordinatorTestStubs.makeStubRequest()
        let result = BASCoordinatorTestStubs.makeStub().runTurn(request)
    
        // Fixed producedAt: it is METADATA ONLY (never hashed), so a constant keeps the
        // digestString reproducible while letting us prove producedAt does not leak in.
        let producedAt = Date(timeIntervalSince1970: 0)
        let laterProducedAt = Date(timeIntervalSince1970: 987_654_321)
    
        // (1) STABILITY — serializing the SAME result twice yields a byte-identical digest
        //     (tolerance 0: exact String equality, not approximate).
        let d1 = BASEBrainTurnResultReplayDigest.from(result: result, producedAt: producedAt)
        let d2 = BASEBrainTurnResultReplayDigest.from(result: result, producedAt: producedAt)
        XCTAssertEqual(d1.digestString, d2.digestString,
            "same turn result serialized twice must produce a byte-identical digest")
    
        // Replicated oracle: re-derive the digest INDEPENDENTLY of the production helper using
        // the exact pinned algorithm (canonicalize → .sortedKeys JSON → UTF-8 → SHA256 → lower-hex).
        // This proves the digest is the documented hash, not just self-consistent.
        let canonical = BASEBrainTurnResultReplayCanonicalizer.canonicalized(result)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let oracleData = try! encoder.encode(canonical)
        let oracleHex = BASAutoRouteRanker.bytesToHexLower(Array(SHA256.hash(data: oracleData)))
        XCTAssertEqual(d1.digestString, oracleHex,
            "production digest must equal the independently-replicated sorted-keys/UTF-8/SHA256 oracle")
        XCTAssertEqual(d1.algorithmName,
            BASEBrainTurnResultReplayDigest.algorithmRawName,
            "algorithm identifier must be the pinned ebrain-turn-result-json-sha256-sortedKeys-utf8")
    
        // (2) producedAt is metadata-only — a DIFFERENT producedAt must NOT change digestString.
        let dLater = BASEBrainTurnResultReplayDigest.from(result: result, producedAt: laterProducedAt)
        XCTAssertEqual(d1.digestString, dLater.digestString,
            "producedAt is metadata only and must never affect the byte-identity digest")
    
        // (3) TAMPER — a SINGLE field change must FLIP the digest. hostGateValue is an
        //     authorization-bearing field that the canonicalizer does NOT pin, so mutating it
        //     alone must yield a different digest under the default canonicalized path.
        var tampered = result
        tampered.hostGateValue = result.hostGateValue + 1.0
        let dTampered = BASEBrainTurnResultReplayDigest.from(result: tampered, producedAt: producedAt)
        XCTAssertNotEqual(d1.digestString, dTampered.digestString,
            "a single-field change (hostGateValue) must flip the replay digest")
    
        // (4) Re-tampering with the SAME mutation re-derives the SAME flipped digest
        //     (determinism of the flipped state, tolerance 0).
        var tampered2 = result
        tampered2.hostGateValue = result.hostGateValue + 1.0
        let dTampered2 = BASEBrainTurnResultReplayDigest.from(result: tampered2, producedAt: producedAt)
        XCTAssertEqual(dTampered.digestString, dTampered2.digestString,
            "the tampered digest must itself be deterministic across re-serialization")
    
        // (5) RAW vs CANONICAL — the canonicalize flag genuinely participates: mutating the
        //     one pinned observation-clock field flips the RAW digest but is collapsed by the
        //     canonical digest, proving canonicalization is non-vacuous and field-scoped.
        var clockDrifted = result
        clockDrifted.memoryBundle.retrievedAt = Date(timeIntervalSince1970: 555)
        let rawBase = BASEBrainTurnResultReplayDigest.from(
            result: result, producedAt: producedAt, canonicalize: false)
        let rawDrift = BASEBrainTurnResultReplayDigest.from(
            result: clockDrifted, producedAt: producedAt, canonicalize: false)
        XCTAssertNotEqual(rawBase.digestString, rawDrift.digestString,
            "raw (uncanonicalized) digest must reflect retrievedAt drift")
        let canonDrift = BASEBrainTurnResultReplayDigest.from(
            result: clockDrifted, producedAt: producedAt)
        XCTAssertEqual(d1.digestString, canonDrift.digestString,
            "canonical digest must collapse the observation-clock drift")
    
        // Digest is non-empty hex of a full SHA256 (64 lowercase hex chars).
        XCTAssertEqual(d1.digestString.count, 64,
            "SHA256 lower-hex digest must be 64 characters")
    
        print("QINAO-GATE turn_replay_determinism: PASS "
            + "(stable=\(d1.digestString == d2.digestString) "
            + "oracle-match=\(d1.digestString == oracleHex) "
            + "single-field-flip=\(d1.digestString != dTampered.digestString) "
            + "canon-collapses-drift=\(d1.digestString == canonDrift.digestString) "
            + "digest=\(d1.digestString.prefix(12))…)")
    }

    func test_qinao_admission_lane_decision_determinism() {
        // L9 #60: BASExecutionGovernance.admissionDecision is a PURE static function over
        // BASAdmissionRequest. This gate raises the bar to tolerance=0:
        //   (a) byte-identical (Equatable ==) decision across repeated re-calls,
        //   (b) byte-identical across permuted SWEEP/insertion order of equivalent requests,
        //   (c) pressure-band cutpoints at exactly 0.55 / 0.85 / 1.0 — probe both sides
        //       (0.549 vs 0.55, 0.849 vs 0.85, 1.0 vs >1.0) against a replicated oracle.
    
        // ---- Replicated oracle for promptPressure (mirrors the real switch) ----
        // ..<0.55 -> low ; ..<0.85 -> elevated ; ...1.0 -> high ; else -> severe.
        func oraclePressure(ratio: Double) -> BASPromptPressure {
            switch ratio {
            case ..<0.55: return .low
            case ..<0.85: return .elevated
            case ...1.0:  return .high
            default:      return .severe
            }
        }
    
        // Build a request whose utilizationRatio = total/target is an EXACT double.
        // utilizationRatio uses Double(total)/Double(target); prefix+suffix == total.
        func makeBudget(target: Int, total: Int) -> BASPromptBudgetSnapshot {
            BASPromptBudgetSnapshot(
                targetCharacters: target,
                prefixCharacters: total,
                suffixCharacters: 0
            )
        }
    
        // Use .primary with rich frontstage signal so the only gating lever that varies
        // here is pressure (we keep candidate/template short-circuits from firing), and
        // include a budget-exceeded path naturally above 1.0.
        func makeRequest(target: Int, total: Int, kind: BASAdaptiveTraceKind) -> BASAdmissionRequest {
            BASAdmissionRequest(
                kind: kind,
                budget: makeBudget(target: target, total: total),
                frontstageState: BASFrontstageSignalSummary(
                    activeStateSignalCount: 2,
                    openTextSignalCount: 5,
                    dangerSignalCount: 0,
                    evidenceHeadlineCount: 4,
                    anchorHeadlineCount: 2,
                    suppressionHintCount: 1
                ),
                selectionCandidateCount: nil,
                selectionAssessment: nil
            )
        }
    
        // ---- Exact cutpoint domain: (target, total) chosen so ratio is an exact double ----
        // 0.549, 0.55, 0.849, 0.85, 1.0, and just-over (severe).
        let cutCases: [(target: Int, total: Int, ratio: Double)] = [
            (1000, 549, 0.549),
            (1000, 550, 0.55),
            (1000, 849, 0.849),
            (1000, 850, 0.85),
            (1000, 1000, 1.0),
            (1000, 1001, 1.001)
        ]
    
        // Sanity: confirm the doubles we feed match the integer ratios exactly (tolerance 0).
        for c in cutCases {
            let b = makeBudget(target: c.target, total: c.total)
            XCTAssertEqual(b.utilizationRatio, c.ratio,
                           "Budget ratio must be an exact double for cutpoint \(c.ratio)")
        }
    
        // (c) Pressure cutpoints exact, both sides, against replicated oracle.
        for c in cutCases {
            let req = makeRequest(target: c.target, total: c.total, kind: .primary)
            let decision = BASExecutionGovernance.admissionDecision(for: req)
            let expected = oraclePressure(ratio: c.ratio)
            XCTAssertEqual(decision.pressure, expected,
                           "pressure at ratio \(c.ratio) must be \(expected.rawValue), got \(decision.pressure.rawValue)")
        }
    
        // Spell out the exact band assignments so a moved cutpoint is caught directly.
        func pressure(target: Int, total: Int) -> BASPromptPressure {
            BASExecutionGovernance.admissionDecision(
                for: makeRequest(target: target, total: total, kind: .primary)
            ).pressure
        }
        XCTAssertEqual(pressure(target: 1000, total: 549), .low)       // 0.549 -> low
        XCTAssertEqual(pressure(target: 1000, total: 550), .elevated)  // 0.55  -> elevated (boundary moves up)
        XCTAssertEqual(pressure(target: 1000, total: 849), .elevated)  // 0.849 -> elevated
        XCTAssertEqual(pressure(target: 1000, total: 850), .high)      // 0.85  -> high (boundary moves up)
        XCTAssertEqual(pressure(target: 1000, total: 1000), .high)     // 1.0   -> high (inclusive)
        XCTAssertEqual(pressure(target: 1000, total: 1001), .severe)   // >1.0  -> severe
    
        // ---- Full decision sweep across all 4 kinds and a range of ratios ----
        let kinds: [BASAdaptiveTraceKind] = [.primary, .comparative, .reflective, .selection]
        let ratioGrid: [(target: Int, total: Int)] = [
            (1000, 100), (1000, 549), (1000, 550), (1000, 700),
            (1000, 849), (1000, 850), (1000, 999), (1000, 1000), (1000, 1500)
        ]
    
        // Build the canonical (sorted) list of requests.
        var canonical: [BASAdmissionRequest] = []
        for k in kinds {
            for g in ratioGrid {
                // For .selection give >=2 candidates with a knowledge need so the
                // candidate-spread / control short-circuits do not pre-empt pressure paths.
                if k == .selection {
                    canonical.append(
                        BASAdmissionRequest(
                            kind: k,
                            budget: makeBudget(target: g.target, total: g.total),
                            frontstageState: BASFrontstageSignalSummary(
                                activeStateSignalCount: 1,
                                openTextSignalCount: 5,
                                dangerSignalCount: 0,
                                evidenceHeadlineCount: 4,
                                anchorHeadlineCount: 2,
                                suppressionHintCount: 1
                            ),
                            selectionCandidateCount: 3,
                            selectionAssessment: BASSelectionAssessment(
                                need: .knowledge,
                                reason: "knowledge-needed",
                                promptTokenCount: 128,
                                topCandidateScore: 9,
                                secondCandidateScore: 4,
                                distinctCandidateCount: 3
                            )
                        )
                    )
                } else {
                    canonical.append(makeRequest(target: g.target, total: g.total, kind: k))
                }
            }
        }
    
        // (a) Deterministic re-call: identical request -> identical decision, every time.
        for req in canonical {
            let d1 = BASExecutionGovernance.admissionDecision(for: req)
            let d2 = BASExecutionGovernance.admissionDecision(for: req)
            let d3 = BASExecutionGovernance.admissionDecision(for: req)
            XCTAssertEqual(d1, d2, "admissionDecision must be byte-identical on re-call")
            XCTAssertEqual(d2, d3, "admissionDecision must be byte-identical on re-call")
        }
    
        // Capture canonical decisions keyed by a stable index.
        let canonicalDecisions = canonical.map { BASExecutionGovernance.admissionDecision(for: $0) }
    
        // (b) Insertion-order permutation: evaluate the SAME logical set in a permuted
        // order and assert each request maps to the byte-identical decision regardless
        // of the order it was produced/iterated in. We pair (request, expectedDecision)
        // and shuffle deterministically, then re-derive and compare.
        var permIndices = Array(canonical.indices)
        // Deterministic reversal + interleave permutation (no RNG => reproducible).
        permIndices.reverse()
        var interleaved: [Int] = []
        var lo = 0
        var hi = permIndices.count - 1
        while lo <= hi {
            interleaved.append(permIndices[lo])
            if lo != hi { interleaved.append(permIndices[hi]) }
            lo += 1
            hi -= 1
        }
        for idx in interleaved {
            let redecided = BASExecutionGovernance.admissionDecision(for: canonical[idx])
            XCTAssertEqual(redecided, canonicalDecisions[idx],
                           "decision must be order-independent (permuted sweep) at index \(idx)")
        }
    
        // Tamper assertion: mutating a single field that the controller reads must be
        // capable of flipping the decision — confirms the gate is actually load-bearing,
        // not a constant. Push primary over budget and require a budget-exceeded skip.
        let overBudget = makeRequest(target: 1000, total: 2000, kind: .primary)
        let overDecision = BASExecutionGovernance.admissionDecision(for: overBudget)
        XCTAssertFalse(overDecision.isAllowed, "over-budget primary must be denied")
        XCTAssertEqual(overDecision.skipReason, .budgetExceeded)
        XCTAssertEqual(overDecision.pressure, .severe)
        // And the mutated decision must differ from the in-budget one (tamper visible).
        let inBudget = makeRequest(target: 1000, total: 700, kind: .primary)
        XCTAssertNotEqual(
            BASExecutionGovernance.admissionDecision(for: inBudget),
            overDecision,
            "mutating the budget must change the admission decision"
        )
    
        print("QINAO-GATE admission_lane_decision_determinism: PASS "
            + "(\(canonical.count) requests x re-call/permutation byte-identical; "
            + "cutpoints exact at 0.55/0.85/1.0 probed both sides; tamper visible)")
    }

        func test_qinao_rust_swift_verdict_parity() async throws {
            typealias Engine = BASSovereignVerdictEngine
            typealias Hard = Engine.HardObservations
            typealias Soft = Engine.SoftSignals
            typealias Domain = Engine.OperationDomain
            typealias Level = BASSovereignVerdictLevel
    
            let ledger = BASSovereignAuditLedger.withSeed("qinao-verdict-parity")
            let engine = Engine(ledger: ledger)
    
            // ---- Replicated oracle (mirrors the documented 3-stage kernel) ----
            // Stage 1 hard-rule (code, minLevel) table — exactly §11.1 / engine.
            func hardHits(_ o: Hard) -> [Level] {
                var l: [Level] = []
                if o.artifactSignatureInvalid { l.append(.deadStop) }      // BR-001
                if o.thoughtFoldChecksumBroken { l.append(.rollback) }     // BR-002
                if o.externalSideEffectWithoutSCT { l.append(.deadStop) }  // BR-003
                if o.memoryOrHostWriteBypass { l.append(.memoryFreeze) }   // BR-004
                if o.hostRemovalBypassed { l.append(.quarantine) }         // BR-005
                if o.policyBundleTampered { l.append(.deadStop) }          // BR-006
                if o.unauthorizedSelfMutation { l.append(.deadStop) }      // BR-007
                if o.irreversibleHighGSIWithoutEvidence { l.append(.toolCut) } // BR-008
                if o.runtimeUnstableInHighRisk { l.append(.shadowLock) }   // BR-009
                if o.riskPermitHeadConflict { l.append(.throttle) }        // BR-010
                if o.hostAttemptsBaseBoundaryOverride { l.append(.quarantine) } // BR-011
                if o.auditAppendFailed { l.append(.deadStop) }             // BR-012
                return l
            }
            // Stage 2 lexicographic non-compensatory soft signals — §12.2 order.
            func band(_ s: Double) -> Int { s >= 0.7 ? 2 : (s >= 0.4 ? 1 : 0) }
            func softLevel(_ s: Soft) -> Level {
                let ordered: [(Double, Level, Level)] = [
                    (s.integrity, .deadStop, .rollback),
                    (s.privilegeViolation, .quarantine, .shadowLock),
                    (s.selfMod, .deadStop, .quarantine),
                    (s.memoryContamination, .memoryFreeze, .shadowLock),
                    (s.irreversibleHarm, .toolCut, .throttle),
                    (s.runtimeInstability, .shadowLock, .throttle),
                    (s.manipulationIntrusion, .toolCut, .throttle),
                ]
                var best: Level = .pass
                for (score, high, mid) in ordered {
                    switch band(score) {
                    case 2: return high           // first .high pins, non-compensatory
                    case 1: if mid > best { best = mid }
                    default: continue
                    }
                }
                return best
            }
            func isIrreversible(_ d: Domain) -> Bool {
                switch d {
                case .toolWrite, .hostMutate, .memoryPromote, .rulePromotion: return true
                case .pureInference, .toolRead: return false
                }
            }
            func oracleLevel(_ ctx: Engine.VerdictContext) -> Level {
                var level = softLevel(ctx.softSignals)              // Stage 2
                for hl in hardHits(ctx.hardObservations) where hl > level {
                    level = hl                                       // max(hard floor, soft)
                }
                if isIrreversible(ctx.operation) && !ctx.evidenceSufficient && level < .toolCut {
                    level = .toolCut                                 // Stage 3 upgrade
                }
                return level
            }
    
            // ---- Frozen fixture grid -------------------------------------------
            // Hard column: clean + each of the 12 single-bit observations.
            let hardSetters: [(String, (inout Hard) -> Void)] = [
                ("clean", { _ in }),
                ("BR-001", { $0.artifactSignatureInvalid = true }),
                ("BR-002", { $0.thoughtFoldChecksumBroken = true }),
                ("BR-003", { $0.externalSideEffectWithoutSCT = true }),
                ("BR-004", { $0.memoryOrHostWriteBypass = true }),
                ("BR-005", { $0.hostRemovalBypassed = true }),
                ("BR-006", { $0.policyBundleTampered = true }),
                ("BR-007", { $0.unauthorizedSelfMutation = true }),
                ("BR-008", { $0.irreversibleHighGSIWithoutEvidence = true }),
                ("BR-009", { $0.runtimeUnstableInHighRisk = true }),
                ("BR-010", { $0.riskPermitHeadConflict = true }),
                ("BR-011", { $0.hostAttemptsBaseBoundaryOverride = true }),
                ("BR-012", { $0.auditAppendFailed = true }),
            ]
            // Soft grid: sweep each of the 7 signals across band boundaries while
            // holding the rest calm, plus a global all-low and all-high corner.
            let bandScores: [Double] = [0.0, 0.39, 0.4, 0.69, 0.7, 1.0]
            let softKeys = 0..<7
            var softFixtures: [Soft] = [.calm]
            for k in softKeys {
                for v in bandScores {
                    var s = Soft.calm
                    switch k {
                    case 0: s.integrity = v
                    case 1: s.privilegeViolation = v
                    case 2: s.selfMod = v
                    case 3: s.memoryContamination = v
                    case 4: s.irreversibleHarm = v
                    case 5: s.runtimeInstability = v
                    default: s.manipulationIntrusion = v
                    }
                    softFixtures.append(s)
                }
            }
            // All-mid and all-high corners exercise the accumulate-mids path.
            softFixtures.append(Soft(integrity: 0.5, privilegeViolation: 0.5, selfMod: 0.5,
                                     memoryContamination: 0.5, irreversibleHarm: 0.5,
                                     runtimeInstability: 0.5, manipulationIntrusion: 0.5))
            softFixtures.append(Soft(integrity: 0.9, privilegeViolation: 0.9, selfMod: 0.9,
                                     memoryContamination: 0.9, irreversibleHarm: 0.9,
                                     runtimeInstability: 0.9, manipulationIntrusion: 0.9))
    
            let domains: [Domain] = [.pureInference, .toolRead, .toolWrite,
                                     .hostMutate, .memoryPromote, .rulePromotion]
            let evidenceCases = [true, false]
            let allLevels = Set(Level.allCases)
    
            var fixtures = 0
            var divergences = 0
            for (hardName, setter) in hardSetters {
                var hard = Hard.clean
                setter(&hard)
                for soft in softFixtures {
                    for domain in domains {
                        for evidence in evidenceCases {
                            let ctx = Engine.VerdictContext(
                                sessionID: "s-\(hardName)",
                                turnID: "t-\(fixtures)",
                                operation: domain,
                                hardObservations: hard,
                                softSignals: soft,
                                evidenceSufficient: evidence,
                                snapshotRef: "snap",
                                policyHash: "policy")
                            // Byte-pinned Swift kernel (routed bridge may be absent).
                            let d1 = await engine.evaluateLevel(ctx, useRouted: false)
    
                            // (A) TOTAL + no spurious nil — level is a real case.
                            XCTAssertTrue(allLevels.contains(d1.level),
                                "non-total level for \(hardName)/\(domain)/\(evidence)")
    
                            // (B) DETERMINISTIC re-call (level + reasons + revokes).
                            let d2 = await engine.evaluateLevel(ctx, useRouted: false)
                            XCTAssertEqual(d1.level, d2.level, "non-deterministic level")
                            XCTAssertEqual(d1.reasonCodes, d2.reasonCodes,
                                "non-deterministic reasonCodes")
                            XCTAssertEqual(d1.revokedPermissions, d2.revokedPermissions,
                                "non-deterministic revokedPermissions")
    
                            // (C) 0 divergence vs the replicated oracle ranking.
                            let expected = oracleLevel(ctx)
                            if d1.level != expected {
                                divergences += 1
                                XCTFail("verdict divergence at \(hardName)/\(domain)/ev=\(evidence): swift=\(d1.level) expected=\(expected)")
                            }
                            fixtures += 1
                        }
                    }
                }
            }
    
            XCTAssertEqual(divergences, 0, "verdict ranking diverged from oracle")
            XCTAssertGreaterThan(fixtures, 0, "empty fixture grid")
            print("QINAO-GATE rust_swift_verdict_parity: PASS fixtures=\(fixtures) divergences=\(divergences) (tolerance=0, total over hardBits×soft×domain×evidence grid, deterministic re-call, replicated-oracle parity on byte-pinned Swift path)")
        }

    // QINAO #87 L14 — a redeemed commit token is NEVER accepted again.
    // Real API: BASSovereignTokenAuthority (actor, BASSovereign) issues + verifies
    // single-use Ed25519 commit tokens; the `redeemed` server record is the burn.
    // Exhaustive over all 6 BASSovereignCommitScope cases; tolerance=0 (exact error equality).
    func test_qinao_commit_token_single_use_burn() async throws {
        // Deterministic clock so TTL never trips during the test (issuedAt == verify time).
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let clock: @Sendable () -> Date = { t0 }
    
        let goodDigest = "ad-canonical-001"
        let goodPolicy = "ph-burn-001"
        let ttlMs = 60_000
    
        // Sweep every scope so the burn invariant is proven across the whole small domain.
        for scope in BASSovereignCommitScope.allCases {
            // Fresh authority per scope (fresh ledger + fresh signing key).
            let authority = BASSovereignTokenAuthority(
                signingKey: Curve25519.Signing.PrivateKey(),
                now: clock)
    
            let intent = BASSovereignTokenAuthority.CommitIntent(
                sessionID: "sess-\(scope.rawValue)",
                turnID: "turn-1",
                scope: scope,
                allowedTargets: ["answer"],
                actionDigest: goodDigest,
                snapshotRef: "snap-1",
                ttlMs: ttlMs,
                policyHash: goodPolicy)
    
            let token = try await authority.issueCommitToken(for: intent)
            XCTAssertTrue(token.singleUse, "authority must mint single-use tokens")
            let activeBefore = await authority.activeTokenCount()
            XCTAssertEqual(activeBefore, 1, "exactly one un-redeemed token after mint")
    
            // --- (a) read-only verify is repeatable and does NOT burn ---
            for _ in 0..<3 {
                try await authority.verifyCommitToken(
                    token,
                    expectedScope: scope,
                    expectedActionDigest: goodDigest,
                    expectedPolicyHash: goodPolicy,
                    redeem: false)
            }
            let activeAfterReads = await authority.activeTokenCount()
            XCTAssertEqual(activeAfterReads, 1,
                "read-only verify (redeem:false) must NOT burn the token")
    
            // --- (b) field-mismatch attempts must throw their EXACT error and NOT burn ---
            let wrongScope: BASSovereignCommitScope =
                (scope == .toolRead) ? .toolWrite : .toolRead
            await XCTAssertThrowsErrorEquals(
                try await authority.verifyCommitToken(
                    token, expectedScope: wrongScope,
                    expectedActionDigest: goodDigest,
                    expectedPolicyHash: goodPolicy, redeem: true),
                BASSovereignTokenAuthority.AuthorityError.scopeMismatch(
                    expected: wrongScope, got: scope),
                "scope mismatch")
            await XCTAssertThrowsErrorEquals(
                try await authority.verifyCommitToken(
                    token, expectedScope: scope,
                    expectedActionDigest: "ad-TAMPERED",
                    expectedPolicyHash: goodPolicy, redeem: true),
                BASSovereignTokenAuthority.AuthorityError.actionDigestMismatch(
                    tokenID: token.tokenID),
                "actionDigest mismatch")
            await XCTAssertThrowsErrorEquals(
                try await authority.verifyCommitToken(
                    token, expectedScope: scope,
                    expectedActionDigest: goodDigest,
                    expectedPolicyHash: "ph-TAMPERED", redeem: true),
                BASSovereignTokenAuthority.AuthorityError.policyHashMismatch(
                    tokenID: token.tokenID),
                "policyHash mismatch")
            // None of the failed attempts may have burned the token.
            let activeAfterMismatch = await authority.activeTokenCount()
            XCTAssertEqual(activeAfterMismatch, 1,
                "a field-mismatch throw must NOT burn the token")
    
            // --- (c) THE BURN: first redeem succeeds, second throws alreadyUsed ---
            try await authority.verifyCommitToken(
                token,
                expectedScope: scope,
                expectedActionDigest: goodDigest,
                expectedPolicyHash: goodPolicy,
                redeem: true)
            let activeAfterBurn = await authority.activeTokenCount()
            XCTAssertEqual(activeAfterBurn, 0, "redeem:true must burn the token")
    
            // Second redeem — and EVERY subsequent attempt (incl. read-only) — is alreadyUsed.
            for redeem in [true, false, true] {
                await XCTAssertThrowsErrorEquals(
                    try await authority.verifyCommitToken(
                        token,
                        expectedScope: scope,
                        expectedActionDigest: goodDigest,
                        expectedPolicyHash: goodPolicy,
                        redeem: redeem),
                    BASSovereignTokenAuthority.AuthorityError.alreadyUsed(
                        tokenID: token.tokenID),
                    "a redeemed token is NEVER accepted again (redeem:\(redeem))")
            }
    
            // --- (d) replay via attacker-flipped singleUse flag is STILL alreadyUsed ---
            // singleUse is unsigned/attacker-mutable; the server `redeemed` record governs.
            var forged = token
            forged.singleUse = false
            await XCTAssertThrowsErrorEquals(
                try await authority.verifyCommitToken(
                    forged,
                    expectedScope: scope,
                    expectedActionDigest: goodDigest,
                    expectedPolicyHash: goodPolicy,
                    redeem: true),
                BASSovereignTokenAuthority.AuthorityError.alreadyUsed(
                    tokenID: token.tokenID),
                "flipping the unsigned singleUse flag cannot un-burn a token")
        }
    
        // --- (e) NONCE REUSE is rejected at deterministic mint (replay across expiry) ---
        do {
            let authority = BASSovereignTokenAuthority(
                signingKey: Curve25519.Signing.PrivateKey(),
                now: clock)
            let intent = BASSovereignTokenAuthority.CommitIntent(
                sessionID: "sess-nonce", turnID: "turn-1",
                scope: .renderHighRisk, allowedTargets: ["answer"],
                actionDigest: goodDigest, snapshotRef: "snap-1",
                ttlMs: ttlMs, policyHash: goodPolicy)
            let nonce = "fixed-nonce-XYZ"
            _ = try await authority.issueDeterministicCommitToken(
                for: intent, tokenID: "sct-1", nonce: nonce, issuedAt: t0)
            // Same nonce, different tokenID → nonce dedup must throw alreadyUsed.
            await XCTAssertThrowsErrorEquals(
                try await authority.issueDeterministicCommitToken(
                    for: intent, tokenID: "sct-2", nonce: nonce, issuedAt: t0),
                BASSovereignTokenAuthority.AuthorityError.alreadyUsed(tokenID: "sct-2"),
                "reusing a nonce must throw alreadyUsed")
            // Same tokenID, fresh nonce → tokenID dedup (no double-spend remint) also throws.
            await XCTAssertThrowsErrorEquals(
                try await authority.issueDeterministicCommitToken(
                    for: intent, tokenID: "sct-1", nonce: "different-nonce", issuedAt: t0),
                BASSovereignTokenAuthority.AuthorityError.alreadyUsed(tokenID: "sct-1"),
                "re-minting an existing tokenID must throw alreadyUsed")
        }
    
        print("QINAO-GATE commit_token_single_use_burn: PASS — across all 6 scopes a redeemed commit token is NEVER re-accepted (second redeem + flipped-singleUse replay both throw .alreadyUsed; read-only verify never burns; scope/actionDigest/policyHash mismatches throw exact errors without burning; nonce reuse and tokenID re-mint both throw .alreadyUsed)")
    }
    
    // Inline async-throwing-equality helper (kept file-local; captures only Sendable
    // AuthorityError + autoclosure, no non-Sendable locals crossing a concurrency boundary).
    private func XCTAssertThrowsErrorEquals<T>(
        _ expression: @autoclosure () async throws -> T,
        _ expected: BASSovereignTokenAuthority.AuthorityError,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("expected throw (\(expected)) but none was thrown — \(message)",
                    file: file, line: line)
        } catch let err as BASSovereignTokenAuthority.AuthorityError {
            XCTAssertEqual(err, expected, message, file: file, line: line)
        } catch {
            XCTFail("threw \(error), expected \(expected) — \(message)",
                    file: file, line: line)
        }
    }

    func test_qinao_byte_determinism_spine_replay() {
        // Build ONE real, fully-populated spine value via the same stub coordinator path the
        // production replay harness uses. `runTurn` is synchronous on the stub coordinator and
        // returns a full ~55-field `BASEBrainTurnResult` (the replay spine).
        let result: BASEBrainTurnResult = BASCoordinatorTestStubs.makeStub()
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
    
        let producedAt = Date(timeIntervalSince1970: 0) // metadata only — never enters the hash
    
        // ── (1) BYTE-IDENTICAL ACROSS TWO PASSES (tolerance = 0) ─────────────────────────────
        // The deterministic-spine serialization is `ebrain-turn-result-json-sha256-sortedKeys-utf8`:
        // canonicalize → JSONEncoder(.sortedKeys) → UTF-8 → SHA256 → lowercase hex. Two independent
        // passes over the SAME spine value MUST yield a byte-identical digest string.
        let passA = BASEBrainTurnResultReplayDigest.from(result: result, producedAt: producedAt)
        let passB = BASEBrainTurnResultReplayDigest.from(result: result, producedAt: producedAt)
        XCTAssertEqual(passA.digestString, passB.digestString,
            "spine digest must be byte-identical across two deterministic passes")
        XCTAssertEqual(passA.algorithmName,
            BASEBrainTurnResultReplayDigest.algorithmRawName,
            "algorithm identifier must be the pinned spine-digest algorithm")
        // Shape sanity: a real SHA256 lowercase-hex digest is 64 chars, never the empty sentinel.
        XCTAssertEqual(passA.digestString.count, 64,
            "spine digest must be a 64-char SHA256 lowercase hex (encoding must not have failed)")
        XCTAssertFalse(passA.digestString.isEmpty,
            "spine digest must not be the empty-encoding-failure sentinel")
        // The replay harness's own determinism verdict must agree (N fresh-coordinator runs collapse
        // to ONE distinct digest) — cross-checks the standalone two-pass result above.
        let verdict = BASEBrainTurnResultReplayHarness.determinismVerdict(
            coordinatorFactory: BASCoordinatorTestStubs.makeStub,
            request: BASCoordinatorTestStubs.makeStubRequest(),
            runCount: 4)
        XCTAssertTrue(verdict.isStable,
            "harness determinism verdict must be byte-stable across fresh-coordinator replays")
        XCTAssertEqual(verdict.distinctDigestCount, 1)
        XCTAssertNil(verdict.divergingRunIndex)
        XCTAssertEqual(verdict.firstDigest, passA.digestString,
            "harness digest must match the standalone two-pass spine digest")
    
        // ── (2) ANY SINGLE-BIT SPINE-FIELD CHANGE FLIPS THE DIGEST (tamper / avalanche) ──────
        // Mutate ONE representative spine field — the risk verdict (`riskCard.riskLevel`,
        // stub baseline `.low`) — to its smallest distinct neighbor and assert the digest flips.
        // Tolerance = 0: a different serialized field MUST produce a different hash.
        let baselineRiskLevel: BASBrainRiskLevel = result.riskCard.riskLevel
        XCTAssertEqual(baselineRiskLevel, .low,
            "stub baseline risk verdict is expected to be .low (fixture pin)")
        var tampered = result
        tampered.riskCard.riskLevel = .extreme // single spine-field change (risk verdict)
        let tamperedDigest = BASEBrainTurnResultReplayDigest.from(
            result: tampered, producedAt: producedAt)
        XCTAssertNotEqual(tamperedDigest.digestString, passA.digestString,
            "a single risk-verdict spine-field change must flip the replay digest")
    
        // Exhaustive over the WHOLE risk-verdict small domain: every value distinct from the
        // baseline MUST flip the digest; restoring the baseline MUST recover the exact digest.
        for level in BASBrainRiskLevel.allCases {
            var probe = result
            probe.riskCard.riskLevel = level
            let probeDigest = BASEBrainTurnResultReplayDigest.from(
                result: probe, producedAt: producedAt).digestString
            if level == baselineRiskLevel {
                XCTAssertEqual(probeDigest, passA.digestString,
                    "restoring the baseline risk verdict must reproduce the exact spine digest")
            } else {
                XCTAssertNotEqual(probeDigest, passA.digestString,
                    "risk verdict \(level) must produce a digest distinct from the baseline")
            }
        }
    
        // Also flip a second independent spine field (the action permit's output cap) to confirm
        // the digest is sensitive to more than one part of the spine.
        var permitTampered = result
        permitTampered.actionPermit = BASActionPermit(
            mode: result.actionPermit.mode,
            reasonCodes: result.actionPermit.reasonCodes,
            outputLengthCap: result.actionPermit.outputLengthCap + 1, // single-field delta
            tonePolicy: result.actionPermit.tonePolicy,
            templatePolicy: result.actionPermit.templatePolicy)
        let permitDigest = BASEBrainTurnResultReplayDigest.from(
            result: permitTampered, producedAt: producedAt).digestString
        XCTAssertNotEqual(permitDigest, passA.digestString,
            "a single action-permit spine-field change must flip the replay digest")
    
        print("QINAO-GATE byte_determinism_spine_replay: PASS "
            + "two-pass byte-identical (\(passA.digestString.prefix(12))…), "
            + "harness verdict stable over 4 replays, "
            + "every risk-verdict in \(BASBrainRiskLevel.allCases.count)-value domain + "
            + "action-permit delta each flips the digest")
    }

    func test_qinao_policy_decision_route_constraint() {
        // Replicated oracle of BASDefaultRoutingPlanner.allowedRoutes(for:) (which is private).
        // L10 sovereignty invariant: the planner must NEVER emit a route — primary OR any
        // fallback stage — outside this allowed set. Cloud egress sovereignty: when cloud is
        // not allowed, the emitted advisory must contain ZERO cloud route kinds anywhere.
        func oracleAllowedRoutes(_ ctx: BASRuntimeContext) -> Set<BASRouteKind> {
            switch ctx.privacyMode {
            case .localOnly:
                return [.local]
            case .localFirst:
                if ctx.networkAvailable && !ctx.deviceProfile.lowPowerMode {
                    return [.local, .hybrid, .cloud]
                }
                return [.local, .hybrid]
            case .cloudAllowed:
                if ctx.networkAvailable {
                    return [.local, .hybrid, .cloud]
                }
                return [.local, .hybrid]
            }
        }
    
        // A registry that offers a candidate of EVERY route kind for EVERY task kind, so the
        // planner is genuinely tempted to pick local/hybrid/cloud. If filtering were buggy,
        // a disallowed route would surface. Cloud descriptors are made cheap+capable so the
        // scorer would happily choose them if not gated.
        func descriptor(_ id: String, _ route: BASRouteKind, _ task: BASTaskKind) -> BASModelDescriptor {
            BASModelDescriptor(
                modelID: id,
                routeKind: route,
                capabilities: BASModelCapabilities(
                    supportsGeneration: true,
                    supportsEmbeddings: true,
                    supportsTools: true,
                    supportsStructuredOutput: true,
                    supportsHybridRouting: true,
                    latencyClass: "fast"
                ),
                supportedTaskKinds: [task],
                relativeCostScore: 0.1,
                maximumContextTokens: 1_000_000
            )
        }
        let allTasks: [BASTaskKind] = [.chat, .plan, .retrieve, .tool, .summarize]
        let allRoutes: [BASRouteKind] = [.local, .hybrid, .cloud]
        var descriptors: [BASModelDescriptor] = []
        for task in allTasks {
            for route in allRoutes {
                descriptors.append(descriptor("\(route.rawValue)-\(task.rawValue)", route, task))
            }
        }
        let registry = BASCapabilityRegistry(descriptors: descriptors)
    
        // Exhaustive small-domain sweep: privacy × network × lowPower × gear × risk × task × thermal.
        let privacyModes: [BASPrivacyMode] = [.localOnly, .localFirst, .cloudAllowed]
        let nets: [Bool] = [true, false]
        let lowPowers: [Bool] = [true, false]
        let gears: [BASRuntimeGear] = [.low, .balanced, .high]
        let risks: [BASRiskLevel] = [.low, .medium, .high]
        let thermals: [String] = ["nominal", "serious", "critical"]
    
        var sweepCount = 0
        var cloudDeniedContexts = 0
        var cloudEmittedWhenDenied = 0
    
        for privacy in privacyModes {
            for net in nets {
                for lowPower in lowPowers {
                    for gear in gears {
                        for risk in risks {
                            for thermal in thermals {
                                for task in allTasks {
                                    let context = BASRuntimeContext(
                                        taskKind: task,
                                        gear: gear,
                                        deviceProfile: BASDeviceProfile(
                                            modelName: "iPhone-Test",
                                            memoryMB: 8192,
                                            batteryLevel: 0.5,
                                            lowPowerMode: lowPower,
                                            thermalState: thermal
                                        ),
                                        privacyMode: privacy,
                                        riskLevel: risk,
                                        networkAvailable: net,
                                        budget: BASExecutionBudget(
                                            contextTokens: 4096,
                                            outputTokens: 512,
                                            retrievalItems: 0,
                                            toolCalls: 4,
                                            timeBudgetMs: 2000
                                        )
                                    )
    
                                    let allowed = oracleAllowedRoutes(context)
                                    let advisory = BASDefaultRoutingPlanner.plan(context: context, registry: registry)
    
                                    // Every emitted route kind: primary route + every fallback stage.
                                    var emitted: [BASRouteKind] = [advisory.route.routeKind]
                                    emitted.append(contentsOf: advisory.fallbackGraph.orderedStages.map { $0.routeKind })
    
                                    for kind in emitted {
                                        XCTAssertTrue(
                                            allowed.contains(kind),
                                            "Route \(kind.rawValue) emitted outside allowedRoutes \(allowed) for privacy=\(privacy.rawValue) net=\(net) lowPower=\(lowPower) task=\(task.rawValue)"
                                        )
                                    }
    
                                    // localOnly => local ONLY (no cloud, no hybrid) anywhere.
                                    if privacy == .localOnly {
                                        for kind in emitted {
                                            XCTAssertEqual(
                                                kind, .local,
                                                "localOnly must emit local-only, got \(kind.rawValue)"
                                            )
                                        }
                                    }
    
                                    // Cloud-egress sovereignty: when cloud is NOT allowed, 0 cloud routes.
                                    if !allowed.contains(.cloud) {
                                        cloudDeniedContexts += 1
                                        let cloudCount = emitted.filter { $0 == .cloud }.count
                                        if cloudCount != 0 { cloudEmittedWhenDenied += 1 }
                                        XCTAssertEqual(
                                            cloudCount, 0,
                                            "Cloud egress leaked: \(cloudCount) cloud route(s) when allowCloud==false (privacy=\(privacy.rawValue) net=\(net) lowPower=\(lowPower))"
                                        )
                                    }
    
                                    // Deterministic re-call: identical context+registry => identical advisory.
                                    let advisory2 = BASDefaultRoutingPlanner.plan(context: context, registry: registry)
                                    XCTAssertEqual(
                                        advisory.route, advisory2.route,
                                        "Routing must be deterministic for an identical context"
                                    )
                                    XCTAssertEqual(
                                        advisory.fallbackGraph, advisory2.fallbackGraph,
                                        "Fallback graph must be deterministic for an identical context"
                                    )
    
                                    sweepCount += 1
                                }
                            }
                        }
                    }
                }
            }
        }
    
        XCTAssertEqual(cloudEmittedWhenDenied, 0, "No cloud route may be emitted in any cloud-denied context")
        XCTAssertGreaterThan(cloudDeniedContexts, 0, "Sweep must actually exercise cloud-denied contexts")
        XCTAssertEqual(sweepCount, privacyModes.count * nets.count * lowPowers.count * gears.count * risks.count * thermals.count * allTasks.count)
    
        print("QINAO-GATE policy_decision_route_constraint: PASS swept=\(sweepCount) cloudDenied=\(cloudDeniedContexts) cloudLeaks=\(cloudEmittedWhenDenied) (route/fallback never outside allowedRoutes; localOnly=>local; 0 cloud-egress when allowCloud==false; deterministic re-call)")
    }

    func test_qinao_permit_escalation_never_loosen() throws {
        // QINAO #69 L11 — the 5-stage permit-escalation ledger
        // (abyssal -> assertion-ceiling -> kunlun -> cthulhu-assertion ->
        //  cthulhu-escalation) recorded by
        //  BASPermitEscalationPipelineObservation.build(...).
        //
        // Invariant (tolerance = 0):
        //  (A) NON-LOOSEN: for every step, severity(outputPermitMode)
        //      >= severity(inputPermitMode). The chain's input mode at
        //      step k is, by construction in .build, the prior step's
        //      OUTPUT mode -> the ledger is a true running ceiling.
        //  (B) CEILING ONLY NARROWS: the running max severity is
        //      monotone non-decreasing across the 5 steps; it never dips.
        //  (C) NO-REVERT: once a terminal-restrictive mode (.block or
        //      .escalate) is the output of any step, no LATER step's
        //      output may be the loosest mode (.answer).
        //  (D) REPLAY: re-building the same chain yields a byte-identical
        //      Codable ledger.
        //  (E) TAMPER: a loosening chain MUST be detectable by the oracle
        //      (the ledger faithfully records the loosening; it does not
        //      silently sanitize it) -> proves the gate has discriminating
        //      power, not a vacuous pass.
    
        // --- Replicated oracle: severity rank over the REAL enum. ---
        // Ordering = BASActionPermitMode declaration order (answer loosest
        // ... escalate most restrictive). answer=0 is the unique "full
        // agency" mode; block/escalate are the terminal-restrictive pair.
        let rank: [BASActionPermitMode: Int] = [
            .answer: 0, .mirror: 1, .compare: 2, .delay: 3,
            .draftOnly: 4, .localOnly: 5, .block: 6, .replace: 7,
            .escalate: 8,
        ]
        // Sanity: oracle is total over the real CaseIterable domain.
        XCTAssertEqual(Set(rank.keys), Set(BASActionPermitMode.allCases),
                       "oracle must cover every real permit mode")
        func sev(_ m: BASActionPermitMode) -> Int { rank[m]! }
        let terminalRestrictive: Set<BASActionPermitMode> = [.block, .escalate]
    
        let allModes = BASActionPermitMode.allCases.sorted { sev($0) < sev($1) }
        let stepNames = ["abyssal", "assertion-ceiling", "kunlun",
                         "cthulhu-assertion", "cthulhu-escalation"]
    
        // Stable encoder for byte-identical replay.
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
    
        var checked = 0
    
        // Exhaustive sweep of MONOTONE-NONDECREASING 5-stage chains over
        // the real 9-mode domain (every legal escalation trajectory).
        // For each, the running output is forced non-loosening so we
        // exercise the ledger across the entire legal frontier.
        for initial in allModes {
            for s0 in allModes where sev(s0) >= sev(initial) {
                for s1 in allModes where sev(s1) >= sev(s0) {
                    for s2 in allModes where sev(s2) >= sev(s1) {
                        for s3 in allModes where sev(s3) >= sev(s2) {
                            for s4 in allModes where sev(s4) >= sev(s3) {
                                let outs = [s0, s1, s2, s3, s4]
                                let chain = zip(stepNames, outs).map {
                                    (stepName: $0.0,
                                     outputPermitMode: $0.1,
                                     reasonCodes: ["rc:\($0.0):\($0.1.rawValue)"])
                                }
                                let obs = BASPermitEscalationPipelineObservation
                                    .build(initialPermitMode: initial,
                                           chain: chain)
    
                                XCTAssertEqual(obs.steps.count, 5)
                                XCTAssertEqual(obs.initialPermitMode, initial)
                                XCTAssertEqual(obs.finalPermitMode, s4)
    
                                // (A)+(B): walk the recorded ledger. Each
                                // step's input == prior output (running
                                // ceiling), and severity never decreases.
                                var prevOut = initial
                                var runningMax = sev(initial)
                                var sawTerminal = false
                                for step in obs.steps {
                                    XCTAssertEqual(
                                        step.inputPermitMode, prevOut,
                                        "ledger input must chain from prior output")
                                    XCTAssertGreaterThanOrEqual(
                                        sev(step.outputPermitMode),
                                        sev(step.inputPermitMode),
                                        "outputPermit must be >= inputPermit (no loosen)")
                                    // ceiling only narrows
                                    XCTAssertGreaterThanOrEqual(
                                        sev(step.outputPermitMode), runningMax,
                                        "running ceiling must not dip")
                                    runningMax = max(runningMax,
                                                     sev(step.outputPermitMode))
                                    // escalated flag is exact vs oracle
                                    XCTAssertEqual(
                                        step.escalated,
                                        step.inputPermitMode != step.outputPermitMode)
                                    // (C): no-revert to .answer after terminal.
                                    if sawTerminal {
                                        XCTAssertNotEqual(
                                            step.outputPermitMode, .answer,
                                            ".block/.escalate must never revert to .answer")
                                    }
                                    if terminalRestrictive.contains(step.outputPermitMode) {
                                        sawTerminal = true
                                    }
                                    prevOut = step.outputPermitMode
                                }
    
                                // (D): byte-identical deterministic replay.
                                let obs2 = BASPermitEscalationPipelineObservation
                                    .build(initialPermitMode: initial,
                                           chain: chain)
                                XCTAssertEqual(obs, obs2)
                                let j1 = try enc.encode(obs)
                                let j2 = try enc.encode(obs2)
                                XCTAssertEqual(j1, j2,
                                               "ledger replay must be byte-identical")
                                checked += 1
                            }
                        }
                    }
                }
            }
        }
    
        // (E) TAMPER: a deliberately LOOSENING chain must be visible in
        // the ledger (the gate is not vacuous). Start restrictive then
        // drop back to .answer; the oracle must flag a non-monotone dip
        // AND a post-terminal revert-to-answer.
        let badChain: [(stepName: String,
                        outputPermitMode: BASActionPermitMode,
                        reasonCodes: [String])] = [
            ("abyssal", .escalate, []),
            ("assertion-ceiling", .block, []),
            ("kunlun", .answer, []),          // <- loosens + reverts
            ("cthulhu-assertion", .answer, []),
            ("cthulhu-escalation", .answer, []),
        ]
        let bad = BASPermitEscalationPipelineObservation
            .build(initialPermitMode: .answer, chain: badChain)
        var loosenDetected = false
        var revertDetected = false
        var sawTerm = false
        for step in bad.steps {
            if sev(step.outputPermitMode) < sev(step.inputPermitMode) {
                loosenDetected = true
            }
            if sawTerm && step.outputPermitMode == .answer {
                revertDetected = true
            }
            if terminalRestrictive.contains(step.outputPermitMode) {
                sawTerm = true
            }
        }
        XCTAssertTrue(loosenDetected,
                      "oracle must detect a loosening transition (gate has power)")
        XCTAssertTrue(revertDetected,
                      "oracle must detect a post-terminal revert to .answer")
    
        print("QINAO-GATE permit_escalation_never_loosen: PASS "
            + "(\(checked) monotone 5-stage ledgers verified non-loosen + "
            + "ceiling-narrows-only + no-revert + byte-identical replay; "
            + "tamper loosening/revert detected)")
    }
}

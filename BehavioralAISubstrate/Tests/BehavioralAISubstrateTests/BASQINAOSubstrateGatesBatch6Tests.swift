import XCTest
@testable import BASLeaseLife
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
import CryptoKit
import Foundation
import SQLite3

/// QINAO Substrate-100 gates — Phase-2 batch 6 (scheduler/sovereignty/tribunal/release; agent-drafted, author-verified).
final class BASQINAOSubstrateGatesBatch6Tests: XCTestCase {

    func test_qinao_emergency_cancels_all_breaths() async throws {
        // L1 kill-stop gate: when the thermal guard rises to .emergency,
        // BASBreathScheduler.reconcile(with: .emergency) MUST cancel ALL
        // in-flight/admitted breaths — 0 active breaths remain afterward,
        // for every maintenance class, and the cancel must reach the bridge.
        let bridge = QINAORecordingBridge()
        let scheduler = BASBreathScheduler(bridge: bridge)
    
        // Admit one breath per non-emergency-eligible class. Under .nominal
        // every class is allowed (mirrors testEmergencyCancelsAllExistingBreaths),
        // so we admit the full small domain to make the sweep exhaustive.
        var admittedIDs: [String] = []
        var i = 0
        for c in BASMaintenanceClass.allCases {
            // .nominal accepts all classes (see validate()).
            let id = "breath-\(i)-\(c)"
            let req = BASBreathScheduler.Request(
                id: id,
                maintenanceClass: c,
                earliestFireAt: Date(timeIntervalSince1970: TimeInterval(60 + i)))
            _ = try await scheduler.schedule(req, guardLevel: .nominal)
            admittedIDs.append(id)
            i += 1
        }
    
        // Precondition: every admitted breath is live.
        let before = await scheduler.count()
        XCTAssertEqual(before, admittedIDs.count,
            "all admitted breaths must be live before the emergency kill-stop")
        XCTAssertGreaterThan(before, 0,
            "the gate is vacuous unless at least one breath was admitted")
    
        // Kill-stop path.
        await scheduler.reconcile(with: .emergency)
    
        // Raised bar 1: zero active breaths remain — tolerance = 0 (count()).
        let afterCount = await scheduler.count()
        XCTAssertEqual(afterCount, 0,
            "emergency must cancel ALL in-flight breaths; expected 0, got \(afterCount)")
    
        // Raised bar 2: the live-breath listing is also empty (independent oracle).
        let remaining = await scheduler.scheduledBreaths()
        XCTAssertTrue(remaining.isEmpty,
            "scheduledBreaths() must be empty after emergency; leaked: \(remaining.map(\.request.id))")
    
        // Raised bar 3: the kill reached the platform — every admitted id was
        // cancelled through the bridge (no silent drop).
        let cancels = await bridge.cancels()
        XCTAssertEqual(Set(cancels), Set(admittedIDs),
            "every admitted breath must be cancelled via the bridge under emergency")
    
        // Raised bar 4: idempotent / deterministic — re-applying emergency stays 0.
        await scheduler.reconcile(with: .emergency)
        let afterSecond = await scheduler.count()
        XCTAssertEqual(afterSecond, 0,
            "re-reconciling at emergency must remain a fixed point at 0")
    
        print("QINAO-GATE emergency_cancels_all_breaths: PASS "
            + "(admitted=\(admittedIDs.count) before=\(before) "
            + "after=\(afterCount) bridgeCancels=\(cancels.count) idempotent=\(afterSecond))")
    }
    
    /// Test double mirrored from BASBreathSchedulerTests.RecordingBridge
    /// (actor-isolated so the test observes forwarded cancels without races).
    private actor QINAORecordingBridge: BASBreathScheduler.PlatformBridge {
        private var registered: [String] = []
        private var cancelled: [String] = []
        func register(_ request: BASBreathScheduler.Request) async -> Bool {
            registered.append(request.id)
            return true
        }
        func cancel(id: String) async { cancelled.append(id) }
        func registrations() -> [String] { registered }
        func cancels() -> [String] { cancelled }
    }

    func test_qinao_governed_excluded_domains_adherence() async throws {
        // QINAO #37 L8 — when excludingDomains is passed to governed
        // RAG retrieval, ZERO returned candidates may originate from
        // an excluded domain. Bar = tolerance-0 leak count.
        //
        // Strategy: stage a corpus across many domains, mark a
        // sensitive subset (medical / financial / legal) as excluded,
        // run the governed retrieve() with a large k (so the index
        // would otherwise return everything), then count leaked atoms.
        // Oracle replicates BASVectorIndex.domainExcluded exactly
        // (case-insensitive substring match against each pattern).
        let provider = BASStubEmbeddingProvider(dimension: 32)
        let index = BASVectorIndex()
    
        // Domain corpus: atomID -> domain. Mix of sensitive +
        // benign, plus case/substring edge cases.
        let atomDomains: [String: String] = [
            "med-1": "user.medical_records",
            "med-2": "USER.MEDICAL.history",        // upper-case probe
            "fin-1": "user.financial.bank",
            "fin-2": "user.financial.brokerage",
            "legal-1": "user.legal.contracts",
            "notes-1": "user.notes",
            "tasks-1": "user.tasks",
            "calendar-1": "user.calendar",
            "embedfin": "user.profinance.notes",    // substring "fin" trap
            "plain-domainless": ""                   // empty domain never excluded
        ]
        for (atomID, domain) in atomDomains.sorted(by: { $0.key < $1.key }) {
            let e = await provider.embed(atomID)
            try await index.insert(BASVectorIndexEntry(
                atomID: atomID,
                normalizedEmbedding: e.normalized,
                domain: domain))
        }
    
        // Sensitive subset declared excluded (substring patterns).
        let excludedPatterns = ["medical", "financial", "legal", "fin"]
    
        // Replicated oracle: mirror BASVectorIndex.domainExcluded —
        // empty domain never excluded; else case-insensitive
        // substring of any non-empty trimmed pattern.
        func oracleExcluded(_ domain: String) -> Bool {
            guard !domain.isEmpty else { return false }
            let lowered = domain.lowercased()
            for pattern in excludedPatterns {
                let trimmed = pattern.trimmingCharacters(
                    in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if lowered.contains(trimmed.lowercased()) { return true }
            }
            return false
        }
        let oracleAllowed = Set(atomDomains.filter {
            !oracleExcluded($0.value)
        }.keys)
        let oracleExcludedIDs = Set(atomDomains.keys)
            .subtracting(oracleAllowed)
        XCTAssertFalse(oracleExcludedIDs.isEmpty,
            "Test corpus must actually contain excluded atoms")
    
        // atomLookup resolves every staged id (no stale skips), so
        // any allowed candidate becomes a returned atom.
        let atomLookup: @Sendable (String) async -> BASMemoryAtom? = { id in
            BASMemoryAtom(
                memoryID: id,
                summary: "summary of \(id)",
                contentType: .hot,
                source: "test",
                confidence: 0.5,
                conflictFingerprint: id)
        }
    
        let result = await BASRAGRetriever.retrieve(
            queryText: "governed retrieval probe",
            embeddingProvider: provider,
            vectorIndex: index,
            atomLookup: atomLookup,
            k: 100,                       // larger than corpus → no top-k truncation
            excludingDomains: excludedPatterns)
    
        // HARD BAR: zero leaked atoms from any excluded domain.
        let returnedIDs = Set(result.atoms.map { $0.memoryID })
        let leaked = returnedIDs.intersection(oracleExcludedIDs)
        XCTAssertEqual(leaked.count, 0,
            "Excluded-domain leak: \(leaked.sorted()) escaped the " +
            "governed retrieval filter")
        XCTAssertTrue(result.scores.keys
            .allSatisfy { !oracleExcludedIDs.contains($0) },
            "Excluded atom present in score map (leak)")
    
        // Exact-set adherence: returned set == oracle allowed set.
        XCTAssertEqual(returnedIDs, oracleAllowed,
            "Governed result must equal the oracle-allowed set exactly")
    
        // Audit reason code records the exclusion count.
        XCTAssertTrue(result.reasonCodes.contains(
            "rag:excluded-domains:\(excludedPatterns.count)"),
            "Excluded-domains audit reason code must be emitted")
    
        // Determinism: re-call with identical inputs yields the
        // same allowed set and still zero leaks.
        let result2 = await BASRAGRetriever.retrieve(
            queryText: "governed retrieval probe",
            embeddingProvider: provider,
            vectorIndex: index,
            atomLookup: atomLookup,
            k: 100,
            excludingDomains: excludedPatterns)
        let returnedIDs2 = Set(result2.atoms.map { $0.memoryID })
        XCTAssertEqual(returnedIDs2, oracleAllowed,
            "Deterministic re-call must reproduce the allowed set")
        XCTAssertEqual(returnedIDs2.intersection(oracleExcludedIDs).count, 0,
            "Deterministic re-call must also leak zero excluded atoms")
    
        // Control: with NO exclusions, the sensitive atoms DO appear
        // (proves the filter, not an empty index, drove the zero).
        let unfiltered = await BASRAGRetriever.retrieve(
            queryText: "governed retrieval probe",
            embeddingProvider: provider,
            vectorIndex: index,
            atomLookup: atomLookup,
            k: 100)
        let unfilteredIDs = Set(unfiltered.atoms.map { $0.memoryID })
        XCTAssertTrue(oracleExcludedIDs.isSubset(of: unfilteredIDs),
            "Without exclusions the sensitive atoms must be retrievable " +
            "(otherwise the zero-leak result is vacuous)")
    
        print("QINAO-GATE governed_excluded_domains_adherence: PASS " +
            "corpus=\(atomDomains.count) excludedPatterns=\(excludedPatterns.count) " +
            "allowed=\(oracleAllowed.count) excludedAtoms=\(oracleExcludedIDs.count) " +
            "returned=\(returnedIDs.count) leaked=\(leaked.count) " +
            "(unfiltered exposed all \(oracleExcludedIDs.count) sensitive atoms)")
    }
    // [DEDUP] shared_wal_durability lives in QINAOGateSharedWALDurabilityTests.swift (removed duplicate)
    
    // ── helpers (same XCTestCase) ──
    //     tempURL = FileManager.default.temporaryDirectory
    // }
    //     if let tempURL {
    //     }
    // }
    //     var stmt: OpaquePointer?
    //     XCTAssertEqual(sqlite3_prepare_v2(db, "PRAGMA \(pragma);", -1, &stmt, nil), SQLITE_OK, "prepare PRAGMA \(pragma)")
    //     defer { sqlite3_finalize(stmt) }
    //     guard sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) else { return "" }
    //     return String(cString: c)
    // }
    //     var stmt: OpaquePointer?
    //     XCTAssertEqual(sqlite3_prepare_v2(db, "PRAGMA \(pragma);", -1, &stmt, nil), SQLITE_OK, "prepare PRAGMA \(pragma)")
    //     defer { sqlite3_finalize(stmt) }
    //     XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW, "row for PRAGMA \(pragma)")
    //     return Int(sqlite3_column_int64(stmt, 0))
    // }

    func test_qinao_entry_plan_approval_coverage() {
        // Metric #63: BASWorkflowState.plan(for:) must require manual approval
        // (approvalRequirement != .none, i.e. "approvalRequired == true") whenever
        // riskLevel == .high OR entryKind == .reopen. Exhaustive over the full
        // BASIntentEntryKind x BASRiskLevel small domain (4 x 3 = 12) with a
        // replicated oracle and tolerance == 0.
        let allEntryKinds: [BASIntentEntryKind] = [.capture, .reopen, .predictive, .resume]
        let allRiskLevels: [BASRiskLevel] = [.low, .medium, .high]
    
        var covered = 0
        for entryKind in allEntryKinds {
            for riskLevel in allRiskLevels {
                let intent = BASIntentEnvelope(
                    entryKind: entryKind,
                    surface: .app,
                    riskLevel: riskLevel,
                    payloadSummary: "qinao sweep \(entryKind.rawValue)/\(riskLevel.rawValue)"
                )
    
                // Deterministic re-call: plan(for:) must be pure for a given intent.
                let state = BASWorkflowState()
                let plan = state.plan(for: intent)
                let planAgain = state.plan(for: intent)
                XCTAssertEqual(
                    plan.approvalRequirement, planAgain.approvalRequirement,
                    "plan(for:) must be deterministic for \(entryKind)/\(riskLevel)")
    
                // Replicated oracle: approval is required iff high risk OR reopen.
                let oracleRequiresApproval = (riskLevel == .high) || (entryKind == .reopen)
                let actualRequiresApproval = (plan.approvalRequirement != .none)
    
                XCTAssertEqual(
                    actualRequiresApproval, oracleRequiresApproval,
                    "approvalRequired mismatch for entryKind=\(entryKind) riskLevel=\(riskLevel): "
                        + "got \(plan.approvalRequirement), expected requiresApproval=\(oracleRequiresApproval)")
    
                // The exact .manual(reason:) contract that backs the boolean gate.
                if oracleRequiresApproval {
                    if riskLevel == .high {
                        XCTAssertEqual(
                            plan.approvalRequirement,
                            .manual(reason: "high risk intent requires review"),
                            "high-risk reason mismatch for \(entryKind)/\(riskLevel)")
                    } else {
                        // entryKind == .reopen with non-high risk
                        XCTAssertEqual(
                            plan.approvalRequirement,
                            .manual(reason: "reopen requires explicit resume context"),
                            "reopen reason mismatch for \(entryKind)/\(riskLevel)")
                    }
                } else {
                    XCTAssertEqual(
                        plan.approvalRequirement, .none,
                        "expected no approval for \(entryKind)/\(riskLevel)")
                }
    
                // Envelope identity must flow through unchanged.
                XCTAssertEqual(plan.envelopeID, intent.id)
    
                covered += 1
            }
        }
    
        XCTAssertEqual(covered, allEntryKinds.count * allRiskLevels.count, "must exhaust the full entryKind x riskLevel domain")
        XCTAssertEqual(covered, 12, "expected 4 entryKinds x 3 riskLevels = 12 combinations")
    
        print("QINAO-GATE entry_plan_approval_coverage: PASS (\(covered) entryKind x riskLevel combinations; approvalRequired == (riskLevel==.high || entryKind==.reopen), tolerance=0, deterministic re-call verified)")
    }

    func test_qinao_tribunal_full_body_coverage() {
        // #64 — BASTribunalCoverageReport.isFullBody is true IFF all three
        // canonical voices (baseSelf / ruleSelf / aspireSelf) emitted >=1
        // observation. Exhaustive sweep over every presence subset (2^3 = 8),
        // tolerance=0, with a replicated oracle and a deterministic re-call.
        let allVoices = BASTribunalVoice.allCases
        XCTAssertEqual(Set(allVoices),
                       [.baseSelf, .ruleSelf, .aspireSelf],
                       "Exactly the 3 canonical voices must exist; "
                       + "the IFF bar is defined over this domain.")
        let n = allVoices.count
        XCTAssertEqual(n, 3, "isFullBody bar assumes 3 voices.")
    
        var checked = 0
        var fullBodyCount = 0
    
        // Enumerate all 8 subsets of the 3-voice domain via a bitmask.
        for mask in 0..<(1 << n) {
            var present: Set<BASTribunalVoice> = []
            for (i, voice) in allVoices.enumerated() where (mask & (1 << i)) != 0 {
                present.insert(voice)
            }
    
            let report = BASTribunalCoverageReport(
                voicesPresent: present,
                subjectIDs: present.isEmpty ? [] : ["c1"],
                hasConvergence: false,
                hasDissent: false)
    
            // Replicated oracle: full-body IFF the present set equals the
            // entire 3-voice domain (i.e. all three flagged in the mask).
            let oracle = (mask == (1 << n) - 1)
            let actual = report.isFullBody
    
            XCTAssertEqual(actual, oracle,
                           "isFullBody mismatch for subset \(present) "
                           + "(mask=\(mask)): expected \(oracle).")
    
            // Determinism: re-derive on a freshly built report — same answer.
            let report2 = BASTribunalCoverageReport(
                voicesPresent: present,
                subjectIDs: [],
                hasConvergence: false,
                hasDissent: false)
            XCTAssertEqual(report2.isFullBody, actual,
                           "isFullBody must be deterministic for \(present).")
    
            // Cross-check the partner derivation: silentVoices is exactly the
            // complement, and is empty IFF full-body.
            XCTAssertEqual(report.silentVoices,
                           Set(allVoices).subtracting(present),
                           "silentVoices must be the exact complement.")
            XCTAssertEqual(report.silentVoices.isEmpty, oracle,
                           "silentVoices empty IFF isFullBody.")
    
            if oracle { fullBodyCount += 1 }
            checked += 1
        }
    
        XCTAssertEqual(checked, 8, "Must sweep all 2^3 presence subsets.")
        XCTAssertEqual(fullBodyCount, 1,
                       "Exactly one subset (all three present) is full-body.")
    
        print("QINAO-GATE tribunal_full_body_coverage: PASS "
              + "(\(checked) presence subsets swept; isFullBody true for "
              + "exactly the all-3-voices subset; silentVoices complement + "
              + "determinism verified)")
    }

    func test_qinao_tribunal_veto_monotonicity() throws {
        // QINAO #65 L10: tribunal verdict aggregation =
        // `BASTribunalObservationBundle.derive(from:...)`. The tribunal
        // "verdict = PASS" is operationalized as the `.convergence`
        // observation being emitted (decision draft present + all three
        // voices agree + NO vetos — see derive() docs §.convergence and
        // convergenceObservation() guard `hasVetos == false`).
        //
        // VETO MONOTONICITY (raised bar): ANY BASVetoMark on the frame
        // forces NOT-pass — a veto can never be outvoted. We prove this
        // exhaustively against the MAXIMAL "should pass" baseline (a
        // unanimous strongly-affirming tribunal + a ready decision
        // draft), sweeping every BASCourtVetoType case × both compensable
        // values. tolerance = 0: convergence count must be EXACTLY 0 in
        // every vetoed configuration and EXACTLY 1 in the clean control.
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
    
        // Maximal "should pass" baseline: unanimous affirm (all >= 0.6)
        // on cand-1, plus a decision draft preferring cand-1.
        let affirmScore = BASTriSelfScore(
            candidateID: "cand-1",
            idScore: 0.9,
            egoScore: 0.9,
            superegoScore: 0.9,
            mergedScore: 0.95,
            veto: false)
        let draft = BASCourtDecisionDraft(
            preferredCandidateID: "cand-1",
            readinessLevel: "ready")
    
        // --- Positive control: no veto => verdict PASS (converges). ---
        let cleanFrame = BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "d-1",
            triScores: [affirmScore],
            vetoMarks: nil,
            remandOrders: nil,
            courtDecisionDraft: draft)
        let cleanBundle = BASTribunalObservationBundle.derive(
            from: cleanFrame,
            turnID: "t-clean",
            sessionID: "s",
            emittedAt: fixedDate)
        XCTAssertEqual(
            cleanBundle.observations(of: .convergence).count, 1,
            "baseline must PASS (converge) when no veto is present — " +
            "otherwise the monotonicity sweep proves nothing")
    
        // --- Exhaustive veto sweep: every vetoType x compensable. ---
        // BASCourtVetoType is CaseIterable; verbatim cases:
        // boundary / dignity / hostConstitution / irreversibility /
        // sovereignPrecondition / calibration.
        var sweptConfigs = 0
        for vetoType in BASCourtVetoType.allCases {
            for compensable in [false, true] {
                let mark = BASVetoMark(
                    candidateID: "cand-1",
                    vetoType: vetoType,
                    reasonCodes: ["reason-a"],
                    compensable: compensable)
                // Identical maximal-affirm frame, now carrying ONE veto.
                let vetoedFrame = BASThoughtFrame(
                    stepIndex: 0,
                    decomposeRef: "d-1",
                    triScores: [affirmScore],
                    vetoMarks: [mark],
                    remandOrders: nil,
                    courtDecisionDraft: draft)
                let bundle = BASTribunalObservationBundle.derive(
                    from: vetoedFrame,
                    turnID: "t-\(vetoType.rawValue)-\(compensable)",
                    sessionID: "s",
                    emittedAt: fixedDate)
    
                // The veto can NEVER be outvoted: convergence (= PASS)
                // is suppressed for every type, compensable or not.
                XCTAssertTrue(
                    bundle.observations(of: .convergence).isEmpty,
                    "veto \(vetoType.rawValue) compensable=\(compensable) " +
                    "must force NOT-pass even with a unanimous tribunal")
                // And the veto is faithfully surfaced as an objection
                // (the structural record the verdict is monotone over).
                XCTAssertEqual(
                    bundle.observations(of: .objection).count, 1,
                    "the veto must materialize as exactly one objection")
                // Non-compensable / boundary / dignity / hostConstitution
                // are the named hard-veto family: confirm a compensable
                // veto is STILL non-pass (compensability never rescues PASS).
                sweptConfigs += 1
            }
        }
        // 6 veto types x 2 compensable flags = 12 forced non-pass configs.
        XCTAssertEqual(sweptConfigs, 12)
        XCTAssertEqual(BASCourtVetoType.allCases.count, 6)
    
        // --- Monotonicity step: adding ANY veto to the PASSING frame
        // flips PASS -> NOT-pass; removing it restores PASS. Deterministic
        // re-derive of the clean frame must reproduce PASS byte-stably. ---
        let cleanReDerive = BASTribunalObservationBundle.derive(
            from: cleanFrame,
            turnID: "t-clean",
            sessionID: "s",
            emittedAt: fixedDate)
        XCTAssertEqual(
            cleanReDerive.observations(of: .convergence).count, 1,
            "deterministic re-derive must reproduce the PASS verdict")
        XCTAssertEqual(
            cleanReDerive, cleanBundle,
            "derive is deterministic: same frame -> identical bundle")
    
        print("QINAO-GATE tribunal_veto_monotonicity: PASS " +
              "(clean frame converges=PASS; all 12 vetoType x " +
              "compensable configs force NOT-pass — a veto can never " +
              "be outvoted; deterministic re-derive stable)")
    }

    func test_qinao_release_consistency_gate() {
        // Mirror of BASCognitionKernelTests.releaseDecisionRejectsOrRepairsBasedOnViolationSeverity:
        // attach a BASStructuredTruthState to the kernel, then drive BASCognitionKernel.releaseDecision.
        let truth = BASStructuredTruthState(
            mode: "predictive_intervention_notification",
            currentGoal: "protect sleep",
            allowedActions: ["send_predictive_notification"],
            forbiddenActions: ["send_now"],
            personaRules: ["brief", "non-judgmental"],
            sessionFacts: ["boundary_mode": "local_only_protective"]
        )
    
        let block = BASContextBlock(
            id: "frontstage_state",
            layer: .kernel,
            title: "Frontstage",
            content: "Protect sleep first.",
            retention: .required,
            priority: 120
        )
    
        let kernel = BASCognitionKernel.compile(
            BASCognitionKernelRequest(
                blocks: [block],
                compilationPolicy: BASContextCompilationPolicy(targetCharacters: 120),
                truthState: truth
            )
        )
        XCTAssertNotNil(kernel.truthState, "truth state must be attached to the kernel snapshot")
    
        // (1) forbiddenAction -> BLOCK release (reject), tolerance 0 on the kind.
        let forbidden = BASCognitionKernel.releaseDecision(
            for: BASCognitionKernelReleaseRequest(
                kernel: kernel,
                responseMode: "predictive_intervention_notification",
                responseText: "Sending the notification now.",
                proposedActions: ["send_now"]
            )
        )
        XCTAssertEqual(forbidden.kind, .reject, "a forbidden action must block release")
        let forbiddenViolations = forbidden.consistencyCheck?.violations ?? []
        XCTAssertTrue(forbiddenViolations.contains { $0.kind == .forbiddenAction })
        XCTAssertFalse(forbidden.consistencyCheck?.isConsistent ?? true)
    
        // (2) modeMismatch -> BLOCK release (reject).
        let modeMismatch = BASCognitionKernel.releaseDecision(
            for: BASCognitionKernelReleaseRequest(
                kernel: kernel,
                responseMode: "casual_chat",
                responseText: "Here is a gentle, brief note.",
                proposedActions: ["send_predictive_notification"]
            )
        )
        XCTAssertEqual(modeMismatch.kind, .reject, "a mode mismatch must block release")
        let modeViolations = modeMismatch.consistencyCheck?.violations ?? []
        XCTAssertTrue(modeViolations.contains { $0.kind == .modeMismatch })
    
        // (2b) both modeMismatch AND forbiddenAction present together -> still reject.
        let bothBad = BASCognitionKernel.releaseDecision(
            for: BASCognitionKernelReleaseRequest(
                kernel: kernel,
                responseMode: "casual_chat",
                responseText: "Sending now.",
                proposedActions: ["send_now"]
            )
        )
        XCTAssertEqual(bothBad.kind, .reject)
        let bothKinds = Set((bothBad.consistencyCheck?.violations ?? []).map { $0.kind })
        XCTAssertTrue(bothKinds.contains(.modeMismatch))
        XCTAssertTrue(bothKinds.contains(.forbiddenAction))
    
        // (3) fully consistent -> RELEASE (allow), with no violations.
        let consistentRequest = BASCognitionKernelReleaseRequest(
            kernel: kernel,
            responseMode: "predictive_intervention_notification",
            responseText: "A brief, gentle, protective note.",
            proposedActions: ["send_predictive_notification"]
        )
        let allowed = BASCognitionKernel.releaseDecision(for: consistentRequest)
        XCTAssertEqual(allowed.kind, .allow, "a consistent response must be released")
        XCTAssertTrue(allowed.consistencyCheck?.isConsistent ?? false)
        XCTAssertEqual(allowed.consistencyCheck?.violations.count, 0)
    
        // Determinism: the pure release decision must be byte-stable on re-call.
        let allowedAgain = BASCognitionKernel.releaseDecision(for: consistentRequest)
        XCTAssertEqual(allowed, allowedAgain, "releaseDecision must be deterministic on identical input")
    
        // Mutate-and-assert (safety gate): swapping an allowed action for a forbidden one
        // must FLIP a released decision into a blocked one.
        let mutated = BASCognitionKernelReleaseRequest(
            kernel: kernel,
            responseMode: consistentRequest.responseMode,
            responseText: consistentRequest.responseText,
            proposedActions: ["send_now"]
        )
        let mutatedDecision = BASCognitionKernel.releaseDecision(for: mutated)
        XCTAssertNotEqual(mutatedDecision.kind, allowed.kind, "introducing a forbidden action must change the verdict")
        XCTAssertEqual(mutatedDecision.kind, .reject)
    
        print("QINAO-GATE release_consistency_gate: PASS (forbidden=\(forbidden.kind) modeMismatch=\(modeMismatch.kind) both=\(bothBad.kind) consistent=\(allowed.kind) deterministic=\(allowed == allowedAgain) mutateFlips=\(mutatedDecision.kind != allowed.kind))")
    }

    func test_qinao_cloud_egress_sovereignty() {
        // QINAO #68 L10: under any localOnly/localFirst/childSafe profile, a request
        // governed by an allowCloud==false rule NEVER receives a cloud egress route.
        // Exhaustive profile x rule x risk x scope x sensitivity grid, tolerance=0.
    
        let sovereignPresets: [BASPolicyProfilePreset] = [.localOnly, .localFirst, .childSafe]
        let allRisks: [BASRiskLevel] = [.low, .medium, .high]
        let allScopes: [BASMemoryScope] = [.user, .device, .session, .task]
        let allSensitivities: [BASMemorySensitivity] = [.low, .medium, .high]
        let allEnforcementPoints = BASEnforcementPoint.allCases
    
        var cloudEgressAllowCount = 0
        var noCloudRulesExercised = 0
        var gridCells = 0
    
        for preset in sovereignPresets {
            let policySet = BASPolicyProfiles.make(preset)
    
            // Only rules that forbid cloud egress are governed by this gate.
            let noCloudRules = policySet.rules.filter { !$0.allowCloud }
            XCTAssertFalse(
                noCloudRules.isEmpty,
                "sovereign profile \(preset.rawValue) must declare at least one allowCloud==false rule"
            )
    
            for rule in noCloudRules {
                noCloudRulesExercised += 1
    
                // Pick a scope/sensitivity that this rule does NOT block, so the
                // decision is driven by the cloud-egress branch (not a scope/sens block).
                // Replicated oracle: a no-cloud rule, when cloud is requested and the
                // rule matches, MUST deny cloud egress -> .deny, NEVER .allow.
                for enforcementPoint in rule.enforcementPoints {
                    for risk in allRisks {
                        for scope in allScopes where !rule.blockedScopes.contains(scope) {
                            for sensitivity in allSensitivities where !rule.blockedSensitivities.contains(sensitivity) {
                                gridCells += 1
    
                                let decision = policySet.decide(
                                    at: enforcementPoint,
                                    actionClass: rule.actionClass,
                                    riskLevel: risk,
                                    scope: scope,
                                    sensitivity: sensitivity,
                                    cloudRequested: true
                                )
    
                                // The raised bar: cloud egress is NEVER granted.
                                if decision.decision == .allow {
                                    cloudEgressAllowCount += 1
                                }
                                XCTAssertNotEqual(
                                    decision.decision,
                                    .allow,
                                    "CLOUD EGRESS LEAK: profile=\(preset.rawValue) rule=\(rule.id) ep=\(enforcementPoint.rawValue) risk=\(risk.rawValue) scope=\(scope.rawValue) sens=\(sensitivity.rawValue) granted cloud egress"
                                )
    
                                // Because no other no-cloud rule blocks this scope/sens,
                                // and another matching rule could only deny for cloud too,
                                // the sovereign refusal must be a hard deny citing cloud.
                                XCTAssertEqual(
                                    decision.decision,
                                    .deny,
                                    "sovereign no-cloud rule must hard-deny cloud egress; got \(decision.decision.rawValue) for profile=\(preset.rawValue) rule=\(rule.id) ep=\(enforcementPoint.rawValue)"
                                )
                                XCTAssertTrue(
                                    decision.reason.contains("cloud"),
                                    "deny reason must cite cloud sovereignty; got '\(decision.reason)' for profile=\(preset.rawValue) rule=\(rule.id)"
                                )
                                XCTAssertTrue(
                                    decision.matchedRuleIDs.contains(rule.id),
                                    "the no-cloud rule \(rule.id) must appear in matchedRuleIDs"
                                )
    
                                // Determinism: re-decide yields an identical record.
                                let replay = policySet.decide(
                                    at: enforcementPoint,
                                    actionClass: rule.actionClass,
                                    riskLevel: risk,
                                    scope: scope,
                                    sensitivity: sensitivity,
                                    cloudRequested: true
                                )
                                XCTAssertEqual(decision, replay, "decide() must be deterministic")
                            }
                        }
                    }
                }
            }
        }
    
        // Mutation guard: flipping a no-cloud rule to allowCloud==true MUST reopen
        // egress, proving the gate is load-bearing (not vacuously denying everything).
        let baseLocalOnly = BASPolicyProfiles.make(.localOnly)
        guard let routeRule = baseLocalOnly.rules.first(where: { $0.actionClass == .routeSelection && !$0.allowCloud }) else {
            return XCTFail("localOnly must contain a no-cloud routeSelection rule")
        }
        let mutatedRule = BASPolicyRule(
            id: routeRule.id,
            actionClass: routeRule.actionClass,
            enforcementPoints: routeRule.enforcementPoints,
            minimumRiskForConfirmation: nil,
            blockedScopes: routeRule.blockedScopes,
            blockedSensitivities: routeRule.blockedSensitivities,
            allowCloud: true
        )
        let mutatedSet = BASPolicySet(rules: [mutatedRule])
        let reopened = mutatedSet.decide(
            at: .routeSelection,
            actionClass: .routeSelection,
            riskLevel: .low,
            scope: .device,
            sensitivity: .low,
            cloudRequested: true
        )
        XCTAssertEqual(
            reopened.decision,
            .allow,
            "mutation guard: allowCloud==true must reopen cloud egress, proving the deny was rule-driven"
        )
    
        XCTAssertEqual(cloudEgressAllowCount, 0, "0 cloud-allow required across the profile x rule grid")
        XCTAssertGreaterThan(noCloudRulesExercised, 0)
        XCTAssertGreaterThan(gridCells, 0)
        print("QINAO-GATE cloud_egress_sovereignty: PASS profiles=\(sovereignPresets.count) noCloudRules=\(noCloudRulesExercised) gridCells=\(gridCells) cloudAllows=\(cloudEgressAllowCount)")
    }
}

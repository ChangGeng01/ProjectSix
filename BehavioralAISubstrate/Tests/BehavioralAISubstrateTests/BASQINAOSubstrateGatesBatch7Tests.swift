import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASObservability
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASSovereign
import CryptoKit
import Foundation

/// QINAO Substrate-100 gates — Phase-2 batch 7 (durable/seam/permit/risk/forget/parity/quarantine/restore; agent-drafted, author-verified).
final class BASQINAOSubstrateGatesBatch7Tests: XCTestCase {

    func test_qinao_durable_cosine_topk_recall() async throws {
        // --- local helpers (mirror BASSQLiteVectorIndexStorageTests.makeEntry verbatim) ---
        func makeEntry(
            atomID: String,
            vector: [Float],
            domain: String = "user.notes",
            metadata: [String: String] = [:]
        ) -> BASVectorIndexEntry {
            let embedding = BASEmbedding(
                vector: vector,
                dimension: vector.count,
                providerVersion: "test-v1")
            return BASVectorIndexEntry(
                atomID: atomID,
                normalizedEmbedding: embedding.normalized,
                domain: domain,
                metadata: metadata)
        }

        // Temp DB URL (mirror setUpWithError idiom).
        let tempURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "qinao-durable-topk-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-wal"))
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-shm"))
        }

        // Deterministic 8-dim corpus: each atom is a distinct direction so
        // the cosine ranking is well-separated (no fp ties at the bar).
        let dim = 8
        var corpus: [(id: String, vec: [Float])] = []
        // 24 atoms with pseudo-random-but-fixed components.
        for i in 0..<24 {
            var v = [Float](repeating: 0, count: dim)
            for d in 0..<dim {
                // Deterministic, finite, varied per (i,d).
                let t = Float((i * 31 + d * 7 + 3) % 97)
                v[d] = (t / 97.0) - 0.5 + Float(d) * 0.01
            }
            corpus.append((id: String(format: "atom-%02d", i), vec: v))
        }

        // --- Session A: build the index, persist every atom to SQLite. ---
        let preIndex = BASVectorIndex()
        let storeA = try BASSQLiteVectorIndexStorage(databaseURL: tempURL)
        for c in corpus {
            let entry = makeEntry(atomID: c.id, vector: c.vec)
            try await preIndex.insert(entry)
            let wasNew = try await storeA.upsert(entry)
            XCTAssertTrue(wasNew, "first upsert of \(c.id) must be new")
        }
        let persistedCount = await storeA.totalCount
        XCTAssertEqual(persistedCount, corpus.count,
            "all corpus atoms must be persisted")

        // Fixed query set: each query is one corpus vector perturbed slightly,
        // plus a couple of arbitrary directions. Pre-normalized (index contract).
        var queries: [BASEmbedding] = []
        for qi in [0, 5, 11, 17, 23] {
            var v = corpus[qi].vec
            for d in 0..<dim { v[d] += Float((d + qi) % 5) * 0.001 }
            queries.append(BASEmbedding(
                vector: v, dimension: dim,
                providerVersion: "test-v1").normalized)
        }
        // One orthogonal-ish probe.
        queries.append(BASEmbedding(
            vector: (0..<dim).map { Float($0) * 0.13 - 0.4 },
            dimension: dim, providerVersion: "test-v1").normalized)

        let k = 6
        // Oracle: pre-restore topK for every query (the durable bar to match).
        var preResults: [[BASVectorTopKResult]] = []
        for q in queries {
            let r = await preIndex.topK(query: q, k: k)
            XCTAssertEqual(r.count, k,
                "pre-restore topK must return k results from a \(corpus.count)-atom index")
            preResults.append(r)
        }

        // --- Session B: fresh index, restore via storage.preload (round-trip). ---
        // Reopen a brand-new storage handle from the SAME file (simulates a
        // new process / cross-session restore — storeA stays alive but the
        // DB is the durable source of truth on disk).
        let storeB = try BASSQLiteVectorIndexStorage(databaseURL: tempURL)
        let restoredCount = await storeB.totalCount
        XCTAssertEqual(restoredCount, corpus.count,
            "reopened durable store must see every persisted atom")

        let postIndex = BASVectorIndex()
        final class QINAOCorruptCounter: @unchecked Sendable { var n = 0 }
        let corruptCounter = QINAOCorruptCounter()
        let loaded = await storeB.preload(into: postIndex) { _, _ in
            corruptCounter.n += 1
        }
        XCTAssertEqual(corruptCounter.n, 0, "no corrupt rows on durable reload")
        XCTAssertEqual(loaded, corpus.count,
            "preload must restore every atom into the fresh index")
        let postEntryCount = await postIndex.entryCount
        XCTAssertEqual(postEntryCount, corpus.count,
            "restored in-memory index must hold the full corpus")

        // --- BAR: post-restore topK IDENTICAL (ordering + scores, tolerance 0). ---
        for (qi, q) in queries.enumerated() {
            let post = await postIndex.topK(query: q, k: k)
            XCTAssertEqual(post.count, k,
                "post-restore topK must return k results for query \(qi)")
            let pre = preResults[qi]
            // BASVectorTopKResult is Equatable (atomID + Float score) — this
            // asserts byte-identical ordering AND scores at tolerance 0.
            XCTAssertEqual(post, pre,
                "durable cosine topK must be byte-identical after restore " +
                "for query \(qi) (ordering + scores, tolerance 0)")
            // Explicit per-rank cross-check (defense in depth).
            for rank in 0..<k {
                XCTAssertEqual(post[rank].atomID, pre[rank].atomID,
                    "atomID at rank \(rank) for query \(qi) must match")
                XCTAssertEqual(post[rank].score, pre[rank].score,
                    "score at rank \(rank) for query \(qi) must be exact (tol 0)")
            }
        }

        // --- Determinism: re-calling topK on the restored index is stable. ---
        let q0 = queries[0]
        let again1 = await postIndex.topK(query: q0, k: k)
        let again2 = await postIndex.topK(query: q0, k: k)
        XCTAssertEqual(again1, again2,
            "repeated topK on the restored index must be deterministic")

        // --- Mutate-and-assert: a second independent restore matches the first. ---
        // Insert into postIndex must NOT retroactively change storeB's durable
        // rows; a third fresh reload still equals the original oracle.
        let extra = makeEntry(atomID: "atom-EXTRA",
            vector: (0..<dim).map { Float($0) * 0.05 })
        try await postIndex.upsert(extra)
        let entryCountAfterExtra = await postIndex.entryCount
        XCTAssertEqual(entryCountAfterExtra, corpus.count + 1,
            "in-memory mutation lands in postIndex only")
        let durableCountAfterMemMutation = await storeB.totalCount
        XCTAssertEqual(durableCountAfterMemMutation, corpus.count,
            "in-memory upsert must not mutate the durable store")
        let thirdIndex = BASVectorIndex()
        let loaded3 = await storeB.preload(into: thirdIndex)
        XCTAssertEqual(loaded3, corpus.count, "third reload restores full corpus")
        let post0Again = await thirdIndex.topK(query: q0, k: k)
        XCTAssertEqual(post0Again, preResults[0],
            "a fresh reload still reproduces the original pre-restore topK")

        print("QINAO-GATE durable_cosine_topk_recall: PASS " +
            "(corpus=\(corpus.count) dim=\(dim) k=\(k) queries=\(queries.count) " +
            "reload=\(loaded) byte-identical topK after cross-session restore, tol=0)")
    }

    func test_qinao_opt_in_seam_dormancy() {
    // METRIC #49 / L9 — opt-in seam DORMANCY: every OPT-IN seam carrier on
    // BASEBrainTurnRequest (default nil/off) leaves the turn-result digest BYTE-EQUAL
    // to the baseline. The two opt-in seams (documented verbatim in EBrainTurnRequest.swift)
    // are:
    //   • turnHistory: [String]   (default [])  — cross-turn SSM-caution history source
    //   • priorSSMState: [Float]? (default nil) — cross-turn SSM hidden state
    // Both are documented "NOT echoed into the turn result ⇒ result bytes unchanged;
    // default ⇒ identical to before (ADR-014 / 红线 7)". This gate proves turning the
    // seams OFF (their default) changes nothing in the digest the result feeds.

    // Deterministic stub coordinator + a fixed producedAt (METADATA ONLY, never hashed) —
    // same construction path the production replay harness uses (mirrors batch4).
    let coordinator = BASCoordinatorTestStubs.makeStub()
    let producedAt = Date(timeIntervalSince1970: 0)

    // Local helper: digest the turn-result of ONE request (canonicalized default path).
    func digest(of request: BASEBrainTurnRequest) -> String {
        let result = coordinator.runTurn(request)
        return BASEBrainTurnResultReplayDigest
            .from(result: result, producedAt: producedAt)
            .digestString
    }

    // BASELINE: a request built BEFORE the seams existed — every opt-in arg omitted
    // (turnHistory defaults to [], priorSSMState defaults to nil). This is the "before
    // the seam" reference digest.
    let baselineRequest = BASCoordinatorTestStubs.makeStubRequest()
    let baselineDigest = digest(of: baselineRequest)
    XCTAssertEqual(baselineDigest.count, 64,
        "baseline digest must be a full SHA256 lower-hex (64 chars) — proves the digest is real")

    // DETERMINISM: the baseline digest is reproducible (tolerance 0, exact String equality).
    XCTAssertEqual(baselineDigest, digest(of: baselineRequest),
        "baseline digest must be deterministic across re-runs (tolerance 0)")

    // The canonical DEFAULT-OFF value for each opt-in seam, expressed EXPLICITLY (rather
    // than via omission) — turning the flag "off" by hand must equal the baseline.
    let userInput = baselineRequest.userInput
    let hostID = baselineRequest.hostID
    let recordedAt = baselineRequest.recordedAt
    let deviceState = BASCoordinatorTestStubs.nominalDeviceState

    // (A) turnHistory seam OFF (explicit empty []) — must equal baseline.
    let turnHistoryOff = BASEBrainTurnRequest(
        userInput: userInput,
        deviceState: deviceState,
        hostID: hostID,
        recordedAt: recordedAt,
        turnHistory: [],
        priorSSMState: nil)
    XCTAssertEqual(digest(of: turnHistoryOff), baselineDigest,
        "turnHistory=[] (opt-in seam OFF) must leave the digest byte-equal to baseline")

    // (B) priorSSMState seam OFF (explicit nil) — must equal baseline.
    let priorStateOff = BASEBrainTurnRequest(
        userInput: userInput,
        deviceState: deviceState,
        hostID: hostID,
        recordedAt: recordedAt,
        turnHistory: [],
        priorSSMState: nil)
    XCTAssertEqual(digest(of: priorStateOff), baselineDigest,
        "priorSSMState=nil (opt-in seam OFF) must leave the digest byte-equal to baseline")

    // (C) ALL opt-in seams OFF together — must equal baseline (dormant in combination).
    let allSeamsOff = BASEBrainTurnRequest(
        userInput: userInput,
        deviceState: deviceState,
        hostID: hostID,
        recordedAt: recordedAt,
        riskHint: nil,
        feedbackEvent: nil,
        activeKillSwitches: [],
        turnHistory: [],
        priorSSMState: nil)
    XCTAssertEqual(digest(of: allSeamsOff), baselineDigest,
        "all opt-in seams at their default-off values must produce the baseline digest")

    // (D) NON-VACUITY GUARD — prove "equal" is meaningful, not a tautology. A NON-seam,
    // result-bearing field (userInput) flows into the turn result, so changing it MUST
    // flip the digest. If this failed, the digest would be blind and assertions (A)–(C)
    // would be empty. This is the replicated control that makes the dormancy claim load-bearing.
    let changedNonSeam = BASEBrainTurnRequest(
        userInput: userInput + " MUTATED",
        deviceState: deviceState,
        hostID: hostID,
        recordedAt: recordedAt,
        turnHistory: [],
        priorSSMState: nil)
    XCTAssertNotEqual(digest(of: changedNonSeam), baselineDigest,
        "a non-seam result-bearing field (userInput) MUST flip the digest — proves the digest is live, not blind")

    print("QINAO-GATE opt_in_seam_dormancy: PASS "
        + "(seams=[turnHistory,priorSSMState] "
        + "turnHistoryOff==baseline=\(digest(of: turnHistoryOff) == baselineDigest) "
        + "priorStateOff==baseline=\(digest(of: priorStateOff) == baselineDigest) "
        + "allOff==baseline=\(digest(of: allSeamsOff) == baselineDigest) "
        + "nonSeam-flips=\(digest(of: changedNonSeam) != baselineDigest) "
        + "baseline=\(baselineDigest.prefix(12))…)")
}

    func test_qinao_redline_permit_downgrade_completeness() {
    // L11 #51 — over an ADVERSARIAL red-line corpus (extreme risk, gsiScore>=0.75,
    // guard runMode, forceProtectedPermit kill switch) the permit normalize/downgrade
    // (`normalizeRiskDecision`) must leave NO residual `.answer` permit — neither the
    // primary `mode` NOR any entry of `stackedModes` (the escape vectors). Downgrade
    // must be complete: 0 escapes, tolerance=0, exhaustive over the input grid,
    // deterministic on re-call, and a NEGATIVE control proves the guard is not vacuous.
    let coordinator = BASCoordinatorTestStubs.makeStub()

    // The maximally-adversarial red-line budget: guard mode (the L1 protective lane).
    let guardBudget = BASBudgetFrame(
        runMode: .guard,
        maxLoops: 3,
        maxCandidates: 4,
        maxDecodeTokens: 256,
        retrievalDepth: 5,
        precisionProfile: .protected,
        deviceRoute: .hybridLocal,
        thermalGuardLevel: .watch,
        maintenanceAllowed: false,
        leaseID: "lease-redline",
        leaseExpiresAt: Date(timeIntervalSince1970: 1_705_000_000),
        maintenanceClass: .none,
        wakeIntentID: BASWakeIntentLevel.guard.rawValue,
        allowedHeads: ["primary"],
        policyBundleVersion: "policy.v1",
        policyDecisionIDs: ["d1"])

    // The maximally-adversarial red-line risk card: extreme level, GSI well over the
    // 0.75 red line, maxed irreversibility/manipulation, and (critically) a
    // recommendedMode that ITSELF tries to keep `.answer` alive — so the only thing
    // that can downgrade is the red-line normalize logic, not the recommendation.
    let redlineCard = BASRiskCard(
        totalRisk: 1.0,
        riskLevel: .extreme,
        factors: ["redline.adversarial"],
        uncertainty: 0.9,
        irreversibility: 1.0,
        manipulationStrength: 1.0,
        gsiScore: 0.99,
        recommendedMode: .answer)

    // forceProtectedPermit is the kill switch the risk-prefixed audit recommends.
    let killSwitches: [BASKillSwitchID] = [.forceProtectedPermit]

    // Adversarial permit corpus: every permit ENTERS as `.answer` (the dangerous
    // direct-output mode), but with varied stacked-mode payloads that each try to
    // smuggle `.answer` back in via the stack — the residual-escape vectors we test.
    let allModes = BASActionPermitMode.allCases
    var inputPermits: [BASActionPermit] = []
    // 1) bare answer
    inputPermits.append(BASActionPermit(mode: .answer))
    // 2) answer with EVERY single mode stacked (incl. a redundant .answer)
    for stacked in allModes {
        inputPermits.append(
            BASActionPermit(
                mode: .answer,
                stackedModes: [stacked, .answer],
                reasonCodes: ["seed.\(stacked.rawValue)"],
                requireSecondCheck: false,
                outputLengthCap: 240))
    }
    // 3) answer with the full stack of every mode at once
    inputPermits.append(
        BASActionPermit(
            mode: .answer,
            stackedModes: allModes,
            reasonCodes: ["seed.fullstack"]))

    // Local oracle: a permit "escapes" the red line iff `.answer` survives ANYWHERE
    // (primary mode OR the stacked-mode list).
    let answerSurvives: (BASActionPermit) -> Bool = { permit in
        permit.mode == .answer || permit.stackedModes.contains(.answer)
    }

    var escapes = 0
    var downgraded = 0
    for permit in inputPermits {
        // sanity: every input is an ACTUAL answer-escape before normalization.
        XCTAssertTrue(answerSurvives(permit), "corpus seed must start as an .answer escape")

        let (_, normalized, findings) = coordinator.normalizeRiskDecision(
            riskCard: redlineCard,
            actionPermit: permit,
            budget: guardBudget,
            activeKillSwitches: killSwitches)

        // Completeness: ZERO residual .answer (mode and every stacked entry).
        if answerSurvives(normalized) {
            escapes += 1
        } else {
            downgraded += 1
        }
        XCTAssertNotEqual(normalized.mode, .answer, "primary permit mode must not stay .answer under red line")
        XCTAssertFalse(
            normalized.stackedModes.contains(.answer),
            "no .answer may survive in stackedModes (escape vector) under red line")

        // The downgrade must be AUDITED (a red-line / kill-switch finding fired,
        // enforced=true) — a silent downgrade is not an acceptable substrate gate.
        let enforcedRedline = findings.contains { f in
            f.enforced && f.layerID == "L11"
        }
        XCTAssertTrue(
            enforcedRedline,
            "an enforced L11 red-line/kill-switch finding must accompany the downgrade")

        // Deterministic re-call: identical inputs => identical normalized permit
        // (tolerance=0, byte-equal on the consequential permit field).
        let (_, replay, _) = coordinator.normalizeRiskDecision(
            riskCard: redlineCard,
            actionPermit: permit,
            budget: guardBudget,
            activeKillSwitches: killSwitches)
        XCTAssertEqual(normalized, replay, "permit downgrade must be replay-stable (deterministic)")
    }

    XCTAssertEqual(escapes, 0, "downgrade must be COMPLETE: 0 residual .answer escapes")
    XCTAssertEqual(downgraded, inputPermits.count, "every red-line answer permit must be downgraded")

    // NEGATIVE CONTROL (non-vacuity): a BENIGN context (low risk, gsi 0.0, engage
    // mode, no kill switches) must LEAVE an .answer permit untouched — proving the
    // gate above is the red line doing the work, not a normalize that nukes .answer
    // unconditionally.
    let benignBudget = BASBudgetFrame(
        runMode: .engage,
        maxLoops: 3,
        maxCandidates: 4,
        maxDecodeTokens: 256,
        retrievalDepth: 5,
        precisionProfile: .balanced,
        deviceRoute: .hybridLocal,
        thermalGuardLevel: .watch,
        maintenanceAllowed: false)
    let benignCard = BASRiskCard(
        totalRisk: 0.05,
        riskLevel: .low,
        uncertainty: 0.05,
        irreversibility: 0.05,
        manipulationStrength: 0.0,
        gsiScore: 0.0,
        recommendedMode: .answer)
    let (_, benignPermit, _) = coordinator.normalizeRiskDecision(
        riskCard: benignCard,
        actionPermit: BASActionPermit(mode: .answer),
        budget: benignBudget,
        activeKillSwitches: [])
    XCTAssertEqual(
        benignPermit.mode, .answer,
        "non-vacuity: a benign turn must KEEP .answer (red line is doing the downgrade, not a blanket nuke)")

    print("QINAO-GATE redline_permit_downgrade_completeness: PASS corpus=\(inputPermits.count) downgraded=\(downgraded) escapes=\(escapes) (extreme+gsi0.99+guard+forceProtectedPermit; 0 residual .answer in mode OR stackedModes, every downgrade carries an enforced L11 finding, deterministic re-call, benign negative control keeps .answer; tolerance=0)")
}

    func test_qinao_risk_calibration_replace_safety() async throws {
        // --- Local fixtures (mirrored verbatim from
        // BASRiskCalibrationGateTests.makeBundle / makeStratumDelta) ---
        func makeBundle(
            version: String,
            supersedes: String? = nil,
            deltas: [BASRiskCalibrationStratumDelta] = []
        ) -> BASRiskCalibrationBundle {
            BASRiskCalibrationBundle(
                bundleVersion: version,
                aggregateProvenanceRef: "agg:\(version)",
                strataDeltas: deltas,
                sovereignWarrantRef: "warrant:\(version)",
                supersedesBundleVersion: supersedes,
                summary: "qinao bundle \(version)")
        }
        func makeStratumDelta(
            key: String,
            medium: Double = 0,
            high: Double = 0,
            extreme: Double = 0
        ) -> BASRiskCalibrationStratumDelta {
            BASRiskCalibrationStratumDelta(
                stratumKey: key,
                mediumThresholdDelta: medium,
                highThresholdDelta: high,
                extremeThresholdDelta: extreme,
                evidenceRowCount: 100)
        }

        // ================================================================
        // PART A — REJECTION: only a VALID monotonic signed bundle is
        // accepted. Each malformed/non-monotonic/broken-signature bundle
        // must throw the EXACT typed ReplaceError AND leave the gate's
        // current bundle UNCHANGED (mutate-and-assert safety gate).
        // ================================================================

        // --- A1: malformed bundle (empty bundleVersion) ---
        do {
            let gate = BASRiskCalibrationGate()  // starts at .baseline
            let before = await gate.currentBundleVersion
            XCTAssertEqual(
                before, BASRiskCalibrationBundle.baselineVersion)
            let malformed = BASRiskCalibrationBundle(
                bundleVersion: "",
                aggregateProvenanceRef: "agg",
                sovereignWarrantRef: "warrant")
            var threw = false
            do {
                _ = try await gate.replace(malformed)
                XCTFail("A1: expected malformedBundle, none thrown")
            } catch BASRiskCalibrationGate.ReplaceError
                .malformedBundle(let reason) {
                threw = true
                XCTAssertTrue(
                    reason.contains("isWellFormed"),
                    "A1: reason must cite isWellFormed; got \(reason)")
            } catch {
                XCTFail("A1: wrong error type: \(error)")
            }
            XCTAssertTrue(threw, "A1: must throw")
            let after = await gate.currentBundleVersion
            XCTAssertEqual(
                after, BASRiskCalibrationBundle.baselineVersion,
                "A1: gate bundle MUST be unchanged after rejection")
        }

        // --- A2: BROKEN SIGNATURE — empty sovereignWarrantRef.
        // isWellFormed=false (the L14 warrant is the bundle's signature
        // surrogate), so this is rejected as malformedBundle. ---
        do {
            let gate = BASRiskCalibrationGate()
            let unsigned = BASRiskCalibrationBundle(
                bundleVersion: "v1.0.0",
                aggregateProvenanceRef: "agg:v1.0.0",
                sovereignWarrantRef: "")  // broken/absent signature
            // sanity: the bundle itself reports not-well-formed
            XCTAssertFalse(
                unsigned.isWellFormed,
                "A2: empty warrant must make isWellFormed=false")
            var threw = false
            do {
                _ = try await gate.replace(unsigned)
                XCTFail("A2: expected malformedBundle, none thrown")
            } catch BASRiskCalibrationGate.ReplaceError
                .malformedBundle {
                threw = true
            } catch {
                XCTFail("A2: wrong error type: \(error)")
            }
            XCTAssertTrue(threw, "A2: broken signature must throw")
            let after = await gate.currentBundleVersion
            XCTAssertEqual(
                after, BASRiskCalibrationBundle.baselineVersion,
                "A2: gate bundle MUST be unchanged after rejection")
        }

        // --- A3: non-monotonic bundleVersion (replay/regress) ---
        do {
            let gate = BASRiskCalibrationGate()
            _ = try await gate.replace(makeBundle(version: "v2.0.0"))
            let beforeBundle = await gate.currentBundle
            XCTAssertEqual(beforeBundle.bundleVersion, "v2.0.0")
            let older = makeBundle(
                version: "v1.0.0", supersedes: "v2.0.0")
            var threw = false
            do {
                _ = try await gate.replace(older)
                XCTFail("A3: expected nonMonotonicVersion, none thrown")
            } catch BASRiskCalibrationGate.ReplaceError
                .nonMonotonicVersion(let cur, let prop) {
                threw = true
                XCTAssertEqual(cur, "v2.0.0", "A3: current")
                XCTAssertEqual(prop, "v1.0.0", "A3: proposed")
            } catch {
                XCTFail("A3: wrong error type: \(error)")
            }
            XCTAssertTrue(threw, "A3: must throw")
            // Equal-version replay is ALSO non-monotonic (strictly-greater).
            var threwEqual = false
            do {
                _ = try await gate.replace(
                    makeBundle(version: "v2.0.0", supersedes: "v2.0.0"))
                XCTFail("A3b: equal version must be rejected")
            } catch BASRiskCalibrationGate.ReplaceError
                .nonMonotonicVersion {
                threwEqual = true
            } catch {
                XCTFail("A3b: wrong error type: \(error)")
            }
            XCTAssertTrue(threwEqual, "A3b: equal version must throw")
            let afterBundle = await gate.currentBundle
            XCTAssertEqual(
                afterBundle, beforeBundle,
                "A3: entire bundle MUST be byte-identical after rejection")
        }

        // --- A4: supersedes-chain mismatch (wrong predecessor) ---
        do {
            let gate = BASRiskCalibrationGate()
            _ = try await gate.replace(makeBundle(version: "v1.0.0"))
            let before = await gate.currentBundleVersion
            let wrong = makeBundle(version: "v2.0.0", supersedes: "v0.5.0")
            var threw = false
            do {
                _ = try await gate.replace(wrong)
                XCTFail("A4: expected supersedesMismatch, none thrown")
            } catch BASRiskCalibrationGate.ReplaceError
                .supersedesMismatch(let cur, let prop) {
                threw = true
                XCTAssertEqual(cur, "v1.0.0", "A4: current")
                XCTAssertEqual(prop, "v0.5.0", "A4: proposed supersedes")
            } catch {
                XCTFail("A4: wrong error type: \(error)")
            }
            XCTAssertTrue(threw, "A4: must throw")
            let after = await gate.currentBundleVersion
            XCTAssertEqual(
                after, before,
                "A4: gate bundle MUST be unchanged after rejection")
        }

        // --- A5: nil supersedes onto a non-baseline gate is rejected
        // (silently dropping audit history is forbidden) ---
        do {
            let gate = BASRiskCalibrationGate()
            _ = try await gate.replace(makeBundle(version: "v1.0.0"))
            let before = await gate.currentBundleVersion
            let nilSupersedes = makeBundle(version: "v2.0.0")  // nil
            var threw = false
            do {
                _ = try await gate.replace(nilSupersedes)
                XCTFail("A5: expected supersedesMismatch, none thrown")
            } catch BASRiskCalibrationGate.ReplaceError
                .supersedesMismatch(let cur, let prop) {
                threw = true
                XCTAssertEqual(cur, "v1.0.0", "A5: current")
                XCTAssertEqual(prop, "(nil)", "A5: proposed sentinel")
            } catch {
                XCTFail("A5: wrong error type: \(error)")
            }
            XCTAssertTrue(threw, "A5: must throw")
            let after = await gate.currentBundleVersion
            XCTAssertEqual(
                after, before,
                "A5: gate bundle MUST be unchanged after rejection")
        }

        // ================================================================
        // PART B — ACCEPTANCE: a valid, monotonic, signed bundle IS
        // accepted, state mutates exactly once, audit codes are typed,
        // and replace is DETERMINISTIC on re-call from a fresh gate.
        // ================================================================
        func freshAcceptanceGate() async throws
            -> (BASRiskCalibrationGate,
                BASRiskCalibrationGateReplaceOutcome)
        {
            let gate = BASRiskCalibrationGate()
            let valid = makeBundle(
                version: "v1.0.0",
                deltas: [
                    makeStratumDelta(
                        key: "tone=angry|stake=high", medium: 0.05),
                    makeStratumDelta(
                        key: "tone=calm|stake=low", medium: 0)
                ])
            XCTAssertTrue(
                valid.isWellFormed,
                "B: valid signed bundle must be well-formed")
            let outcome = try await gate.replace(valid)
            return (gate, outcome)
        }

        let (gateB1, outcomeB1) = try await freshAcceptanceGate()
        let acceptedVersion = await gateB1.currentBundleVersion
        XCTAssertEqual(
            acceptedVersion, "v1.0.0",
            "B: valid bundle MUST become the active bundle")
        XCTAssertEqual(
            outcomeB1.priorBundleVersion,
            BASRiskCalibrationBundle.baselineVersion)
        XCTAssertEqual(outcomeB1.newBundleVersion, "v1.0.0")
        XCTAssertEqual(
            outcomeB1.strataChanged, 1,
            "B: only the non-zero-delta stratum counts as changed")
        XCTAssertEqual(outcomeB1.totalEvidenceRowCount, 200)
        XCTAssertTrue(
            outcomeB1.auditReasonCodes.contains(
                "risk-calibration:strata-changed:1"),
            "B: typed strata-changed audit code required")
        XCTAssertTrue(
            outcomeB1.auditReasonCodes.contains(where: {
                $0.contains(
                    "bundle-replaced:from-v0.0.0-baseline:to-v1.0.0")
            }),
            "B: typed bundle-replaced audit code required")

        // Determinism: a SECOND independent fresh gate run yields an
        // outcome equal on every decision-bearing field (appliedAt is a
        // wall-clock stamp and is intentionally excluded).
        let (_, outcomeB2) = try await freshAcceptanceGate()
        XCTAssertEqual(
            outcomeB1.priorBundleVersion,
            outcomeB2.priorBundleVersion)
        XCTAssertEqual(
            outcomeB1.newBundleVersion, outcomeB2.newBundleVersion)
        XCTAssertEqual(outcomeB1.strataChanged, outcomeB2.strataChanged)
        XCTAssertEqual(
            outcomeB1.totalEvidenceRowCount,
            outcomeB2.totalEvidenceRowCount)
        XCTAssertEqual(
            outcomeB1.auditReasonCodes, outcomeB2.auditReasonCodes,
            "B: replace decision MUST be deterministic across runs")

        // A subsequent valid monotonic+chained replace is accepted on the
        // already-mutated gate (proves the gate advances, not just from
        // baseline).
        let nextValid = makeBundle(
            version: "v2.0.0", supersedes: "v1.0.0")
        let outcomeNext = try await gateB1.replace(nextValid)
        XCTAssertEqual(outcomeNext.priorBundleVersion, "v1.0.0")
        XCTAssertEqual(outcomeNext.newBundleVersion, "v2.0.0")
        let finalVersion = await gateB1.currentBundleVersion
        XCTAssertEqual(finalVersion, "v2.0.0")

        print(
            "QINAO-GATE risk_calibration_replace_safety: PASS " +
            "(rejected malformed/broken-signature/non-monotonic/" +
            "supersedes-mismatch with bundle UNCHANGED; accepted only " +
            "valid monotonic signed bundle; deterministic re-call)")
    }

    func test_qinao_replay_disposition_forget_vault_gate() {
    // QINAO #75: BASObservabilityInspector.replayDisposition(for:) must DENY replay
    // (isAvailable == false) ONLY when there is a verified forget-revocation
    // (forget_verified:true AND (checkpoints OR sync-exports revoked)) OR the host
    // constitution vault is NON-consistent (revocation_pending / out_of_sync /
    // migration_pending). A consistent (or absent) vault with no verified revocation
    // must REMAIN replayable. Source: ObservabilityCore.swift:837-934 (static func),
    // marker grammar parsed from retrievalTags + verificationSnapshot ("|"-split).

    // --- Local helper: build a brain state carrying the given marker tokens. ---
    // Mirrors makeReplayBundle()'s BASCurrentBrainState construction verbatim
    // (BASObservabilityCoreTests.swift:791-800), varying only the marker tags.
    func makeBrainState(markers: [String]) -> BASCurrentBrainState {
        BASCurrentBrainState(
            mode: "primary",
            dominantGoals: ["stay calm"],
            activeConstraints: ["sleep first"],
            reactionWeights: BASReactionWeights(warmth: 0.7, directness: 0.5, brevity: 0.8, actionBias: 0.6),
            activeTemplateIDs: [],
            recentFailurePatternIDs: [],
            retrievalTags: ["night"] + markers,
            verificationSnapshot: (["fp_1"] + markers).joined(separator: "|")
        )
    }

    // --- Oracle for the gate, derived independently from the spec. ---
    func expectedBlocked(
        forgetVerified: Bool,
        checkpointsRevoked: Bool,
        syncExportsRevoked: Bool,
        vaultState: String?
    ) -> Bool {
        let verifiedRevocation = forgetVerified && (checkpointsRevoked || syncExportsRevoked)
        let vaultBlocks =
            vaultState == "revocation_pending" ||
            vaultState == "out_of_sync" ||
            vaultState == "migration_pending"
        return verifiedRevocation || vaultBlocks
    }

    // --- Exhaustive truth table over the four gating axes. ---
    let vaultStates: [String?] = [
        nil,                   // no vault marker
        "consistent",         // non-blocking state -> must stay replayable absent revocation
        "synchronized",       // another non-blocking state
        "revocation_pending", // BLOCKS
        "out_of_sync",        // BLOCKS
        "migration_pending"   // BLOCKS
    ]
    let bools = [false, true]

    var cases = 0
    for forgetVerified in bools {
        for checkpointsRevoked in bools {
            for syncExportsRevoked in bools {
                for vaultState in vaultStates {
                    var markers: [String] = ["forget_request:forget.guard.anchor"]
                    if forgetVerified { markers.append("forget_verified:true") }
                    if checkpointsRevoked { markers.append("forget_checkpoints_revoked:true") }
                    if syncExportsRevoked { markers.append("forget_sync_exports_revoked:true") }
                    if let vs = vaultState { markers.append("vault_consistency:\(vs)") }

                    let state = makeBrainState(markers: markers)
                    let disposition = BASObservabilityInspector.replayDisposition(for: state)

                    let wantBlocked = expectedBlocked(
                        forgetVerified: forgetVerified,
                        checkpointsRevoked: checkpointsRevoked,
                        syncExportsRevoked: syncExportsRevoked,
                        vaultState: vaultState
                    )
                    let label = "fv=\(forgetVerified) ckpt=\(checkpointsRevoked) sync=\(syncExportsRevoked) vault=\(vaultState ?? "nil")"

                    // Core gate: availability is the exact negation of "blocked".
                    XCTAssertEqual(disposition.isAvailable, !wantBlocked,
                                   "replay availability gate violated for \(label)")

                    // Safety invariant: any DENIED replay MUST carry a non-empty reason.
                    if wantBlocked {
                        XCTAssertFalse(disposition.isAvailable, "must DENY for \(label)")
                        let reason = disposition.reason ?? ""
                        XCTAssertFalse(reason.isEmpty, "blocked replay must explain why for \(label)")
                    } else {
                        XCTAssertTrue(disposition.isAvailable, "must ALLOW for \(label)")
                    }

                    // Determinism (tolerance 0): re-call yields the identical disposition.
                    let repeated = BASObservabilityInspector.replayDisposition(for: state)
                    XCTAssertEqual(disposition, repeated, "non-deterministic disposition for \(label)")

                    cases += 1
                }
            }
        }
    }
    XCTAssertEqual(cases, 2 * 2 * 2 * 6)

    // --- Anchored positive: verified forget + revoked checkpoint must DENY. ---
    let verifiedBlock = makeBrainState(markers: [
        "forget_request:forget.guard.anchor",
        "forget_verified:true",
        "forget_checkpoints_revoked:true"
    ])
    let verifiedDisp = BASObservabilityInspector.replayDisposition(for: verifiedBlock)
    XCTAssertFalse(verifiedDisp.isAvailable, "verified checkpoint revocation must block replay")
    XCTAssertEqual(verifiedDisp.forgetRequestID, "forget.guard.anchor")
    XCTAssertTrue(verifiedDisp.checkpointsRevoked)

    // --- Mutate-and-assert: a non-consistent vault flips an otherwise-allowed
    // state to DENIED, proving the vault-consistency guard is load-bearing. ---
    let allowedState = makeBrainState(markers: ["forget_request:forget.guard.anchor"])
    let allowedDisp = BASObservabilityInspector.replayDisposition(for: allowedState)
    XCTAssertTrue(allowedDisp.isAvailable, "plain unverified forget (consistent/absent vault) stays replayable")

    let inconsistentState = makeBrainState(markers: [
        "forget_request:forget.guard.anchor",
        "vault_consistency:out_of_sync"
    ])
    let inconsistentDisp = BASObservabilityInspector.replayDisposition(for: inconsistentState)
    XCTAssertFalse(inconsistentDisp.isAvailable, "non-consistent forget vault must block replay")
    XCTAssertEqual(inconsistentDisp.vaultConsistencyState, "out_of_sync")
    XCTAssertNotEqual(allowedDisp.isAvailable, inconsistentDisp.isAvailable,
                      "vault consistency must be load-bearing for the replay gate")

    print("QINAO-GATE replay_disposition_forget_vault_gate: PASS (\(cases) exhaustive cases; verified-revocation + non-consistent-vault both DENY; consistent/unverified stays replayable; deterministic; reasons present)")
}

    // [QINAO-REWORK DONE] verdict_parity_shadow_laxer_halt now lives in BASQINAOSubstrateGatesBatch8Tests

    func test_qinao_ledger_quarantine_on_corrupt_reload() async throws {
    // QINAO #85 / L14: cold-start integrity > availability. A persisted audit chain
    // whose verify-on-reload FAILS must set integrityQuarantined=true and REJECT all
    // subsequent appends (persisted-then-tampered -> quarantine, fail-closed per BR-012).
    //
    // Construction mirrored verbatim from
    // Tests/.../BASSovereignAuditLedgerReloadVerifyTests.swift:
    //   - BASSovereignAuditLedger(ed25519KeyPair:storage:)
    //   - BASSovereignLedgerSQLiteStorage(path:) throws
    //   - BASSovereignAuditEntry(auditID:sessionID:turnID:verdictRef:ruleIDs:
    //         signalRefs:actionRefs:snapshotRef:actor:signature:appendedAt:)
    //   - isIntegrityQuarantined (async actor property)
    //   - quarantined append throws LedgerError.invalidEntry

    // Local helpers (kept inside the method per harness rule).
    func qinaoTempPath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("qinao-quar-\(UUID().uuidString).sqlite").path
    }
    func qinaoEntry(_ id: String) -> BASSovereignAuditEntry {
        BASSovereignAuditEntry(
            auditID: id, sessionID: "s", turnID: "t", verdictRef: "v",
            ruleIDs: ["BR-001"], signalRefs: [], actionRefs: [],
            snapshotRef: "snap", actor: .system, signature: "",
            appendedAt: Date(timeIntervalSince1970: 1))
    }

    // ---- Corruption case: persist under key A, reload under DIFFERENT key B. ----
    // A divergent signing key is the exact shape of a tampered/forged persisted file:
    // the stored signatures no longer verify, so verify-on-reload must fail -> quarantine.
    let corruptPath = qinaoTempPath()
    defer { try? FileManager.default.removeItem(atPath: corruptPath) }

    let keyA = BASSovereignEd25519KeyPair.generate()
    let keyB = BASSovereignEd25519KeyPair.generate()

    // Author and PERSIST a genuine multi-entry hash-chain under key A.
    let authorLedger = BASSovereignAuditLedger(
        ed25519KeyPair: keyA,
        storage: try BASSovereignLedgerSQLiteStorage(path: corruptPath))
    _ = try await authorLedger.append(qinaoEntry("a1"))
    _ = try await authorLedger.append(qinaoEntry("a2"))
    _ = try await authorLedger.append(qinaoEntry("a3"))

    // COLD-START reload the same on-disk chain under the WRONG key.
    let reloaded = BASSovereignAuditLedger(
        ed25519KeyPair: keyB,
        storage: try BASSovereignLedgerSQLiteStorage(path: corruptPath))

    // Gate 1 — integrity > availability: the corrupt reload MUST quarantine.
    let quarantined = await reloaded.isIntegrityQuarantined
    XCTAssertTrue(quarantined,
        "a persisted chain whose verify FAILS on reload must set integrityQuarantined=true")

    // Gate 2 — determinism: re-reading the flag yields the SAME verdict (idempotent,
    // tolerance 0). The lazy verify-on-reload must not flip state on a second read.
    let quarantinedAgain = await reloaded.isIntegrityQuarantined
    XCTAssertEqual(quarantined, quarantinedAgain,
        "isIntegrityQuarantined must be deterministic across re-reads")
    XCTAssertTrue(quarantinedAgain)

    // Gate 3 — REJECT all subsequent appends (fail-closed). Mutate-and-assert: every
    // attempt to grow a quarantined chain throws LedgerError.invalidEntry and never
    // extends the chain.
    for forged in ["b1", "b2"] {
        do {
            _ = try await reloaded.append(qinaoEntry(forged))
            XCTFail("a quarantined ledger must REFUSE new appends (got: \(forged))")
        } catch BASSovereignAuditLedger.LedgerError.invalidEntry {
            // expected: fail-closed
        }
    }
    // Append surface stayed at the (now-untrusted) persisted length — no forged growth.
    let countAfterRejected = await reloaded.count()
    XCTAssertEqual(countAfterRejected, 3,
        "rejected appends must not extend a quarantined chain")

    // ---- Specificity control: an UNCORRUPTED same-key reload must NOT quarantine ----
    // Proves the gate is integrity-driven, not an always-on refusal that would trivially
    // satisfy Gates 1-3 while breaking the availability side for legitimate restarts.
    let cleanPath = qinaoTempPath()
    defer { try? FileManager.default.removeItem(atPath: cleanPath) }
    let keyC = BASSovereignEd25519KeyPair.generate()
    let cleanAuthor = BASSovereignAuditLedger(
        ed25519KeyPair: keyC,
        storage: try BASSovereignLedgerSQLiteStorage(path: cleanPath))
    _ = try await cleanAuthor.append(qinaoEntry("c1"))

    let cleanReload = BASSovereignAuditLedger(
        ed25519KeyPair: keyC,
        storage: try BASSovereignLedgerSQLiteStorage(path: cleanPath))
    let cleanQuarantined = await cleanReload.isIntegrityQuarantined
    XCTAssertFalse(cleanQuarantined,
        "a legit same-key reload of an intact chain must NOT quarantine")
    // And it must still accept new appends (availability preserved when integrity holds).
    _ = try await cleanReload.append(qinaoEntry("c2"))
    let cleanCount = await cleanReload.count()
    XCTAssertEqual(cleanCount, 2,
        "an un-quarantined ledger must accept appends after a clean reload")

    print("QINAO-GATE ledger_quarantine_on_corrupt_reload: PASS "
        + "(corrupt reload quarantined + rejected \(2) appends, chain held at "
        + "\(countAfterRejected); clean same-key reload accepted, chain=\(cleanCount))")
}

    func test_qinao_restore_payload_hash_gate() async throws {
    // L14 BR-04 SnapshotManager hash gate (#92). Two edges, tolerance 0:
    //  (A) verifyRestore MUST throw .payloadHashMismatch when the presented
    //      payload's SHA-256 != the registered payloadHash.
    //  (B) register MUST throw .hashBindingMismatch when the anchor's declared
    //      integrityHash != the computed SHA-256 of the sealed payload.
    // Actor-isolated => async. All helpers local to avoid cross-test collision.
    typealias Manager = BASSovereignSnapshotManager
    typealias Anchor = Manager.SnapshotAnchor
    typealias ManagerError = Manager.ManagerError

    let payload: (String) -> Data = { Data($0.utf8) }

    // Mirror the existing-test `anchor(...)` helper: declared hash == hash(payload).
    let honestAnchor: (String, Data) -> Anchor = { id, p in
        Anchor(
            anchorID: id,
            safeSnapshotRef: "snap-\(id)",
            foldRefs: [],
            hostVersionRef: nil,
            integrityHash: Manager.hash(p)
        )
    }

    // Replicated oracle: hash is the canonical SHA-256 hex used by the manager.
    // We treat Manager.hash as the oracle and assert determinism of it first.
    let oracleA = Manager.hash(payload("oracle-seed"))
    let oracleB = Manager.hash(payload("oracle-seed"))
    XCTAssertEqual(oracleA, oracleB, "Manager.hash must be deterministic")

    // ---- Edge B: registration rejects declared != computed (exhaustive over samples) ----
    let mismatchSamples: [(declared: String, sealed: String)] = [
        ("v-A", "v-B"),
        ("", "x"),
        ("longer-payload-content-here", "longer-payload-content-her"), // 1-byte diff
        ("同样的内容?", "同样的内容!"),                                  // unicode 1-char diff
        ("repeat", "repeatX")
    ]
    for (idx, s) in mismatchSamples.enumerated() {
        let mgr = Manager()
        let id = "liar-\(idx)"
        let sealed = payload(s.sealed)
        let liar = Anchor(
            anchorID: id,
            safeSnapshotRef: "s",
            integrityHash: Manager.hash(payload(s.declared)) // declared != computed(sealed)
        )
        // Precondition: the declared and computed hashes genuinely differ.
        XCTAssertNotEqual(Manager.hash(payload(s.declared)), Manager.hash(sealed),
                          "sample \(idx) must be a genuine hash mismatch")
        do {
            _ = try await mgr.register(anchor: liar, sealedPayload: sealed)
            XCTFail("register must reject declared!=computed for sample \(idx)")
        } catch let error as ManagerError {
            guard case .hashBindingMismatch(let aid, let declared, let computed) = error else {
                XCTFail("expected hashBindingMismatch, got \(error)")
                continue
            }
            XCTAssertEqual(aid, id)
            XCTAssertEqual(declared, Manager.hash(payload(s.declared)).lowercased())
            XCTAssertEqual(computed, Manager.hash(sealed))
        }
        // Mutation/audit: a rejected anchor must NOT be stored.
        let cnt = await mgr.registeredCount()
        XCTAssertEqual(cnt, 0, "rejected anchor must not be stored (sample \(idx))")
        let resolved = await mgr.isRegistered(anchorID: id)
        XCTAssertFalse(resolved, "rejected anchor must not be resolvable (sample \(idx))")
    }

    // ---- Edge A: verifyRestore throws payloadHashMismatch on tampered payload ----
    let tamperPairs: [(orig: String, tampered: String)] = [
        ("weights-v1", "weights-v2"),
        ("state-blob", "state-blob "),   // trailing-space tamper
        ("0123456789", "0123456788"),    // last-digit flip
        ("中文权重快照", "中文权重快照X")    // unicode append
    ]
    for (idx, pair) in tamperPairs.enumerated() {
        let mgr = Manager()
        let id = "anchor-\(idx)"
        let original = payload(pair.orig)
        // Honest registration must succeed (declared == computed).
        let entry = try await mgr.register(anchor: honestAnchor(id, original), sealedPayload: original)
        XCTAssertEqual(entry.payloadHash, Manager.hash(original))

        // Clean restore (identical bytes) must pass — no throw.
        try await mgr.verifyRestore(anchorID: id, presentedPayload: original)

        // Tampered restore must throw payloadHashMismatch with the right hashes.
        let tampered = payload(pair.tampered)
        XCTAssertNotEqual(Manager.hash(original), Manager.hash(tampered),
                          "tamper sample \(idx) must change the hash")
        do {
            try await mgr.verifyRestore(anchorID: id, presentedPayload: tampered)
            XCTFail("verifyRestore must throw on tampered payload (sample \(idx))")
        } catch let error as ManagerError {
            guard case .payloadHashMismatch(let aid, let expected, let actual) = error else {
                XCTFail("expected payloadHashMismatch, got \(error)")
                continue
            }
            XCTAssertEqual(aid, id)
            XCTAssertEqual(expected, Manager.hash(original), "expected == registered payloadHash")
            XCTAssertEqual(actual, Manager.hash(tampered), "actual == hash(presented)")
            XCTAssertNotEqual(expected, actual, "mismatch must be a real inequality")
        }

        // Deterministic re-call: same tamper throws the identical error twice.
        do {
            try await mgr.verifyRestore(anchorID: id, presentedPayload: tampered)
            XCTFail("re-call must also throw (sample \(idx))")
        } catch let error as ManagerError {
            guard case .payloadHashMismatch(_, let expected2, let actual2) = error else {
                XCTFail("re-call expected payloadHashMismatch, got \(error)")
                continue
            }
            XCTAssertEqual(expected2, Manager.hash(original))
            XCTAssertEqual(actual2, Manager.hash(tampered))
        }
    }

    // ---- Randomized + replicated-oracle sweep over both gates ----
    var rng = SystemRandomNumberGenerator()
    let randomString: (Int) -> String = { n in
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        var s = ""
        for _ in 0..<n { s.append(alphabet[Int.random(in: 0..<alphabet.count, using: &rng)]) }
        return s
    }
    for trial in 0..<24 {
        let mgr = Manager()
        let id = "rand-\(trial)"
        let body = randomString(1 + (trial % 16))
        let data = payload(body)
        // Honest register succeeds.
        _ = try await mgr.register(anchor: honestAnchor(id, data), sealedPayload: data)

        // A different random payload (guaranteed distinct) must fail verifyRestore.
        var otherBody = randomString(1 + ((trial + 7) % 16))
        while Manager.hash(payload(otherBody)) == Manager.hash(data) {
            otherBody += "x"
        }
        let other = payload(otherBody)
        do {
            try await mgr.verifyRestore(anchorID: id, presentedPayload: other)
            XCTFail("random tamper trial \(trial) must throw")
        } catch let error as ManagerError {
            guard case .payloadHashMismatch(_, let expected, let actual) = error else {
                XCTFail("random trial \(trial) expected payloadHashMismatch, got \(error)")
                continue
            }
            XCTAssertEqual(expected, Manager.hash(data))
            XCTAssertEqual(actual, Manager.hash(other))
        }
        // The genuine payload still verifies (no false positive after a failed attempt).
        try await mgr.verifyRestore(anchorID: id, presentedPayload: data)
    }

    print("QINAO-GATE restore_payload_hash_gate: PASS (verifyRestore throws payloadHashMismatch on hash!=registered; register throws hashBindingMismatch on declared!=computed; exhaustive+randomized, tolerance=0, deterministic re-call, rejected anchors not stored)")
}
}

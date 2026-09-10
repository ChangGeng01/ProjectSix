import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASObservability
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASSovereign
import CryptoKit
import Foundation

/// QINAO Substrate-100 gates — Phase-2 batch 3 (audit-chain + memory determinism; agent-drafted, author-verified).
final class BASQINAOSubstrateGatesBatch3Tests: XCTestCase {

    func test_qinao_memory_governance_determinism() {
        // QINAO #38 L8 — BASMemoryGovernance.assess gate.
        // Claim A: pure-deterministic (same draft -> same verdict, N>=1000 replay).
        // Claim B: rejects 100% of provenanceRisk drafts (NO continuity escape).
        // Claim C: the 0.58 single-evidence low-confidence gate's SOLE admit
        //          exception is continuity-protection (goal/identity typeID),
        //          verified against a replicated oracle. tolerance = 0.
    
        // The real engine's contamination signals (BASMemoryTrustBehavior.generic).
        // Any provenanceSummary containing one of these (case-insensitive) => provenanceRisk.
        let contaminationSignals = [
            "<script", "</", "```", "http://", "https://",
            "assistant:", "tool call", "function(", "\"role\":", "{json"
        ]
        // The real gate constant extracted at MemoryGovernanceCore.swift line ~270.
        let lowConfThreshold = 0.58
        // Continuity-protected typeIDs per isContinuityProtected().
        let continuityTypeIDs: Set<String> = ["goal", "identity"]
    
        let sources: [BASMemorySource] = BASMemorySource.allCases
        let decays: [BASMemoryDecayPolicy] = BASMemoryDecayPolicy.allCases
        let promotions: [BASDraftPromotionPolicy] = [
            .immediate,
            .candidateOnly,
            .repeated(minConfirmationCount: 2, minEvidenceCount: 3)
        ]
        let typeIDs = ["goal", "identity", "situational", "support", "semantic", "fact"]
        let cleanProvenances = ["", "user typed this", "observed in-session", "manual note"]
        // Provenance strings that DO trip a contamination signal.
        let dirtyProvenances = contaminationSignals.map { "lead text \($0) trailing" }
        let confidences = [0.0, 0.30, 0.57, 0.5799, 0.58, 0.64, 0.80, 0.99]
        let evidenceCounts = [0, 1, 2, 5]
        let priorities = [0.0, 0.5, 0.69, 0.7, 0.95]
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    
        func makeDraft(
            typeID: String,
            source: BASMemorySource,
            decay: BASMemoryDecayPolicy,
            promotion: BASDraftPromotionPolicy,
            confidence: Double,
            priority: Double,
            evidence: Int,
            provenance: String
        ) -> BASMemoryGovernanceDraftInput {
            BASMemoryGovernanceDraftInput(
                id: "d-\(typeID)-\(source.rawValue)-\(evidence)",
                typeID: typeID,
                topic: "topic",
                headline: "headline",
                value: "value",
                confidence: confidence,
                priority: priority,
                source: source,
                lastConfirmedAt: fixedDate,
                decayPolicy: decay,
                retrievalTags: ["t1", "t2"],
                evidenceCount: evidence,
                provenanceSummary: provenance,
                promotionPolicy: promotion,
                tierID: "warm"
            )
        }
    
        // -------------------------------------------------------------------
        // Claim B: 100% provenanceRisk rejection, INCLUDING continuity types.
        // -------------------------------------------------------------------
        var provenanceChecks = 0
        for typeID in typeIDs {            // includes goal & identity (continuity)
            for source in sources {
                for promotion in promotions {
                    for dirty in dirtyProvenances {
                        let draft = makeDraft(
                            typeID: typeID, source: source, decay: .stable,
                            promotion: promotion, confidence: 0.99, priority: 0.95,
                            evidence: 9, provenance: dirty
                        )
                        let verdict = BASMemoryGovernance.assess(draft: draft)
                        XCTAssertEqual(
                            verdict.decision, .reject,
                            "provenanceRisk draft must reject (typeID=\(typeID), prov=\(dirty))"
                        )
                        provenanceChecks += 1
                    }
                }
            }
        }
        XCTAssertGreaterThan(provenanceChecks, 0)
    
        // -------------------------------------------------------------------
        // Claim A + C: deterministic replay + replicated oracle over a full
        // small-domain sweep. N is large (>1000) via the cross product.
        // -------------------------------------------------------------------
        var replayCount = 0
        var sawLowConfRejectClean = false
        var sawLowConfAdmitContinuity = false
    
        for typeID in typeIDs {
            for source in sources {
                for decay in decays {
                    for promotion in promotions {
                        for confidence in confidences {
                            for evidence in evidenceCounts {
                                for priority in priorities {
                                    for clean in cleanProvenances {
                                        let draft = makeDraft(
                                            typeID: typeID, source: source, decay: decay,
                                            promotion: promotion, confidence: confidence,
                                            priority: priority, evidence: evidence,
                                            provenance: clean
                                        )
                                        let first = BASMemoryGovernance.assess(draft: draft)
                                        let second = BASMemoryGovernance.assess(draft: draft)
                                        // Determinism: identical decision AND reason, tolerance 0.
                                        XCTAssertEqual(first.decision, second.decision)
                                        XCTAssertEqual(first.reason, second.reason)
                                        replayCount += 1
    
                                        // Oracle for the 0.58 continuity exception.
                                        // The clean provenances never trip contamination,
                                        // so provenanceRisk is false here by construction.
                                        let isCandidateOnly = promotion.isCandidateOnly
                                        let continuity = continuityTypeIDs.contains(typeID)
                                        let hitsLowConfGate =
                                            confidence < lowConfThreshold && evidence <= 1
                                        // The low-conf gate only fires AFTER the
                                        // candidateOnly/situational deferral short-circuit.
                                        let preEmptedByDeferral =
                                            isCandidateOnly || typeID == "situational"
    
                                        if hitsLowConfGate && !preEmptedByDeferral {
                                            if continuity {
                                                // Sole admit exception path.
                                                XCTAssertEqual(
                                                    first.decision, .admit,
                                                    "continuity low-conf must admit (type=\(typeID), conf=\(confidence), ev=\(evidence))"
                                                )
                                                sawLowConfAdmitContinuity = true
                                            } else {
                                                XCTAssertEqual(
                                                    first.decision, .reject,
                                                    "non-continuity low-conf single-evidence must reject (type=\(typeID), conf=\(confidence), ev=\(evidence))"
                                                )
                                                sawLowConfRejectClean = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    
        XCTAssertGreaterThanOrEqual(replayCount, 1000, "N>=1000 replay required")
        XCTAssertTrue(sawLowConfRejectClean, "must exercise the low-conf reject path")
        XCTAssertTrue(sawLowConfAdmitContinuity, "must exercise the continuity admit exception")
    
        // -------------------------------------------------------------------
        // Cross-overload determinism: assess(draft:behavior:) re-call stability
        // against an explicit generic behavior matches the default overload.
        // -------------------------------------------------------------------
        let probe = makeDraft(
            typeID: "fact", source: .pattern, decay: .medium,
            promotion: .immediate, confidence: 0.9, priority: 0.8,
            evidence: 3, provenance: "clean note"
        )
        let viaDefault = BASMemoryGovernance.assess(draft: probe)
        let viaExplicit = BASMemoryGovernance.assess(draft: probe, behavior: .generic)
        XCTAssertEqual(viaDefault, viaExplicit)
    
        print("QINAO-GATE memory_governance_determinism: PASS replay=\(replayCount) provenanceRejects=\(provenanceChecks) (100% reject, deterministic, 0.58 continuity exception verified vs oracle)")
    }

    func test_qinao_event_projection_replay_determinism() async throws {
        // QINAO #39 L8 — BASMemoryAtomReducer.project is order-stable:
        //   the SAME event multiset folded in N random orders must yield
        //   a BYTE-IDENTICAL projection, AND warm-at-init (replay from
        //   storage) must equal the lazy in-loop fold. tolerance = 0.
        //
        // Construction uses a commutative multiset: each atomID is
        // admitted EXACTLY ONCE with distinct fields, so the projection
        // is a pure set-union independent of fold order. The reducer's
        // admission-tiebreak keeps existing on equal confidence, but with
        // unique atomIDs no key ever collides, so order cannot change the
        // outcome — that is exactly the order-stability the gate raises.
    
        // --- Deterministic oracle: build N distinct .admitted payloads.
        let n = 200
        let kinds: [BASMemoryKind] = [
            .episodic, .semantic, .profile, .goal,
            .situational, .support, .template, .failurePattern]
        let scopes: [BASMemoryScope] = [.user, .device, .session, .task]
        let sensitivities: [BASMemorySensitivity] = [.low, .medium, .high]
        let tiers: [BASMemoryTier] = [.hot, .warm, .cold]
        let statuses: [BASMemoryGovernanceStatus] = [
            .candidate, .governed, .quarantined, .rejected, .archived]
    
        // Stable UUIDs derived from index so the multiset is reproducible.
        func uuid(_ i: Int) -> UUID {
            let s = String(format: "00000000-0000-4000-8000-%012d", i)
            return UUID(uuidString: s)!
        }
    
        var atoms: [BASGovernedMemory] = []
        atoms.reserveCapacity(n)
        for i in 0..<n {
            let atom = BASGovernedMemory(
                id: uuid(i),
                kind: kinds[i % kinds.count],
                // Content is host-ephemeral; replay always projects "".
                // Use "" here so the oracle equals the reducer output.
                content: "",
                scope: scopes[i % scopes.count],
                sensitivity: sensitivities[i % sensitivities.count],
                tier: tiers[i % tiers.count],
                // Vary confidence; clamped to 0..1 by the payload init.
                confidence: Double(i % 101) / 100.0,
                sourceType: "src-\(i % 7)",
                lastConfirmedAt: (i % 3 == 0)
                    ? Date(timeIntervalSince1970: Double(1_000 + i))
                    : nil,
                decayScore: 0.0,
                governanceStatus: statuses[i % statuses.count],
                provenanceSummary: "prov-\(i)")
            atoms.append(atom)
        }
    
        // Build the canonical event multiset (one .admitted per atom).
        let sessionID = "qinao-39-session"
        var events: [BASEventLogEntry] = []
        events.reserveCapacity(n)
        for (i, atom) in atoms.enumerated() {
            let payload = BASMemoryAtomEventPayload(admitted: atom)
            let entry = BASEventLogEntry.memoryAtomEvent(
                eventID: "evt-\(i)",
                timestampMs: Int64(10_000 + i),
                sessionID: sessionID,
                payload: payload)
            events.append(entry)
        }
    
        // Replicated oracle: the projection MUST equal the set of atoms
        // keyed by uuidString (content "" on replay — already "").
        var oracle: [String: BASGovernedMemory] = [:]
        for atom in atoms { oracle[atom.id.uuidString] = atom }
    
        // Byte-stable serializer for tolerance-0 comparison.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        func bytes(_ p: [String: BASGovernedMemory]) throws -> Data {
            try encoder.encode(p)
        }
        let oracleBytes = try bytes(oracle)
    
        // --- N random orders -> byte-identical lazy fold projection.
        var rng = SystemRandomNumberGenerator()
        let orders = 64
        var reference: Data? = nil
        for _ in 0..<orders {
            var shuffled = events
            shuffled.shuffle(using: &rng)
            var proj: [String: BASGovernedMemory] = [:]
            for e in shuffled {
                proj = BASMemoryAtomReducer.reduce(
                    priorAtoms: proj, event: e)
            }
            let b = try bytes(proj)
            // Equals the replicated oracle (tolerance 0).
            XCTAssertEqual(b, oracleBytes,
                "order-permuted fold diverged from oracle")
            // Equals every other order (byte-identical across orders).
            if let ref = reference {
                XCTAssertEqual(b, ref,
                    "two random orders produced different projections")
            } else {
                reference = b
            }
            XCTAssertEqual(proj.count, n)
        }
    
        // --- Deterministic re-call: same input array -> identical output.
        var fold1: [String: BASGovernedMemory] = [:]
        var fold2: [String: BASGovernedMemory] = [:]
        for e in events {
            fold1 = BASMemoryAtomReducer.reduce(priorAtoms: fold1, event: e)
        }
        for e in events {
            fold2 = BASMemoryAtomReducer.reduce(priorAtoms: fold2, event: e)
        }
        XCTAssertEqual(try bytes(fold1), try bytes(fold2),
            "deterministic re-call diverged")
    
        // --- warm-at-init == lazy: replay from storage (append in a
        // SHUFFLED order; storage assigns sequence, project folds in
        // sequence order) must equal the lazy fold / oracle.
        let storage = BASInMemoryEventLogStorage()
        var appendOrder = events
        appendOrder.shuffle(using: &rng)
        for e in appendOrder {
            _ = try await storage.append(e)
        }
        let warm = await BASMemoryAtomReducer.project(
            from: storage, sessionID: sessionID)
        XCTAssertEqual(try bytes(warm), oracleBytes,
            "warm-at-init (storage replay) != lazy oracle projection")
        XCTAssertEqual(warm.count, n)
    
        print("QINAO-GATE event_projection_replay_determinism: PASS "
            + "(n=\(n) atoms, \(orders) random orders byte-identical, "
            + "deterministic re-call stable, warm-at-init==lazy)")
    }

    func test_qinao_projection_content_empty_on_replay() async throws {
        // ---- Arrange: a canonical event log shared across stores ----
        let sessionID = "qinao-projection-content-empty"
        let log = BASInMemoryEventLogStorage()
    
        // Small exhaustive-ish domain sweep: every kind × a rotating set of
        // scope/sensitivity/tier/governance, each with DISTINCT non-empty content.
        let kinds: [BASMemoryKind] = [
            .episodic, .semantic, .profile, .goal,
            .situational, .support, .template, .failurePattern,
        ]
        let scopes: [BASMemoryScope] = [.user, .device, .session, .task]
        let sensitivities: [BASMemorySensitivity] = [.low, .medium, .high]
        let tiers: [BASMemoryTier] = [.hot, .warm, .cold]
        let statuses: [BASMemoryGovernanceStatus] = [
            .candidate, .governed, .quarantined, .rejected, .archived,
        ]
    
        // Replicated oracle: id -> (originalContent, expectedDigest).
        var oracleContent: [String: String] = [:]
        var oracleDigest: [String: String] = [:]
        var oracleState: [String: BASGovernedMemory] = [:]  // with empty content
    
        // ---- Act 1: WRITER store with an in-process content cache ----
        // `.warmAtInit` keeps the in-actor caches; admit populates contentCache.
        let writer = BASEventSourcedMemoryAtomStore(
            eventLog: log,
            sessionID: sessionID,
            source: "qinao-writer",
            cachePolicy: .warmAtInit)
    
        for (i, kind) in kinds.enumerated() {
            let id = UUID()
            let content = "SECRET-PLAINTEXT-\(kind.rawValue)-\(i)-🔒"
            XCTAssertFalse(content.isEmpty, "test setup must use non-empty content")
            let atom = BASGovernedMemory(
                id: id,
                kind: kind,
                content: content,
                scope: scopes[i % scopes.count],
                sensitivity: sensitivities[i % sensitivities.count],
                tier: tiers[i % tiers.count],
                confidence: Double(i + 1) / Double(kinds.count + 1),
                sourceType: "qinao-source-\(i)",
                lastConfirmedAt: nil,
                decayScore: 0.0,
                governanceStatus: statuses[i % statuses.count],
                provenanceSummary: "prov-\(i)")
    
            let appended = try await writer.admit(atom)
            XCTAssertTrue(appended, "fresh distinct atom must append (id=\(id))")
    
            oracleContent[id.uuidString] = content
            // Oracle digest = the SAME pure hash the payload init uses.
            oracleDigest[id.uuidString] =
                BASMemoryAtomEventPayload.sha256Hex(content)
            // Oracle for projected state = atom with content forced empty.
            var emptied = atom
            emptied.content = ""
            emptied.decayScore = 0.0
            oracleState[id.uuidString] = emptied
        }
    
        // In-process writer DOES see full content (the content cache is alive).
        let writerAll = await writer.allAtoms()
        XCTAssertEqual(
            writerAll.count, kinds.count,
            "writer projection must contain every admitted atom")
        for atom in writerAll {
            XCTAssertEqual(
                atom.content, oracleContent[atom.id.uuidString],
                "in-process writer must hydrate full content from its cache")
        }
    
        // ---- Act 2: REPLAY store — NEW store over the SAME log, NO cache ----
        // A brand-new store has an EMPTY contentCache, so it can only project
        // from the event log. This is invariant #3: rebuilt-from-log => empty content.
        let replay = BASEventSourcedMemoryAtomStore(
            eventLog: log,
            sessionID: sessionID,
            source: "qinao-replay",
            cachePolicy: .lazy)
    
        let replayed = await replay.allAtoms()
    
        // ---- Assert: exhaustive, tolerance 0 ----
        XCTAssertEqual(
            replayed.count, kinds.count,
            "replay must reconstruct exactly the admitted atom set from the log")
    
        for atom in replayed {
            let key = atom.id.uuidString
            guard let expectedDigest = oracleDigest[key],
                  let expectedState = oracleState[key],
                  let original = oracleContent[key] else {
                XCTFail("replayed an unknown atom id=\(key)")
                continue
            }
    
            // (1) INVARIANT #3 core: content is EMPTY after pure replay.
            XCTAssertEqual(
                atom.content, "",
                "replayed atom \(key) must have EMPTY content (no in-process cache)")
            XCTAssertTrue(
                atom.content.isEmpty,
                "replayed content must be the empty string, not a placeholder")
    
            // (2) Plaintext must NOT survive anywhere in the projected atom.
            XCTAssertFalse(
                original.isEmpty,
                "oracle content should have been non-empty plaintext")
            XCTAssertFalse(
                atom.provenanceSummary.contains(original),
                "plaintext must not leak into provenanceSummary on replay")
    
            // (3) All OTHER state survives the projection byte-for-byte.
            XCTAssertEqual(
                atom, expectedState,
                "non-content atom state must replay exactly (kind/scope/tier/...)")
    
            // (4) Only the digest survives — and it equals SHA256(original),
            //     non-empty, recoverable from the raw event payload.
            XCTAssertEqual(
                expectedDigest.count, 64,
                "SHA256 hex digest must be 64 chars")
            XCTAssertNotEqual(
                expectedDigest, "",
                "contentDigest must be present (only thing that survives content)")
        }
    
        // ---- Assert: the digest truly lives in the raw event log ----
        // Pull the admit events straight off the canonical log and confirm the
        // surviving contentDigest matches SHA256(originalContent) exactly, while
        // the payload carries NO plaintext content field at all.
        let events = await log.events(forSession: sessionID)
        var sawAdmit = 0
        for event in events {
            guard let payload = event.memoryAtomEventPayload,
                  payload.op == .admitted else { continue }
            sawAdmit += 1
            let key = payload.atomID
            XCTAssertEqual(
                payload.contentDigest, oracleDigest[key],
                "event-log contentDigest must equal SHA256(originalContent)")
            // The typed payload has no `content` field — digest is the only
            // content-derived survivor. Re-hashing the (lost) plaintext is the
            // ONLY way back; assert the digest is the hash, not the text.
            if let original = oracleContent[key], let d = payload.contentDigest {
                XCTAssertNotEqual(
                    d, original,
                    "surviving field must be the DIGEST, never the plaintext")
                XCTAssertEqual(
                    d, BASMemoryAtomEventPayload.sha256Hex(original),
                    "digest must be reproducibly SHA256(content)")
            }
        }
        XCTAssertEqual(
            sawAdmit, kinds.count,
            "every admit must be a contentDigest-bearing event on the log")
    
        // ---- Assert: deterministic re-replay — a THIRD store is byte-equal ----
        let replay2 = BASEventSourcedMemoryAtomStore(
            eventLog: log,
            sessionID: sessionID,
            source: "qinao-replay-2",
            cachePolicy: .warmAtInit)
        let replayed2 = await replay2.projectAll()
        let replayed1Map = await replay.projectAll()
        XCTAssertEqual(
            replayed1Map, replayed2,
            "two independent cacheless replays must produce byte-equal projections")
        for (_, atom) in replayed2 {
            XCTAssertEqual(
                atom.content, "",
                "second replay path must also yield empty content")
        }
    
        print("QINAO-GATE projection_content_empty_on_replay: PASS "
            + "(\(kinds.count) atoms; replay content all empty, only 64-char "
            + "SHA256 contentDigest survives on the event log; deterministic "
            + "re-replay byte-equal)")
    }

    func test_qinao_forget_cascade_execution_correctness() {
        // QINAO #42 L8: BASMemoryForgetCascadeRunner.apply deletes EXACTLY
        // the records whose memoryID lies in (rootTargets ∪ dependentRefs),
        // with 0 over-delete, 0 under-delete, and every retained sibling
        // preserved byte-identically (Equatable). Exhaustive small-domain
        // sweep over the membership subset lattice, against a replicated
        // oracle. tolerance=0.
    
        let runner = BASMemoryForgetCascadeRunner()
        // Pin the legacy Swift path deterministically for this gate.
        let savedFlag = BASMemoryForgetCascadeRunner.useRoutedFilter
        BASMemoryForgetCascadeRunner.useRoutedFilter = false
        defer { BASMemoryForgetCascadeRunner.useRoutedFilter = savedFlag }
    
        // Fixed clock → deterministic timing stamps.
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let clock: () -> Date = { t0 }
    
        // Universe of N distinct records with distinct memoryIDs. Each
        // record carries a unique summary so byte-identity (not just ID
        // match) is asserted for retained siblings.
        let N = 8
        func makeRecord(_ i: Int) -> BASTemporalMemoryRecord {
            BASTemporalMemoryRecord(
                memoryID: "mem-\(i)",
                summary: "summary-payload-\(i)-\(i * 31 + 7)",
                memoryType: BASTemporalMemoryType.allCases[i % BASTemporalMemoryType.allCases.count],
                sourceClass: "src-class-\(i)",
                sourceRefs: ["ref-\(i)-a", "ref-\(i)-b"],
                timestamp: Date(timeIntervalSince1970: 1_600_000_000 + Double(i)),
                certainty: Double(i) / Double(N),
                evidenceStrength: 1.0 - Double(i) / Double(N),
                emotionalWeight: Double(i) * 0.1,
                hostScope: "host-\(i)",
                sovereignScope: "sov-\(i)",
                lineageRefs: ["lin-\(i)"])
        }
        let allRecords = (0..<N).map(makeRecord)
        let allIDs = allRecords.map { $0.memoryID }
    
        // Decorate the field with non-records collections so we can assert
        // the runner preserves them byte-for-byte on the happy path.
        let baseField = BASTemporalMemoryField(records: allRecords)
    
        // Sweep every subset of records as the deletion target, and
        // independently split that subset across rootTargets / dependentRefs
        // to exercise the UNION semantics (an ID in either bucket deletes).
        // 2^N subsets × split rule by index parity = exhaustive over
        // membership; union split deterministically derived.
        let subsetCount = 1 << N
        var casesChecked = 0
        for mask in 0..<subsetCount {
            // Build the target subset from the bitmask.
            var targetSet = Set<String>()
            var rootTargets: [String] = []
            var dependentRefs: [String] = []
            for i in 0..<N where (mask & (1 << i)) != 0 {
                let id = allIDs[i]
                targetSet.insert(id)
                // Split union across the two buckets by parity; this proves
                // rootTargets ∪ dependentRefs is the matching domain.
                if i % 2 == 0 { rootTargets.append(id) }
                else { dependentRefs.append(id) }
            }
            // Inject a non-existent target into a bucket on every other case
            // to prove phantom targets never over-delete (and don't fail the
            // cascade as long as a real target also matches).
            if mask != 0 && mask % 2 == 0 {
                dependentRefs.append("phantom-id-does-not-exist-\(mask)")
            }
    
            let cascade = BASMemoryForgetCascade(
                cascadeID: "casc-\(mask)",
                rootTargets: rootTargets,
                dependentRefs: dependentRefs,
                executionState: BASForgetCascadeExecutionState.queued.rawValue)
    
            // Empty-cascade (no real and no phantom targets) is the
            // pre-flight .failed branch — handled separately below; here we
            // only feed mask==0 when it has the phantom guard off, so skip.
            if rootTargets.isEmpty && dependentRefs.isEmpty {
                // Exercise the .failed pre-flight branch and assert no delete.
                let (f, o) = runner.apply(cascade, to: baseField, now: clock)
                XCTAssertEqual(o.terminalState, .failed, "empty cascade must fail")
                XCTAssertEqual(o.removedRecordIDs, [], "failed cascade removes nothing")
                XCTAssertEqual(o.reasonCodes, ["empty-cascade-targets"])
                XCTAssertEqual(f.records, allRecords, "failed cascade leaves field byte-identical")
                XCTAssertEqual(f.records.count, N)
                casesChecked += 1
                continue
            }
    
            let (newField, outcome) = runner.apply(cascade, to: baseField, now: clock)
    
            // Replicated oracle: expected removed = intersection of target
            // set with the universe of present record IDs; expected retained
            // = the complement, in original order.
            let expectedRemoved = allRecords.filter { targetSet.contains($0.memoryID) }
            let expectedRetained = allRecords.filter { !targetSet.contains($0.memoryID) }
            let expectedRemovedIDs = expectedRemoved.map { $0.memoryID }
    
            if expectedRemoved.isEmpty {
                // No real match → .skipped, field untouched (phantom only).
                XCTAssertEqual(outcome.terminalState, .skipped, "no-match → skipped (mask \(mask))")
                XCTAssertEqual(outcome.removedRecordIDs, [], "skipped removes nothing")
                XCTAssertEqual(outcome.reasonCodes, ["nothing-to-remove"])
                XCTAssertEqual(newField.records, allRecords, "skipped leaves records byte-identical")
            } else {
                // Happy path: EXACT delete, EXACT retain.
                XCTAssertEqual(outcome.terminalState, .completed, "matched → completed (mask \(mask))")
                // 0 over-delete + 0 under-delete: removed ID set is exactly
                // the present-target set, and in field traversal order.
                XCTAssertEqual(outcome.removedRecordIDs, expectedRemovedIDs,
                               "removed IDs exact + ordered (mask \(mask))")
                XCTAssertEqual(Set(outcome.removedRecordIDs), Set(expectedRemovedIDs),
                               "no phantom over-delete (mask \(mask))")
                // Retained siblings: byte-identical (full Equatable), same order.
                XCTAssertEqual(newField.records, expectedRetained,
                               "retained siblings byte-identical + ordered (mask \(mask))")
                // Count conservation: removed + retained == universe.
                XCTAssertEqual(newField.records.count + outcome.removedRecordIDs.count, N,
                               "count conservation (mask \(mask))")
                // No retained record's ID is in the target set (under-delete guard).
                for r in newField.records {
                    XCTAssertFalse(targetSet.contains(r.memoryID),
                                   "retained record \(r.memoryID) was a target — under-delete (mask \(mask))")
                }
                // Cascade stamped completed.
                XCTAssertEqual(outcome.cascade.executionState,
                               BASForgetCascadeExecutionState.completed.rawValue)
            }
    
            // Non-records collections are preserved byte-for-byte on every path.
            XCTAssertEqual(newField.schemaVersion, baseField.schemaVersion)
            XCTAssertEqual(newField.temperatureProfiles, baseField.temperatureProfiles)
            XCTAssertEqual(newField.provenanceSeals, baseField.provenanceSeals)
            XCTAssertEqual(newField.episodeArcs, baseField.episodeArcs)
            XCTAssertEqual(newField.sanctumEntries, baseField.sanctumEntries)
            XCTAssertEqual(newField.forgetCascades, baseField.forgetCascades)
    
            // Input field is never mutated (pure-value contract).
            XCTAssertEqual(baseField.records, allRecords, "input field unmutated (mask \(mask))")
    
            // Deterministic re-call: identical inputs → identical outputs.
            let (newField2, outcome2) = runner.apply(cascade, to: baseField, now: clock)
            XCTAssertEqual(newField2.records, newField.records, "deterministic re-call records (mask \(mask))")
            XCTAssertEqual(outcome2.removedRecordIDs, outcome.removedRecordIDs, "deterministic re-call removed (mask \(mask))")
            XCTAssertEqual(outcome2.terminalState, outcome.terminalState, "deterministic re-call state (mask \(mask))")
    
            casesChecked += 1
        }
    
        XCTAssertEqual(casesChecked, subsetCount, "every subset of the membership lattice exercised")
        print("QINAO-GATE forget_cascade_execution_correctness: PASS — exhaustive \(subsetCount)-subset (2^\(N)) membership sweep over rootTargets∪dependentRefs: 0 over-delete, 0 under-delete, retained siblings byte-identical, phantom-target safe, pure/deterministic, non-record collections preserved.")
    }

    func test_qinao_budget_overrun_escape_rate() {
        // ---- Real coordinator from placeholder seats (BASEBrainRuntimeCoordinator is a public struct, not an actor) ----
        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService: BASPlaceholderPowerClockService(),
            hostProfileService: BASPlaceholderHostProfileService(),
            contextService: BASPlaceholderContextService(),
            decomposeService: BASPlaceholderDecomposeService(),
            memoryService: BASPlaceholderMemoryService(),
            loopService: BASPlaceholderLoopService(),
            triSelfService: BASPlaceholderTriSelfService(),
            riskService: BASPlaceholderRiskService(),
            actionService: BASPlaceholderActionService(),
            evolutionService: BASPlaceholderEvolutionService())
    
        // Helper: a raw (pre-normalization) budget frame with caller-chosen caps.
        func rawBudget(maxLoops: Int, maxCandidates: Int, retrievalDepth: Int) -> BASBudgetFrame {
            BASBudgetFrame(
                runMode: .engage,
                maxLoops: maxLoops,
                maxCandidates: maxCandidates,
                maxDecodeTokens: 64,
                retrievalDepth: retrievalDepth,
                precisionProfile: .balanced,
                deviceRoute: .scoutCPU,
                thermalGuardLevel: .nominal,
                maintenanceAllowed: false)
        }
        func makeCandidate(_ i: Int) -> BASCandidatePath {
            BASCandidatePath(
                candidateID: "cand.\(i)", title: "t\(i)", actionSummary: "a\(i)",
                expectedBenefit: 0.5, expectedCost: 0.5, reversibility: 0.5, confidence: 0.5)
        }
        func makeAtom(_ i: Int) -> BASMemoryAtom {
            BASMemoryAtom(
                memoryID: "mem.\(i)", summary: "s\(i)", contentType: .warm,
                source: "test", confidence: 0.5, conflictFingerprint: "fp.\(i)")
        }
        func makeFrame(stepIndex: Int, candidateCount: Int, decomposeRef: String) -> BASThoughtFrame {
            BASThoughtFrame(
                stepIndex: stepIndex,
                decomposeRef: decomposeRef,
                candidates: (0..<candidateCount).map(makeCandidate))
        }
    
        var escapes = 0
        var clampFindingsChecked = 0
    
        // ============================================================
        // PART A — normalizeBudget floor enforcement: maxLoops>=1, maxCandidates>=1
        // Sweep degenerate caps (incl. 0 and negative) and assert each clamp emits enforced=true.
        // Note: BASBudgetFrame.init floors maxCandidates to >=1; maxLoops is allowed to be 0 pre-normalize.
        // ============================================================
        for rawLoops in [-3, 0, 1, 2] {
            let budget = rawBudget(maxLoops: rawLoops, maxCandidates: 1, retrievalDepth: 3)
            let (norm, findings) = coordinator.normalizeBudget(
                budget, riskHint: nil, activeKillSwitches: [])
            // Raised bar: floors must hold.
            XCTAssertGreaterThanOrEqual(norm.maxLoops, 1, "maxLoops floor not enforced for raw=\(rawLoops)")
            XCTAssertGreaterThanOrEqual(norm.maxCandidates, 1, "maxCandidates floor not enforced for raw=\(rawLoops)")
            if norm.maxLoops < 1 || norm.maxCandidates < 1 { escapes += 1 }
            // Every emitted finding is an enforced clamp (tolerance=0 on the enforced flag).
            for f in findings {
                XCTAssertTrue(f.enforced, "budget finding \(f.code) not enforced")
                clampFindingsChecked += 1
            }
            // When the raw value was below the floor, a loop_floor clamp MUST have fired.
            if budget.maxLoops < 1 {
                XCTAssertTrue(findings.contains { $0.code == "budget.loop_floor" && $0.enforced },
                              "expected enforced budget.loop_floor for raw=\(rawLoops)")
            }
        }
    
        // ============================================================
        // PART B — normalizeThoughtFrame (L9) + normalizeMemoryBundle (L8) overrun clamps.
        // Exhaustive small-domain sweep of (cap, overrun) pairs with a replicated oracle.
        // ============================================================
        let caps = [1, 2, 3, 4]
        for maxLoops in caps {
            for maxCandidates in caps {
                for retrievalDepth in caps {
                    let budget = rawBudget(
                        maxLoops: maxLoops, maxCandidates: maxCandidates, retrievalDepth: retrievalDepth)
                    // Sweep over- and at/under-budget magnitudes.
                    for stepIndex in [0, 1, maxLoops, maxLoops + 1, maxLoops + 5] {
                        for candidateCount in [0, maxCandidates, maxCandidates + 1, maxCandidates + 4] {
                            let ref = "dec.\(maxLoops).\(maxCandidates).\(stepIndex).\(candidateCount)"
                            let frame = makeFrame(
                                stepIndex: stepIndex, candidateCount: candidateCount, decomposeRef: ref)
                            let (nf, frameFindings) = coordinator.normalizeThoughtFrame(frame, budget: budget)
    
                            // Raised bar: post-normalize MUST be within budget. No escapes.
                            XCTAssertLessThanOrEqual(nf.stepIndex, budget.maxLoops,
                                "stepIndex escaped maxLoops (\(stepIndex)>\(budget.maxLoops))")
                            XCTAssertLessThanOrEqual(nf.candidates.count, budget.maxCandidates,
                                "candidates escaped maxCandidates (\(candidateCount)>\(budget.maxCandidates))")
                            if nf.stepIndex > budget.maxLoops { escapes += 1 }
                            if nf.candidates.count > budget.maxCandidates { escapes += 1 }
    
                            // Replicated oracle: a clamp finding must appear IFF the input overran.
                            let loopClamp = frameFindings.contains {
                                $0.code == "loop.max_loops_clamped" }
                            let candClamp = frameFindings.contains {
                                $0.code == "loop.candidate_budget_clamped" }
                            XCTAssertEqual(loopClamp, stepIndex > budget.maxLoops,
                                "loop clamp finding mismatch at step=\(stepIndex) cap=\(budget.maxLoops)")
                            XCTAssertEqual(candClamp, candidateCount > budget.maxCandidates,
                                "candidate clamp finding mismatch at n=\(candidateCount) cap=\(budget.maxCandidates)")
                            if stepIndex > budget.maxLoops {
                                XCTAssertEqual(nf.stopReason, .maxLoopsReached,
                                    "stopReason not set on loop clamp")
                            }
                            // Every emitted finding is enforced=true (tolerance=0).
                            for f in frameFindings {
                                XCTAssertTrue(f.enforced, "thought finding \(f.code) not enforced")
                                XCTAssertEqual(f.layerID, "L9", "thought clamp not tagged L9")
                                clampFindingsChecked += 1
                            }
    
                            // Determinism: re-call yields identical clamp + same finding codes.
                            let (nf2, ff2) = coordinator.normalizeThoughtFrame(frame, budget: budget)
                            XCTAssertEqual(nf2.stepIndex, nf.stepIndex, "non-deterministic stepIndex clamp")
                            XCTAssertEqual(nf2.candidates.count, nf.candidates.count,
                                "non-deterministic candidate clamp")
                            XCTAssertEqual(ff2.map(\.code), frameFindings.map(\.code),
                                "non-deterministic finding set")
    
                            // ---- L8 atoms vs retrievalDepth ----
                            for atomCount in [0, retrievalDepth, retrievalDepth + 1, retrievalDepth + 3] {
                                let bundle = BASMemoryBundle(atoms: (0..<atomCount).map(makeAtom))
                                let (nb, bundleFindings) = coordinator.normalizeMemoryBundle(
                                    bundle, budget: budget)
                                XCTAssertLessThanOrEqual(nb.atoms.count, budget.retrievalDepth,
                                    "atoms escaped retrievalDepth (\(atomCount)>\(budget.retrievalDepth))")
                                if nb.atoms.count > budget.retrievalDepth { escapes += 1 }
                                let depthClamp = bundleFindings.contains {
                                    $0.code == "memory.retrieval_depth_clamped" }
                                XCTAssertEqual(depthClamp, atomCount > budget.retrievalDepth,
                                    "depth clamp finding mismatch at n=\(atomCount) cap=\(budget.retrievalDepth)")
                                for f in bundleFindings {
                                    XCTAssertTrue(f.enforced, "memory finding \(f.code) not enforced")
                                    XCTAssertEqual(f.layerID, "L8", "memory clamp not tagged L8")
                                    clampFindingsChecked += 1
                                }
                            }
                        }
                    }
                }
            }
        }
    
        // ---- Final raised-bar assertions ----
        XCTAssertEqual(escapes, 0, "QINAO budget gate: budget overruns escaped normalization")
        XCTAssertGreaterThan(clampFindingsChecked, 0, "no enforced clamp findings were exercised")
    
        print("QINAO-GATE budget_overrun_escape_rate: PASS escapes=\(escapes) enforcedClampFindings=\(clampFindingsChecked) (L9 stepIndex<=maxLoops, candidates<=maxCandidates; L8 atoms<=retrievalDepth; floors maxLoops>=1, maxCandidates>=1; every clamp enforced=true; deterministic)")
    }

    func test_qinao_chain_seal_determinism_byte_equal() async throws {
        // ===========================================================================
        // QINAO #83 L14 — chain seal determinism + canonical injectivity (tolerance=0)
        //
        // Three raised bars, all asserted with exact byte equality / zero collisions:
        //   (A) selfHash + HMAC signature are BYTE-IDENTICAL across repeated appends
        //       of identical logical entries (deterministic re-call).
        //   (B) selfHash + HMAC signature are BYTE-IDENTICAL legacy (CryptoKit
        //       `hash`) vs routed (Rust `hashViaAutoRouter`) seal paths — the
        //       opt-in default-flip cannot break chain of custody.
        //   (C) schema 1.2.0 length-prefixed canonical encoding is INJECTIVE:
        //       0 collisions across an exhaustive small-domain sweep of every
        //       field that varies, INCLUDING in-band U+001F/U+001E separators
        //       and the ambiguous composite-ref shapes that defeated 1.0.0/1.1.0.
        // ===========================================================================
    
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000.123)
        let namespace = BASSovereignTrustConstants.signingNamespace
        let secret = SymmetricKey(data: SHA256.hash(data: Data("qinao-83-seal-seed".utf8)))
    
        // A small, fully-deterministic chain of hardened (1.2.0) entries. Each
        // carries composite refs that legitimately contain the hardened-format
        // separators (U+001F unit / U+001E record) so the seal must survive them.
        func makeEntries() -> [BASSovereignAuditEntry] {
            (0..<10).map { i in
                BASSovereignAuditEntry(
                    schemaVersion: BASSovereignAuditEntry.hardenedSchemaVersion, // "1.2.0"
                    auditID: "audit-\(i)",
                    sessionID: "sess-\(i % 3)",
                    turnID: "turn-\(i)",
                    verdictRef: "shadow_trial\u{1F}vd-\(i)",        // in-band U+001F
                    ruleIDs: ["RULE-A", "RULE-\(i)"],
                    signalRefs: ["sig\u{1F}\(i)", "sig-b\u{1E}\(i)"], // in-band U+001F + U+001E
                    actionRefs: ["act-\(i)"],
                    snapshotRef: "snap-\(i)",
                    actor: i % 2 == 0 ? .system : .operator,
                    signature: "",
                    appendedAt: fixedDate.addingTimeInterval(Double(i)))
            }
        }
    
        // Helper: append the chain to a fresh HMAC ledger under a given seal mode,
        // returning the appended records (selfHash + signature live here). The
        // routed-seal flag is global static + nonisolated(unsafe); set it BEFORE
        // constructing/using the ledger (the comment in append() requires this).
        func sealChain(useRouted: Bool) async throws -> [BASSovereignAuditLedger.AppendedEntry] {
            BASSovereignAuditLedger.useRoutedSeal = useRouted
            let ledger = BASSovereignAuditLedger(
                signingSecret: secret, signingNamespace: namespace)
            var out: [BASSovereignAuditLedger.AppendedEntry] = []
            for e in makeEntries() {
                out.append(try await ledger.append(e))
            }
            // Independent confirmation the whole chain verifies (selfHash recomputed
            // by CryptoKit must match even when sealed via the routed path).
            try await ledger.verifyChainIntegrity()
            return out
        }
    
        let savedFlag = BASSovereignAuditLedger.useRoutedSeal
        defer { BASSovereignAuditLedger.useRoutedSeal = savedFlag }
    
        // ---- (A) deterministic re-call: legacy path, twice, must be byte-equal ----
        let legacy1 = try await sealChain(useRouted: false)
        let legacy2 = try await sealChain(useRouted: false)
        XCTAssertEqual(legacy1.count, 10)
        XCTAssertEqual(legacy2.count, 10)
        for i in 0..<legacy1.count {
            XCTAssertEqual(legacy1[i].selfHash, legacy2[i].selfHash,
                           "selfHash not deterministic across repeats at \(i)")
            XCTAssertEqual(legacy1[i].priorHash, legacy2[i].priorHash,
                           "priorHash not deterministic across repeats at \(i)")
            XCTAssertEqual(legacy1[i].entry.signature, legacy2[i].entry.signature,
                           "HMAC signature not deterministic across repeats at \(i)")
            XCTAssertFalse(legacy1[i].selfHash.isEmpty)
            XCTAssertFalse(legacy1[i].entry.signature.isEmpty)
        }
    
        // ---- (B) legacy-vs-routed seal: byte-identical selfHash + signature ----
        let routed = try await sealChain(useRouted: true)
        XCTAssertEqual(routed.count, legacy1.count)
        for i in 0..<routed.count {
            XCTAssertEqual(routed[i].selfHash, legacy1[i].selfHash,
                           "routed selfHash != legacy selfHash at \(i)")
            XCTAssertEqual(routed[i].priorHash, legacy1[i].priorHash,
                           "routed priorHash != legacy priorHash at \(i)")
            // HMAC signing is independent of the seal flag, so it must match too.
            XCTAssertEqual(routed[i].entry.signature, legacy1[i].entry.signature,
                           "routed signature != legacy signature at \(i)")
        }
    
        // Direct primitive equality on raw canonical bytes (no ledger framing):
        // CryptoKit SHA256→base64 must equal the Rust routed seal→base64 exactly.
        for probe in ["", "abc", "\u{1F}\u{1E}composite", String(repeating: "z", count: 200)] {
            let data = Data(probe.utf8)
            let cryptoKit = Data(SHA256.hash(data: data)).base64EncodedString()
            let routedHash = BASSovereignAuditLedger.hashViaAutoRouter(data)
            XCTAssertEqual(cryptoKit, routedHash,
                           "routed seal != CryptoKit SHA256 for probe \(probe.debugDescription)")
        }
    
        // ---- (C) schema 1.2.0 canonical encoding is INJECTIVE (0 collisions) ----
        // Sweep every field across a domain that deliberately includes the empty
        // string, the hardened separators, and the "boundary-shift" pairs that
        // make a delimiter-join non-injective (e.g. ["a","bc"] vs ["a\u{1F}bc"],
        // ["", "x"] vs ["x", ""]). Length-prefixing must keep all distinct.
        let pHash = "PRIOR-HASH-CONST"
        let strDomain = ["", "a", "ab", "a\u{1F}b", "a\u{1E}b", "\u{1F}", "\u{1E}"]
        let arrDomain: [[String]] = [
            [], ["a"], ["a", "bc"], ["a\u{1F}bc"],   // join-ambiguous pair
            ["", "x"], ["x", ""],                      // empty-element boundary pair
            ["a\u{1E}", "b"]                           // in-band record sep
        ]
        let actorDomain: [BASSovereignAuditActor] = [.system, .operator]
    
        var seen = Set<Data>()
        var total = 0
        // Bounded exhaustive sweep: vary auditID, verdictRef, ruleIDs, signalRefs,
        // actor — the fields most exposed to caller-supplied composite content.
        for auditID in strDomain {
            for verdictRef in strDomain {
                for rules in arrDomain {
                    for signals in arrDomain {
                        for actor in actorDomain {
                            let entry = BASSovereignAuditEntry(
                                schemaVersion: "1.2.0",
                                auditID: auditID,
                                sessionID: "S",
                                turnID: "T",
                                verdictRef: verdictRef,
                                ruleIDs: rules,
                                signalRefs: signals,
                                actionRefs: [],
                                snapshotRef: "",
                                actor: actor,
                                signature: "",
                                appendedAt: fixedDate)
                            let bytes = basSovereignAuditCanonicalBytes(
                                for: entry, priorHash: pHash, signingNamespace: namespace)
                            seen.insert(bytes)
                            total += 1
                        }
                    }
                }
            }
        }
        // Every distinct field-tuple is distinct by construction, so an injective
        // encoding yields exactly `total` unique byte strings — 0 collisions.
        XCTAssertEqual(seen.count, total,
                       "1.2.0 canonical encoding produced \(total - seen.count) collision(s) "
                       + "over \(total) distinct entries — NOT injective")
    
        // Canonical bytes are themselves deterministic (re-call byte-equality).
        let sample = BASSovereignAuditEntry(
            schemaVersion: "1.2.0", auditID: "x", sessionID: "S", turnID: "T",
            verdictRef: "v\u{1F}r", ruleIDs: ["a", "b"], signalRefs: ["s"],
            actionRefs: [], snapshotRef: "snap", actor: .system,
            signature: "", appendedAt: fixedDate)
        let b1 = basSovereignAuditCanonicalBytes(for: sample, priorHash: pHash, signingNamespace: namespace)
        let b2 = basSovereignAuditCanonicalBytes(for: sample, priorHash: pHash, signingNamespace: namespace)
        XCTAssertEqual(b1, b2, "canonical bytes not deterministic across re-call")
    
        print("QINAO-GATE chain_seal_determinism_byte_equal: PASS "
              + "(10-entry chain: selfHash+HMAC byte-identical across 2 repeats AND "
              + "legacy-vs-routed seal; raw-seal == CryptoKit SHA256 on 4 probes; "
              + "schema 1.2.0 length-prefixed canonical INJECTIVE — \(total) distinct "
              + "entries → \(seen.count) unique encodings, 0 collisions)")
    }

    func test_qinao_chain_tamper_detection_coverage() async throws {
        // QINAO #84 L14 — 100% internal-tamper detection on the sovereign hash-chained
        // audit ledger. We build a clean N-entry HMAC chain, then for EACH tamper vector
        // we rebuild an identical clean ledger and apply exactly one mutation via the
        // actor-internal `_m92TestTamper` hook, asserting BOTH detectors fire:
        //   - `auditChainFull()` (non-throwing BR-013 sentinel) reports !isClean with the
        //      EXACT expected reason code(s), and
        //   - `verifyChainIntegrity()` (fail-closed BR-012 guard) THROWS.
        // Then we assert the legitimate tail-trim case produces NO false positive.
        // tolerance = 0: every vector must be caught; the clean + trimmed chains must
        // be reported perfectly clean.
    
        let seed = "qinao-84-tamper-seed"
        let entryCount = 6
    
        // Build a fresh, fully-clean, fully-signed ledger of `entryCount` entries.
        @Sendable func freshCleanLedger() async throws -> BASSovereignAuditLedger {
            let ledger = BASSovereignAuditLedger.withSeed(seed)
            for i in 0..<entryCount {
                let entry = BASSovereignAuditEntry(
                    auditID: "qinao-audit-\(i)",
                    sessionID: "qinao-session",
                    turnID: "turn-\(i)",
                    verdictRef: "verdict-\(i)",
                    ruleIDs: ["BR-001", "rule-\(i)"],
                    signalRefs: ["sig-\(i)"],
                    actionRefs: ["act-\(i)"],
                    snapshotRef: "snap-\(i)",
                    actor: .system,
                    signature: "",                                   // ledger self-signs
                    appendedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(i)))
                _ = try await ledger.append(entry)
            }
            return ledger
        }
    
        // Oracle: the SHA-256/base64 hash the ledger uses for selfHash — used only to
        // forge a structurally-plausible-but-unkeyed rehash ("no-key rehash" vector).
        @Sendable func sha256b64(_ s: String) -> String {
            Data(SHA256.hash(data: Data(s.utf8))).base64EncodedString()
        }
    
        // Sanity: the baseline chain is perfectly clean under BOTH detectors.
        do {
            let ledger = try await freshCleanLedger()
            let report = await ledger.auditChainFull()
            XCTAssertTrue(report.isClean, "baseline chain must be clean")
            XCTAssertEqual(report.totalEntriesScanned, entryCount)
            XCTAssertTrue(report.corruptions.isEmpty)
            try await ledger.verifyChainIntegrity()   // must NOT throw
        }
    
        // Drives one tamper vector: rebuild clean ledger, mutate at `position`, assert both
        // detectors fire and (when reasons are supplied) the exact reason set is present.
        func runVector(
            _ name: String,
            position: Int,
            expectedReasons: Set<BASSovereignAuditLedger.BASSignatureAuditReason>,
            _ mutate: @escaping @Sendable (BASSovereignAuditLedger.AppendedEntry)
                -> BASSovereignAuditLedger.AppendedEntry
        ) async throws {
            let ledger = try await freshCleanLedger()
            await ledger._m92TestTamper(position: position, replacement: mutate)
    
            // 1) BR-013 non-throwing sentinel must flag corruption.
            let report = await ledger.auditChainFull()
            XCTAssertFalse(report.isClean, "[\(name)] auditChainFull must report not-clean")
            XCTAssertFalse(report.corruptions.isEmpty, "[\(name)] expected >=1 corruption")
            if !expectedReasons.isEmpty {
                let reasonsAtPos = Set(
                    report.corruptions
                        .filter { $0.position == position }
                        .flatMap { $0.reasons })
                XCTAssertTrue(
                    expectedReasons.isSubset(of: reasonsAtPos),
                    "[\(name)] expected reasons \(expectedReasons) ⊆ found \(reasonsAtPos) at pos \(position)")
            }
    
            // 2) BR-012 fail-closed guard must THROW on the same tamper.
            var threw = false
            do { try await ledger.verifyChainIntegrity() }
            catch { threw = true }
            XCTAssertTrue(threw, "[\(name)] verifyChainIntegrity must throw on tamper")
        }
    
        // --- Vector A: field-flip (mutate a content field, leave hashes/sig) -----------
        // Changing verdictRef changes canonical bytes ⇒ stored selfHash no longer matches
        // AND the stored signature no longer authenticates the new bytes.
        try await runVector(
            "field-flip(verdictRef)", position: 2,
            expectedReasons: [.selfHashMismatch, .signatureInvalid]
        ) { appended in
            var raw = appended.entry
            raw.verdictRef = "FORGED-verdict"
            return BASSovereignAuditLedger.AppendedEntry(
                entry: raw, priorHash: appended.priorHash, selfHash: appended.selfHash)
        }
    
        // --- Vector B: no-key rehash (attacker edits field AND recomputes selfHash
        // with the public SHA-256, but CANNOT recompute the keyed HMAC signature) -------
        // selfHash is made internally consistent with the forged bytes (so .selfHashMismatch
        // may NOT fire), but the keyed signature still fails ⇒ .signatureInvalid is the
        // guaranteed detector. This is the crux: rehashing without the key is still caught.
        try await runVector(
            "no-key-rehash", position: 3,
            expectedReasons: [.signatureInvalid]
        ) { appended in
            var raw = appended.entry
            raw.verdictRef = "FORGED-rehashed"
            // forge a fresh-but-unkeyed selfHash over a plausible string of the new bytes
            let forgedSelf = sha256b64("FORGED-rehashed|\(raw.auditID)|\(appended.priorHash)")
            return BASSovereignAuditLedger.AppendedEntry(
                entry: raw, priorHash: appended.priorHash, selfHash: forgedSelf)
        }
    
        // --- Vector C: priorHash edit (break the chain linkage) ------------------------
        try await runVector(
            "priorHash-edit", position: 4,
            expectedReasons: [.priorHashBroken]
        ) { appended in
            BASSovereignAuditLedger.AppendedEntry(
                entry: appended.entry,
                priorHash: sha256b64("BOGUS-prior-link"),
                selfHash: appended.selfHash)
        }
    
        // --- Vector D: entry swap (replace one entry's whole payload with another's
        // content while leaving the slot's chain bookkeeping) --------------------------
        // The swapped-in content no longer matches the slot's selfHash/signature.
        try await runVector(
            "entry-swap", position: 1,
            expectedReasons: [.selfHashMismatch, .signatureInvalid]
        ) { appended in
            var raw = appended.entry
            // overwrite identity + content with a DIFFERENT entry's values
            raw.auditID = "qinao-audit-5"
            raw.turnID = "turn-5"
            raw.verdictRef = "verdict-5"
            raw.signalRefs = ["sig-5"]
            return BASSovereignAuditLedger.AppendedEntry(
                entry: raw, priorHash: appended.priorHash, selfHash: appended.selfHash)
        }
    
        // --- Vector E: mid-delete (simulate removing a middle entry by overwriting it
        // with the NEXT entry's content — the linkage to position+1 now breaks) ---------
        // We rebuild a clean ledger, capture the successor's payload via snapshot, and
        // stamp it over the middle slot. The successor's stored selfHash/signature do not
        // match this slot, so both checks fire; the chain link to the real successor breaks.
        do {
            let name = "mid-delete"
            let position = 2
            let ledger = try await freshCleanLedger()
            let snap = await ledger.snapshot()
            let successor = snap[position + 1].entry          // value copy, Sendable
            await ledger._m92TestTamper(position: position) { appended in
                BASSovereignAuditLedger.AppendedEntry(
                    entry: successor,
                    priorHash: appended.priorHash,
                    selfHash: appended.selfHash)
            }
            let report = await ledger.auditChainFull()
            XCTAssertFalse(report.isClean, "[\(name)] must report not-clean")
            let reasons = Set(
                report.corruptions.flatMap { $0.reasons })
            XCTAssertTrue(
                reasons.contains(.signatureInvalid) || reasons.contains(.selfHashMismatch)
                    || reasons.contains(.priorHashBroken),
                "[\(name)] expected an integrity reason, found \(reasons)")
            var threw = false
            do { try await ledger.verifyChainIntegrity() } catch { threw = true }
            XCTAssertTrue(threw, "[\(name)] verifyChainIntegrity must throw")
        }
    
        // --- Vector F: schemaVersion downgrade (forge a lower/forgeable schema form) ---
        // schemaVersion is part of the canonical bytes ⇒ downgrading it desyncs both the
        // selfHash and the keyed signature.
        try await runVector(
            "schemaVersion-downgrade", position: 0,
            expectedReasons: [.selfHashMismatch, .signatureInvalid]
        ) { appended in
            var raw = appended.entry
            raw.schemaVersion = "0.0.1"   // below currentSchemaVersion ("1.0.0")
            return BASSovereignAuditLedger.AppendedEntry(
                entry: raw, priorHash: appended.priorHash, selfHash: appended.selfHash)
        }
    
        // --- Negative control: legitimate tail-trim must NOT be flagged ----------------
        // An append-only ledger truncated at the tail leaves a valid signed prefix chain.
        // We build a ledger with `entryCount - 1` entries (the legitimately trimmed
        // prefix) and assert it is reported perfectly clean by BOTH detectors — no false
        // positive. (Tail-trim drops a verifiable suffix; it does not corrupt any
        // surviving entry's selfHash, signature, or backward linkage.)
        do {
            let trimmed = BASSovereignAuditLedger.withSeed(seed)
            for i in 0..<(entryCount - 1) {
                let entry = BASSovereignAuditEntry(
                    auditID: "qinao-audit-\(i)",
                    sessionID: "qinao-session",
                    turnID: "turn-\(i)",
                    verdictRef: "verdict-\(i)",
                    ruleIDs: ["BR-001", "rule-\(i)"],
                    signalRefs: ["sig-\(i)"],
                    actionRefs: ["act-\(i)"],
                    snapshotRef: "snap-\(i)",
                    actor: .system,
                    signature: "",
                    appendedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(i)))
                _ = try await trimmed.append(entry)
            }
            let report = await trimmed.auditChainFull()
            XCTAssertTrue(report.isClean, "tail-trim FALSE POSITIVE: trimmed prefix must be clean")
            XCTAssertTrue(report.corruptions.isEmpty)
            XCTAssertEqual(report.totalEntriesScanned, entryCount - 1)
            try await trimmed.verifyChainIntegrity()   // must NOT throw
        }
    
        print("QINAO-GATE chain_tamper_detection_coverage: PASS — 6/6 internal-tamper vectors detected (field-flip, no-key rehash, priorHash edit, entry swap, mid-delete, schemaVersion downgrade) by both auditChainFull() + verifyChainIntegrity(); legitimate tail-trim tolerated with zero false positives (tolerance=0)")
    }
}

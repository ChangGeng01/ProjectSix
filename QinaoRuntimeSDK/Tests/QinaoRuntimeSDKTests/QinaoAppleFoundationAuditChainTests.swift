import XCTest
import BASRuntimeCore
import BASMemory
import BASObservability
import BASOrgan
import BASAppleAdapters
import QinaoLoop
import QinaoAppleFoundation
@testable import QinaoRuntime
@testable import QinaoSovereign

/// M183 — full audit-chain E2E: real Apple FoundationModels output
/// flows through L13 UpdateTicket and lands in the L14 audit ledger.
///
/// ## Why this exists
///
/// M177-M181 each prove a slice of the chain:
/// - M177: Apple FM real LLM through the substrate adapter contract
/// - M178: Apple FM real LLM through QinaoLoop public API
/// - M180: same via the public factory
/// - M181: error translation + concurrent safety
///
/// What was missing: a single test that walks the WHOLE path from
/// real-LLM body production → host wraps the body in a
/// `BASUpdateTicket` → runtime streams the ticket via L13 →
/// observation bundle lands in the L14 audit ledger → ledger query
/// returns it. That's the production "shadow trial → audit"
/// commitment, end-to-end with a real model on the line.
///
/// ## Gating
///
/// Same `QINAO_FM_E2E=1` + macOS 26+ as the rest of the real-LLM
/// suite. Default `swift test` skips this; local human runs with the
/// env var exercise the full chain.
final class QinaoAppleFoundationAuditChainTests: XCTestCase {

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise the audit " +
                "chain through real Apple FoundationModels")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ / " +
            "visionOS 26+; current OS does not satisfy the guard")
    }

    func testAppleFMBodyFlowsIntoUpdateTicketAndLandsInL14Ledger()
        async throws
    {
        try skipUnlessReady()

        let now: @Sendable () -> Date = {
            Date(timeIntervalSince1970: 1_700_000_000)
        }
        let fx = await QinaoTestFixture.make(now: now)

        // Step 1: real Apple FoundationModels draft via the public
        // factory (same path a host uses).
        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        let llmLoop = QinaoLoop(organEndpoint: endpoint)
        let seed = QinaoLoop.CandidateSeed(
            candidateID: "audit-c1",
            title: "Audit chain seed",
            prompt:
                "Reply with a single short sentence about " +
                "habit-building.",
            role: .scout,
            expectedBenefit: 0.7,
            expectedCost: 0.2,
            reversibility: 0.9,
            confidence: 0.8)
        let drafts = try await llmLoop.generateCandidates(
            sessionID: "audit-llm.1",
            seeds: [seed])
        XCTAssertEqual(drafts.count, 1)
        let draft = drafts[0]
        XCTAssertEqual(
            draft.providerID,
            "apple.foundation-models.v1",
            "draft must come from the real on-device model")
        XCTAssertFalse(
            draft.body
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
            "real LLM body must be non-empty before we wrap " +
            "it into a ticket")

        // Step 2: host wraps the LLM body into a shadow-trial
        // UpdateTicket. The ticketID + summary travel into L13;
        // the L14 audit ledger captures the bundle.
        let ticketID = "ticket.audit.\(UUID().uuidString.prefix(8))"
        let auditTicket = BASUpdateTicket(
            ticketID: ticketID,
            sessionRef: "sess.audit.1",
            summary: draft.body,
            memoryWriteSuggestion:
                "shadow-trial of Apple FM scout draft",
            confidence: 0.7)

        // Step 3: drive a turn through the runtime's full audit path
        // (sendSession) with the ticket attached. Sovereign records
        // the L13 observation bundle into the audit ledger.
        let observations = QinaoSovereignControlPlane
            .TurnObservations(
                sessionID: "sess.audit.1",
                turnID: "turn.audit.1",
                snapshotRef: "snap.audit.1",
                policyHash: "policy.audit.1")
        _ = try await fx.runtime.sendSession(
            observations,
            coordinatorSeverity: .pass,
            updateTickets: [auditTicket])

        // Step 4: the audit ledger now holds an observation bundle
        // for this (session, turn). Query it.
        let bundle = await fx.sovereign.observationBundle(
            sessionID: "sess.audit.1",
            turnID: "turn.audit.1")
        XCTAssertNotNil(
            bundle,
            "audit ledger must have a bundle recorded for this turn")

        // Step 5: the bundle MUST include an L13 (evolutionFurnace)
        // entry — proves the real-LLM-derived ticket flowed all the
        // way from sendSession's input to the L14 audit ledger.
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertTrue(
            layers.contains(.evolutionFurnace),
            "bundle must contain L13 (evolutionFurnace) — the " +
            "audit chain commitment is broken if the ticket " +
            "didn't make it. Got layers: \(layers)")
        XCTAssertTrue(
            layers.contains(.sovereign),
            "L14 (sovereign) is always present — its absence " +
            "would mean no audit ran at all")

        // Step 6: locate the L13 summary and assert its layerCode
        // is "L13" (catches a future enum/raw-value drift).
        guard
            let l13 = bundle?.summaries
                .first(where: { $0.layer == .evolutionFurnace })
        else {
            XCTFail("no L13 summary in bundle")
            return
        }
        XCTAssertEqual(l13.layer.rawValue, "L13")
    }

    func testRealLLMTraceIDIsRecoverableFromGeneratedCandidate()
        async throws
    {
        try skipUnlessReady()

        // Smaller variant: prove that the GeneratedCandidate carries
        // a non-empty traceID that hosts can persist for
        // post-incident audit (e.g. "which model output produced
        // this ticket?"). The trace is opaque to the loop but stable
        // across the BASOrganDraft → QinaoLoop.OrganResponse →
        // GeneratedCandidate translation chain.
        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)
        let seed = QinaoLoop.CandidateSeed(
            candidateID: "trace-c1",
            title: "Trace test",
            prompt: "Reply in three words.",
            role: .scout,
            expectedBenefit: 0.5,
            expectedCost: 0.1,
            reversibility: 0.9,
            confidence: 0.5)

        let result = try await loop.generateCandidates(
            sessionID: "trace.1", seeds: [seed])
        XCTAssertEqual(result.count, 1)
        let candidate = result[0]
        XCTAssertFalse(
            candidate.traceID.isEmpty,
            "every real-LLM-backed candidate MUST carry a " +
            "non-empty traceID — hosts persist this for " +
            "post-incident audit")
        // Apple FM's traceID format is a SHA256 hex digest of
        // (providerID + role + preset + instruction + context).
        // The exact format is provider-internal, but length must
        // be non-zero and stable.
        XCTAssertGreaterThan(
            candidate.traceID.count, 0,
            "traceID grammar drift would break audit reconstruction")
    }
}

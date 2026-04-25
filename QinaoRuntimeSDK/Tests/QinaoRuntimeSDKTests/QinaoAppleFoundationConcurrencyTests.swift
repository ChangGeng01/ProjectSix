import XCTest
import BASOrgan
import BASAppleAdapters
import QinaoLoop
import QinaoAppleFoundation

/// M181 — concurrent Apple FoundationModels invocations through
/// the Qinao public API.
///
/// ## What this proves
///
/// `QinaoLoop.generateCandidates` runs seeds *sequentially* within a
/// session — that's by design (frontier scoring depends on each
/// `body` landing before the next is dispatched). This suite proves
/// **across-session** concurrency is safe: two parallel sessions
/// running on independent `QinaoLoop` actors with the same
/// underlying `QinaoAppleFoundationEndpoint` both reach Apple FM,
/// both produce real bodies, and the actor isolation of the
/// adapter / registry doesn't deadlock or cross-talk.
///
/// ## Gating
///
/// Same `QINAO_FM_E2E=1` + macOS 26+ availability as M177/M178/M180.
/// CI default skips the suite to keep `swift test` fast and offline.
final class QinaoAppleFoundationConcurrencyTests: XCTestCase {

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise concurrent " +
                "Apple FoundationModels invocations")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ / " +
            "visionOS 26+; current OS does not satisfy the guard")
    }

    private func makeSeed(
        _ id: String,
        _ prompt: String,
        role: QinaoLoop.OrganRole = .scout
    ) -> QinaoLoop.CandidateSeed {
        QinaoLoop.CandidateSeed(
            candidateID: id,
            title: id,
            prompt: prompt,
            role: role,
            expectedBenefit: 0.7,
            expectedCost: 0.2,
            reversibility: 0.9,
            confidence: 0.8)
    }

    // MARK: - 1. Two sessions in parallel — both reach Apple FM

    func testTwoConcurrentSessionsBothReachAppleFM() async throws {
        try skipUnlessReady()

        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        // Two independent `QinaoLoop` actors sharing the same
        // endpoint — represents two host-side conversations
        // running side-by-side.
        let loopA = QinaoLoop(organEndpoint: endpoint)
        let loopB = QinaoLoop(organEndpoint: endpoint)

        // Construct seeds before the async let to avoid Swift 6
        // strict-concurrency `self` capture warnings — `makeSeed` is
        // an instance method.
        let seedA = makeSeed("a1", "Reply with one word.")
        let seedB = makeSeed("b1", "Reply with one word.")

        async let resultA = loopA.generateCandidates(
            sessionID: "concurrent.A", seeds: [seedA])
        async let resultB = loopB.generateCandidates(
            sessionID: "concurrent.B", seeds: [seedB])

        let (a, b) = try await (resultA, resultB)

        XCTAssertEqual(a.count, 1)
        XCTAssertEqual(b.count, 1)
        XCTAssertEqual(
            a.first?.providerID, "apple.foundation-models.v1")
        XCTAssertEqual(
            b.first?.providerID, "apple.foundation-models.v1")
        XCTAssertFalse(
            (a.first?.body ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty)
        XCTAssertFalse(
            (b.first?.body ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty)
    }

    // MARK: - 2. Five concurrent direct adapter calls

    /// Apple FM adapter is itself an `actor`, so concurrent
    /// `draft(_:)` calls serialize internally. This test confirms 5
    /// in-flight calls all complete without crash, with consistent
    /// providerID and non-empty bodies — proving the adapter's
    /// internal session per-request pattern doesn't leak state
    /// across concurrent callers.
    func testFiveConcurrentAdapterCallsAllComplete() async throws {
        try skipUnlessReady()

        let adapter = AppleFoundationOrganAdapter()

        await withThrowingTaskGroup(
            of: BASOrganDraft.self
        ) { group in
            for i in 0..<5 {
                let request = BASOrganRequest(
                    requestID: "concurrent-\(i)",
                    role: .scout,
                    preset: .scout,
                    instruction: "Reply with one short word.")
                group.addTask {
                    try await adapter.draft(request)
                }
            }

            var collected: [BASOrganDraft] = []
            do {
                for try await draft in group {
                    collected.append(draft)
                }
            } catch {
                XCTFail(
                    "concurrent adapter call threw: \(error)")
                return
            }

            XCTAssertEqual(collected.count, 5)
            for draft in collected {
                XCTAssertEqual(
                    draft.providerID,
                    "apple.foundation-models.v1")
                XCTAssertFalse(
                    draft.body
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines)
                        .isEmpty)
            }

            // Each request should have its own requestID echoed
            // back — proves no cross-contamination.
            let returnedIDs = Set(collected.map(\.requestID))
            XCTAssertEqual(
                returnedIDs.count, 5,
                "each concurrent call must round-trip its " +
                "requestID; got \(returnedIDs)")
        }
    }
}

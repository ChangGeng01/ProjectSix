import XCTest
@testable import QinaoDefaults
@testable import QinaoLoop
import QinaoSeats
import QinaoUI

/// M294 — convenience-factory contract tests.
///
/// Doctrine pinned:
/// - `makeStandard(endpoint:)` returns a (loop, registry) pair
///   with all four standard seats registered
/// - `standardShowcase()` returns the canonical 6-surface bundle
final class QinaoDefaultsTests: XCTestCase {

    /// Spy endpoint just to satisfy the loop wiring; never called
    /// in these tests.
    actor InertEndpoint: QinaoOrganEndpoint {
        func produceBody(
            prompt: String,
            context: [String],
            role: QinaoLoop.OrganRole,
            sessionID: String
        ) async throws -> QinaoLoop.OrganResponse {
            QinaoLoop.OrganResponse(
                body: "",
                providerID: "inert",
                traceID: "trace")
        }
    }

    func test_makeStandardReturnsLoopAndRegistry() async throws {
        let (loop, registry) = try await QinaoDefaults
            .makeStandard(endpoint: InertEndpoint())
        XCTAssertNotNil(loop)
        let registered = await registry.registeredSeats()
        // M292.6a expanded standardLoopSeats from 4 to 6.
        XCTAssertEqual(
            registered,
            [
                .critic, .planner, .risk, .scout,
                .sovereignSentinel, .surface,
            ])
    }

    func test_standardShowcaseReturnsSixSurfaces() {
        let m = QinaoDefaults.standardShowcase()
        XCTAssertEqual(m.componentIDs.count, 6)
        XCTAssertEqual(
            m.componentIDs.first?.rawValue, "compare-panel")
        XCTAssertEqual(
            m.componentIDs.last?.rawValue, "local-only-sheet")
    }

    func test_makeStandardLoopHasSeededVault() async throws {
        // Indirect proof the vault was seeded: refining
        // counterfactuals against `tmpl-body-hydration`
        // (a built-in template) must succeed without
        // 'unknown-template' error.
        let (loop, _) = try await QinaoDefaults
            .makeStandard(endpoint: InertEndpoint())
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                QinaoLoop.CandidateInput(
                    candidateID: "c1",
                    title: "t",
                    actionSummary: "summary",
                    expectedBenefit: 0.5,
                    expectedCost: 0.2,
                    reversibility: 0.5,
                    confidence: 0.5),
            ])
        // Should not throw 'unknown-template' — vault is seeded.
        _ = try await loop.refineAgainstCounterfactuals(
            sessionID: "s1",
            templateID: "tmpl-body-hydration")
    }
}

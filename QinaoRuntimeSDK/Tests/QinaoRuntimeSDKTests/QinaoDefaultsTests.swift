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

    // MARK: - M312: makeStandardWithAdapters wires all 9 seats

    /// M312 — `makeStandardWithAdapters(endpoint:)` returns a
    /// registry covering exactly the manifesto v2 第八节 9-seat
    /// council. Pre-M312 hosts wanting all 9 had to compose
    /// `standardLoopSeats(loop:)` (M294) + `adapterBoundSeats(
    /// loop:)` (M292.6d) by hand.
    func test_makeStandardWithAdaptersRegistersAllNineSeats()
        async throws
    {
        let (loop, registry) = try await QinaoDefaults
            .makeStandardWithAdapters(
                endpoint: InertEndpoint())
        XCTAssertNotNil(loop)
        let registered = await registry.registeredSeats()
        XCTAssertEqual(
            registered.count, 9,
            "manifesto v2 第八节 — exactly 9 seats")
        XCTAssertEqual(
            Set(registered), Set(QinaoSeat.allCases),
            "every QinaoSeat case must be registered")
    }

    /// M312 — backward-compat: existing `makeStandard(endpoint:)`
    /// keeps the 6-seat shape so M294 callers don't break.
    func test_makeStandardStillReturnsSixSeatsAfterM312()
        async throws
    {
        let (_, registry) = try await QinaoDefaults
            .makeStandard(endpoint: InertEndpoint())
        let registered = await registry.registeredSeats()
        XCTAssertEqual(
            registered.count, 6,
            "M294 makeStandard contract — 6 seats")
    }

    /// M312 — the 9-seat council is the 6-seat council
    /// (`makeStandard`) plus the 3 adapter-bound seats. Pin the
    /// disjoint cover so a future regression that drops a seat
    /// from either factory surfaces here.
    func test_makeStandardWithAdaptersAddsExactlyThreeOverM294()
        async throws
    {
        let (_, six) = try await QinaoDefaults
            .makeStandard(endpoint: InertEndpoint())
        let (_, nine) = try await QinaoDefaults
            .makeStandardWithAdapters(
                endpoint: InertEndpoint())
        let sixSet = Set(await six.registeredSeats())
        let nineSet = Set(await nine.registeredSeats())
        let added = nineSet.subtracting(sixSet)
        XCTAssertEqual(
            added,
            Set([.memory, .hostAlignment, .evolutionShadow]),
            "9-seat council = 6-seat council ∪ {memory, " +
            "hostAlignment, evolutionShadow}")
    }

    /// M312 — vault is seeded same as `makeStandard`. Pin via
    /// the same `tmpl-body-hydration` smoke check so the M294
    /// vault contract is preserved.
    func test_makeStandardWithAdaptersLoopHasSeededVault()
        async throws
    {
        let (loop, _) = try await QinaoDefaults
            .makeStandardWithAdapters(
                endpoint: InertEndpoint())
        try await loop.submit(
            sessionID: "s-m312",
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
        // Must not throw — vault has the built-in template.
        _ = try await loop.refineAgainstCounterfactuals(
            sessionID: "s-m312",
            templateID: "tmpl-body-hydration")
    }

    /// M312 — calling the factory twice produces independent
    /// (loop, registry) pairs, each with all 9 seats. No leakage
    /// between instances.
    func test_makeStandardWithAdaptersIsIndependentAcrossCalls()
        async throws
    {
        let (l1, r1) = try await QinaoDefaults
            .makeStandardWithAdapters(
                endpoint: InertEndpoint())
        let (l2, r2) = try await QinaoDefaults
            .makeStandardWithAdapters(
                endpoint: InertEndpoint())
        let s1 = await r1.registeredSeats()
        let s2 = await r2.registeredSeats()
        XCTAssertEqual(s1.count, 9)
        XCTAssertEqual(s2.count, 9)
        XCTAssertEqual(s1, s2,
                       "register order is deterministic " +
                       "across calls")
        // loops are distinct actor instances.
        XCTAssertFalse(l1 === l2)
    }
}

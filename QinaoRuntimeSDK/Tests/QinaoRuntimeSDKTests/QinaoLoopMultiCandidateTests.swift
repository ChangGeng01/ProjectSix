import XCTest
@testable import QinaoLoop

/// M100 — `QinaoLoop.generateCandidates(sessionID:seeds:variantsPerSeed:)`
/// variant-expansion contract tests.
///
/// Plan l2-silly-piglet §T6 wants dream-loop to produce ≥2
/// candidates per turn by default. M100 adds an opt-in overload
/// that expands seeds into N variants per seed — the caller passes
/// `variantsPerSeed: 2` (or more) and the loop takes care of ID
/// disambiguation and N-times endpoint invocation. `variantsPerSeed
/// == 1` delegates to the existing non-variant path for zero-diff.
///
/// Covered contracts:
///
/// 1. `variantsPerSeed == 1` delegates unchanged (byte-for-byte
///    parity with non-variant path)
/// 2. `variantsPerSeed == N >= 2` produces exactly N candidates
///    per seed with disambiguated IDs
/// 3. Expanded IDs follow the spec: variant 1 keeps original,
///    variants 2..N use `"<seedID>#variant-<i>"`
/// 4. Endpoint is called exactly N * seeds.count times
/// 5. `variantsPerSeed < 1` throws `.invalidCandidate` with a
///    stable reason code before any endpoint call
final class QinaoLoopMultiCandidateTests: XCTestCase {

    // MARK: - Spy endpoint

    actor SpyEndpoint: QinaoOrganEndpoint {
        struct Call: Sendable, Equatable {
            let prompt: String
            let sessionID: String
        }
        private(set) var callCount = 0
        private(set) var calls: [Call] = []

        func produceBody(
            prompt: String,
            context: [String],
            role: QinaoLoop.OrganRole,
            sessionID: String
        ) async throws -> QinaoLoop.OrganResponse {
            callCount += 1
            calls.append(Call(
                prompt: prompt, sessionID: sessionID))
            return QinaoLoop.OrganResponse(
                body: "response-\(callCount)",
                providerID: "spy.m100",
                traceID: "trace-\(callCount)")
        }

        func snapshot() -> [Call] { calls }
        func observedCallCount() -> Int { callCount }
    }

    private func makeSeed(
        id: String, prompt: String = "p"
    ) -> QinaoLoop.CandidateSeed {
        QinaoLoop.CandidateSeed(
            candidateID: id,
            title: "t",
            prompt: prompt,
            context: [],
            role: .core,
            expectedBenefit: 0.5,
            expectedCost: 0.1,
            reversibility: 0.9,
            confidence: 0.5)
    }

    // MARK: - 1. variantsPerSeed == 1 delegates unchanged

    func testVariantsOneDelegatesWithoutIDMangling() async throws {
        let spy = SpyEndpoint()
        let loop = QinaoLoop(organEndpoint: spy)
        let seeds = [
            makeSeed(id: "alpha"),
            makeSeed(id: "beta"),
        ]

        let generated = try await loop.generateCandidates(
            sessionID: "sess.m100.one",
            seeds: seeds,
            variantsPerSeed: 1)

        XCTAssertEqual(generated.count, 2,
            "1 variant per seed = 1 candidate per seed")
        let callCount = await spy.observedCallCount()
        XCTAssertEqual(callCount, 2,
            "endpoint called 2 seeds × 1 variant = 2 calls")
        let ids = Set(generated.map(\.candidateID))
        XCTAssertEqual(ids, Set(["alpha", "beta"]),
            "IDs unchanged when variantsPerSeed == 1")
    }

    // MARK: - 2. variantsPerSeed == 2 fans out each seed

    func testVariantsTwoProducesTwoPerSeed() async throws {
        let spy = SpyEndpoint()
        let loop = QinaoLoop(organEndpoint: spy)
        let seeds = [makeSeed(id: "alpha")]

        let generated = try await loop.generateCandidates(
            sessionID: "sess.m100.two",
            seeds: seeds,
            variantsPerSeed: 2)

        XCTAssertEqual(generated.count, 2,
            "2 variants per 1 seed = 2 candidates")
        let callCount = await spy.observedCallCount()
        XCTAssertEqual(callCount, 2,
            "endpoint called 1 seed × 2 variants = 2 calls")
        let ids = Set(generated.map(\.candidateID))
        XCTAssertEqual(
            ids,
            Set(["alpha", "alpha#variant-2"]),
            "variant 1 keeps original ID, variant 2 suffixes")
    }

    // MARK: - 3. variantsPerSeed == 3 with two seeds = 6

    func testVariantsThreeTwoSeedsProducesSixCandidates()
        async throws {
        let spy = SpyEndpoint()
        let loop = QinaoLoop(organEndpoint: spy)
        let seeds = [
            makeSeed(id: "alpha"),
            makeSeed(id: "beta"),
        ]

        let generated = try await loop.generateCandidates(
            sessionID: "sess.m100.three",
            seeds: seeds,
            variantsPerSeed: 3)

        XCTAssertEqual(generated.count, 6,
            "2 seeds × 3 variants = 6 candidates")
        let callCount = await spy.observedCallCount()
        XCTAssertEqual(callCount, 6,
            "endpoint called 2 seeds × 3 variants = 6 calls")
        let ids = Set(generated.map(\.candidateID))
        XCTAssertEqual(
            ids,
            Set([
                "alpha", "alpha#variant-2", "alpha#variant-3",
                "beta", "beta#variant-2", "beta#variant-3"
            ]),
            "variant 1 keeps each seed's ID, variants 2..N suffix")
    }

    // MARK: - 4. variantsPerSeed < 1 fails fast

    func testVariantsZeroThrowsBeforeAnyEndpointCall() async {
        let spy = SpyEndpoint()
        let loop = QinaoLoop(organEndpoint: spy)
        let seeds = [makeSeed(id: "alpha")]

        do {
            _ = try await loop.generateCandidates(
                sessionID: "sess.m100.zero",
                seeds: seeds,
                variantsPerSeed: 0)
            XCTFail("expected invalidCandidate throw")
        } catch QinaoLoop.LoopError.invalidCandidate(let reason) {
            XCTAssertTrue(
                reason.hasPrefix("variants-per-seed-out-of-range:"),
                "reason prefix is stable: got \(reason)")
        } catch {
            XCTFail("unexpected: \(error)")
        }

        let callCount = await spy.observedCallCount()
        XCTAssertEqual(
            callCount, 0,
            "endpoint never called on validation failure")
    }

    func testVariantsNegativeThrowsBeforeAnyEndpointCall()
        async {
        let spy = SpyEndpoint()
        let loop = QinaoLoop(organEndpoint: spy)
        let seeds = [makeSeed(id: "alpha")]

        do {
            _ = try await loop.generateCandidates(
                sessionID: "sess.m100.neg",
                seeds: seeds,
                variantsPerSeed: -5)
            XCTFail("expected invalidCandidate throw")
        } catch QinaoLoop.LoopError.invalidCandidate {
            // expected
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }
}

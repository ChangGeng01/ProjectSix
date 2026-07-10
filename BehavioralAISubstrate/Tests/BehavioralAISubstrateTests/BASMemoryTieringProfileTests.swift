import XCTest
@testable import BASMemory

final class BASMemoryTieringProfileTests: XCTestCase {
    // MARK: - Profile construction & clamping

    func testProfileClampsAllFourSignalsIntoUnitRange() {
        let profile = BASMemoryTieringProfile(
            atomID: "atom-1",
            currentTier: .warm,
            recencyScore: 2.5,              // over 1.0
            accessFrequency: -0.4,          // below 0.0
            sensitivityDrift: 1.7,          // over 1.0
            worldContextStaleness: -99.0,   // far below 0.0
            observedAt: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(profile.recencyScore, 1.0)
        XCTAssertEqual(profile.accessFrequency, 0.0)
        XCTAssertEqual(profile.sensitivityDrift, 1.0)
        XCTAssertEqual(profile.worldContextStaleness, 0.0)
    }

    func testCompositeHeatIsWeightedBlend() {
        let profile = BASMemoryTieringProfile(
            atomID: "atom-2",
            currentTier: .warm,
            recencyScore: 1.0,
            accessFrequency: 1.0,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.0,
            observedAt: Date())

        // 0.55 * 1.0 + 0.35 * 1.0 - 0.10 * 0.0 = 0.90
        XCTAssertEqual(profile.compositeHeat, 0.90, accuracy: 1e-9)
    }

    func testCompositeHeatPenalizesStaleWorldContext() {
        let fresh = BASMemoryTieringProfile(
            atomID: "fresh",
            currentTier: .warm,
            recencyScore: 0.8,
            accessFrequency: 0.6,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.0,
            observedAt: Date())
        let stale = BASMemoryTieringProfile(
            atomID: "stale",
            currentTier: .warm,
            recencyScore: 0.8,
            accessFrequency: 0.6,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.5,
            observedAt: Date())

        XCTAssertGreaterThan(fresh.compositeHeat, stale.compositeHeat)
    }

    // MARK: - Policy: hold / promote / demote

    func testWarmAtomHeldWhenCompositeHeatInsideBand() {
        let profile = BASMemoryTieringProfile(
            atomID: "warm-hold",
            currentTier: .warm,
            recencyScore: 0.6,
            accessFrequency: 0.5,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.0,
            observedAt: Date())

        let decision = BASMemoryTemperaturePolicy
            .recommendTransition(for: profile)
        XCTAssertEqual(
            decision,
            .hold(tier: .warm, reason: .withinThresholds))
    }

    func testColdAtomPromotedWhenHeatCrossesLowerBand() {
        let profile = BASMemoryTieringProfile(
            atomID: "cold-promote",
            currentTier: .cold,
            recencyScore: 0.8,
            accessFrequency: 0.3,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.0,
            observedAt: Date())

        XCTAssertEqual(
            BASMemoryTemperaturePolicy.recommendTransition(for: profile),
            .promote(
                from: .cold,
                to: .warm,
                // blindspot MED id31: cold → warm crosses the LOWER band
                // (heat ≥ warmLowerBand), so the audit reason must name
                // the lower band, not the upper.
                reason: .compositeHeatAboveLowerBand))
    }

    func testWarmAtomPromotedWhenHeatCrossesUpperBand() {
        let profile = BASMemoryTieringProfile(
            atomID: "warm-promote",
            currentTier: .warm,
            recencyScore: 1.0,
            accessFrequency: 1.0,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.0,
            observedAt: Date())

        XCTAssertEqual(
            BASMemoryTemperaturePolicy.recommendTransition(for: profile),
            .promote(
                from: .warm,
                to: .hot,
                reason: .compositeHeatAboveUpperBand))
    }

    func testHotAtomDemotedWhenHeatDropsBelowLowerBand() {
        let profile = BASMemoryTieringProfile(
            atomID: "hot-demote",
            currentTier: .hot,
            recencyScore: 0.2,
            accessFrequency: 0.1,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.0,
            observedAt: Date())

        XCTAssertEqual(
            BASMemoryTemperaturePolicy.recommendTransition(for: profile),
            .demote(
                from: .hot,
                to: .warm,
                reason: .compositeHeatBelowLowerBand))
    }

    func testWarmAtomDemotedWhenHeatDropsBelowLowerBand() {
        let profile = BASMemoryTieringProfile(
            atomID: "warm-demote",
            currentTier: .warm,
            recencyScore: 0.1,
            accessFrequency: 0.1,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.0,
            observedAt: Date())

        XCTAssertEqual(
            BASMemoryTemperaturePolicy.recommendTransition(for: profile),
            .demote(
                from: .warm,
                to: .cold,
                reason: .compositeHeatBelowLowerBand))
    }

    // MARK: - Policy: quarantine short-circuits

    func testSensitivityEscalationRoutesToQuarantineRegardlessOfTier() {
        for tier in [BASMemoryTier.hot, .warm, .cold] {
            let profile = BASMemoryTieringProfile(
                atomID: "sensitive-\(tier.rawValue)",
                currentTier: tier,
                recencyScore: 1.0,
                accessFrequency: 1.0,
                sensitivityDrift: 0.9, // above threshold 0.75
                worldContextStaleness: 0.0,
                observedAt: Date())
            XCTAssertEqual(
                BASMemoryTemperaturePolicy.recommendTransition(for: profile),
                .quarantineSuggest(
                    from: tier, reason: .sensitivityEscalated),
                "tier=\(tier)")
        }
    }

    func testWorldContaminationRoutesToQuarantineBeforeTierLadder() {
        let profile = BASMemoryTieringProfile(
            atomID: "contaminated",
            currentTier: .warm,
            recencyScore: 0.9,
            accessFrequency: 0.9,
            sensitivityDrift: 0.2,
            worldContextStaleness: 0.8, // above threshold 0.75
            observedAt: Date())

        XCTAssertEqual(
            BASMemoryTemperaturePolicy.recommendTransition(for: profile),
            .quarantineSuggest(
                from: .warm, reason: .worldContextContaminated))
    }

    func testSensitivityEscalationWinsOverWorldContamination() {
        // Both thresholds crossed → sensitivity must win because it's
        // evaluated first. This protects host privacy even when the
        // world layer is also drifting.
        let profile = BASMemoryTieringProfile(
            atomID: "double-drift",
            currentTier: .warm,
            recencyScore: 0.5,
            accessFrequency: 0.5,
            sensitivityDrift: 0.9,
            worldContextStaleness: 0.9,
            observedAt: Date())

        XCTAssertEqual(
            BASMemoryTemperaturePolicy.recommendTransition(for: profile),
            .quarantineSuggest(
                from: .warm, reason: .sensitivityEscalated))
    }

    // MARK: - Policy: eviction

    func testColdUnusedAtomSuggestsEviction() {
        let profile = BASMemoryTieringProfile(
            atomID: "unused",
            currentTier: .cold,
            recencyScore: 0.0,
            accessFrequency: 0.0,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.0,
            observedAt: Date())

        XCTAssertEqual(
            BASMemoryTemperaturePolicy.recommendTransition(for: profile),
            .evictSuggest(from: .cold, reason: .coldStaleUnused))
    }

    func testColdAtomWithStaleWorldContextSuggestsEviction() {
        // Recency non-zero so the coldStaleUnused rule does not fire;
        // staleness must sit between evictStalenessThreshold (0.50)
        // and quarantineContaminationThreshold (0.75) so the eviction
        // branch fires rather than the quarantine branch.
        let profile = BASMemoryTieringProfile(
            atomID: "stale-cold",
            currentTier: .cold,
            recencyScore: 0.1,
            accessFrequency: 0.0,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.60,
            observedAt: Date())

        XCTAssertEqual(
            BASMemoryTemperaturePolicy.recommendTransition(for: profile),
            .evictSuggest(
                from: .cold, reason: .worldContextStaleAndCold))
    }

    func testColdAtomWithMildStalenessIsHeldNotEvicted() {
        let profile = BASMemoryTieringProfile(
            atomID: "mild-cold",
            currentTier: .cold,
            recencyScore: 0.1,
            accessFrequency: 0.05,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.2,
            observedAt: Date())

        XCTAssertEqual(
            BASMemoryTemperaturePolicy.recommendTransition(for: profile),
            .hold(tier: .cold, reason: .withinThresholds))
    }

    // MARK: - Audit log actor

    func testTransitionLogAppendsAndSnapshots() async {
        let log = BASMemoryTierTransitionLog(
            capacity: 8,
            clock: { Date(timeIntervalSince1970: 42) })

        let profileA = BASMemoryTieringProfile(
            atomID: "a",
            currentTier: .warm,
            recencyScore: 0.5,
            accessFrequency: 0.5,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.0,
            observedAt: Date())
        let profileB = BASMemoryTieringProfile(
            atomID: "b",
            currentTier: .cold,
            recencyScore: 0.0,
            accessFrequency: 0.0,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.0,
            observedAt: Date())

        _ = await log.record(
            profile: profileA,
            transition: .hold(tier: .warm, reason: .withinThresholds))
        _ = await log.record(
            profile: profileB,
            transition: .evictSuggest(
                from: .cold, reason: .coldStaleUnused))

        let snapshot = await log.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot[0].profile.atomID, "a")
        XCTAssertEqual(snapshot[1].profile.atomID, "b")
        XCTAssertEqual(
            snapshot[0].recordedAt,
            Date(timeIntervalSince1970: 42))
    }

    func testTransitionLogCapsAtConfiguredCapacity() async {
        let log = BASMemoryTierTransitionLog(capacity: 3)
        let profile = BASMemoryTieringProfile(
            atomID: "x",
            currentTier: .warm,
            recencyScore: 0.5,
            accessFrequency: 0.5,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.0,
            observedAt: Date())

        for _ in 0..<7 {
            _ = await log.record(
                profile: profile,
                transition: .hold(
                    tier: .warm, reason: .withinThresholds))
        }

        let count = await log.count()
        XCTAssertEqual(count, 3)
    }

    func testTransitionLogClearEmptiesBuffer() async {
        let log = BASMemoryTierTransitionLog(capacity: 4)
        let profile = BASMemoryTieringProfile(
            atomID: "y",
            currentTier: .warm,
            recencyScore: 0.5,
            accessFrequency: 0.5,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.0,
            observedAt: Date())
        _ = await log.record(
            profile: profile,
            transition: .hold(tier: .warm, reason: .withinThresholds))
        await log.clear()
        let snapshot = await log.snapshot()
        XCTAssertTrue(snapshot.isEmpty)
    }

    // MARK: - Codable round-trip

    func testProfileAndTransitionAreCodable() throws {
        let profile = BASMemoryTieringProfile(
            atomID: "codable",
            currentTier: .hot,
            recencyScore: 0.6,
            accessFrequency: 0.4,
            sensitivityDrift: 0.1,
            worldContextStaleness: 0.2,
            observedAt: Date(timeIntervalSince1970: 1_000))

        let transition: BASMemoryTierTransition = .promote(
            from: .warm,
            to: .hot,
            reason: .compositeHeatAboveUpperBand)

        let enc = JSONEncoder()
        let dec = JSONDecoder()
        let profileData = try enc.encode(profile)
        let transitionData = try enc.encode(transition)

        let profileRT = try dec.decode(
            BASMemoryTieringProfile.self, from: profileData)
        let transitionRT = try dec.decode(
            BASMemoryTierTransition.self, from: transitionData)

        XCTAssertEqual(profileRT, profile)
        XCTAssertEqual(transitionRT, transition)
    }
}

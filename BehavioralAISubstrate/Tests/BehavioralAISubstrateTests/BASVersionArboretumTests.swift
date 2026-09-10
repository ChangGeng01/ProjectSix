import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

/// M94 — Unit tests for `BASVersionArboretum` schema + query
/// surface.
///
/// Coverage:
/// 1. Enum / struct defaults + init trimming
/// 2. Codable round-trip (enum + delta + arboretum)
/// 3. appending returns new arboretum without mutating original
/// 4. deltas(targeting:) / children(of:) / deltas(ofKind:)
/// 5. ancestors(of:) walks back to root, handles cycles
/// 6. reversibleRollbackPath stops at first non-reversible
/// 7. knownVersionRefs includes both before + after refs
/// 8. rootVersionRefs returns .candidateAdmitted entries
final class BASVersionArboretumTests: XCTestCase {

    // MARK: - Helpers

    private func makeDelta(
        deltaID: String,
        beforeRef: String? = nil,
        afterRef: String,
        kind: BASArboretumDeltaKind = .candidateAdmitted,
        reasonCodes: [String] = [],
        authorRef: String = "test",
        reversible: Bool = true,
        appendedAt: Date = Date(timeIntervalSince1970: 1)
    ) -> BASArboretumDelta {
        BASArboretumDelta(
            deltaID: deltaID,
            beforeRef: beforeRef,
            afterRef: afterRef,
            kind: kind,
            reasonCodes: reasonCodes,
            authorRef: authorRef,
            reversible: reversible,
            appendedAt: appendedAt)
    }

    // MARK: - 1. Enum raw values stable

    func testExecutionStateRawValuesAreStable() {
        // Stable raw values are the cross-layer contract — any
        // change is a breaking API change.
        XCTAssertEqual(
            BASArboretumDeltaKind.candidateAdmitted.rawValue,
            "candidate-admitted")
        XCTAssertEqual(
            BASArboretumDeltaKind.candidatePromoted.rawValue,
            "candidate-promoted")
        XCTAssertEqual(
            BASArboretumDeltaKind.trialObservation.rawValue,
            "trial-observation")
        XCTAssertEqual(
            BASArboretumDeltaKind.rollbackApplied.rawValue,
            "rollback-applied")
        XCTAssertEqual(
            BASArboretumDeltaKind.retractionQueued.rawValue,
            "retraction-queued")
        XCTAssertEqual(
            BASArboretumDeltaKind.retractionCompleted.rawValue,
            "retraction-completed")
        XCTAssertEqual(
            BASArboretumDeltaKind.versionFrozen.rawValue,
            "version-frozen")
        XCTAssertEqual(
            BASArboretumDeltaKind.versionThawed.rawValue,
            "version-thawed")
    }

    // MARK: - 2. Init trims whitespace

    func testDeltaInitTrimsWhitespace() {
        let d = BASArboretumDelta(
            deltaID: "  delta-1  ",
            beforeRef: "  v0  ",
            afterRef: "  v1  ",
            kind: .candidateAdmitted,
            authorRef: "  sovereign  ",
            reversible: true,
            appendedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(d.deltaID, "delta-1")
        XCTAssertEqual(d.beforeRef, "v0")
        XCTAssertEqual(d.afterRef, "v1")
        XCTAssertEqual(d.authorRef, "sovereign")
    }

    func testArboretumInitTrimsID() {
        let a = BASVersionArboretum(arboretumID: "  arb-1  ")
        XCTAssertEqual(a.arboretumID, "arb-1")
    }

    // MARK: - 3. Codable round-trip

    func testCodableRoundTripPreservesAllFields() throws {
        let original = BASVersionArboretum(
            arboretumID: "arb-rt",
            deltas: [
                makeDelta(
                    deltaID: "d1", afterRef: "v1",
                    kind: .candidateAdmitted,
                    reasonCodes: ["new-fork"],
                    authorRef: "coordinator",
                    reversible: true),
                makeDelta(
                    deltaID: "d2", beforeRef: "v1", afterRef: "v2",
                    kind: .candidatePromoted,
                    reasonCodes: ["host-approved"],
                    authorRef: "sovereign",
                    reversible: false),
            ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASVersionArboretum.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 4. Appending is pure

    func testAppendingReturnsNewArboretum() {
        let a = BASVersionArboretum(arboretumID: "arb")
        let b = a.appending(makeDelta(
            deltaID: "d1", afterRef: "v1"))
        XCTAssertEqual(a.deltas.count, 0, "original unchanged")
        XCTAssertEqual(b.deltas.count, 1)
        XCTAssertEqual(b.deltas.first?.deltaID, "d1")
    }

    // MARK: - 5. Query APIs

    func testDeltasTargeting() {
        let a = BASVersionArboretum(arboretumID: "arb")
            .appending(makeDelta(
                deltaID: "d1", afterRef: "v1"))
            .appending(makeDelta(
                deltaID: "d2", afterRef: "v2"))
            .appending(makeDelta(
                deltaID: "d3", beforeRef: "v2", afterRef: "v1",
                kind: .trialObservation))
        let targetingV1 = a.deltas(targeting: "v1")
        XCTAssertEqual(targetingV1.count, 2)
        XCTAssertEqual(Set(targetingV1.map(\.deltaID)),
                       Set(["d1", "d3"]))
    }

    func testChildrenOf() {
        let a = BASVersionArboretum(arboretumID: "arb")
            .appending(makeDelta(
                deltaID: "d1", afterRef: "v1"))
            .appending(makeDelta(
                deltaID: "d2", beforeRef: "v1", afterRef: "v2"))
            .appending(makeDelta(
                deltaID: "d3", beforeRef: "v1", afterRef: "v3"))
        let children = a.children(of: "v1")
        XCTAssertEqual(children.count, 2)
        XCTAssertEqual(Set(children.map(\.deltaID)),
                       Set(["d2", "d3"]))
    }

    func testDeltasOfKind() {
        let a = BASVersionArboretum(arboretumID: "arb")
            .appending(makeDelta(
                deltaID: "d1", afterRef: "v1",
                kind: .candidateAdmitted))
            .appending(makeDelta(
                deltaID: "d2", beforeRef: "v1", afterRef: "v2",
                kind: .candidatePromoted))
            .appending(makeDelta(
                deltaID: "d3", beforeRef: "v2", afterRef: "v3",
                kind: .retractionQueued))
        let promotions = a.deltas(ofKind: .candidatePromoted)
        XCTAssertEqual(promotions.count, 1)
        XCTAssertEqual(promotions.first?.deltaID, "d2")
    }

    // MARK: - 6. Ancestor walk

    func testAncestorsWalkUpChain() {
        let a = BASVersionArboretum(arboretumID: "arb")
            .appending(makeDelta(
                deltaID: "d1", afterRef: "v1",
                kind: .candidateAdmitted))
            .appending(makeDelta(
                deltaID: "d2", beforeRef: "v1", afterRef: "v2",
                kind: .candidatePromoted))
            .appending(makeDelta(
                deltaID: "d3", beforeRef: "v2", afterRef: "v3",
                kind: .trialObservation))
        let path = a.ancestors(of: "v3")
        XCTAssertEqual(path.map(\.deltaID), ["d3", "d2", "d1"])
    }

    func testAncestorsHandlesUnknownVersionRef() {
        let a = BASVersionArboretum(arboretumID: "arb")
        let path = a.ancestors(of: "unknown")
        XCTAssertEqual(path, [])
    }

    func testAncestorsDoesNotLoopOnCycle() {
        // Build a pathological cycle d1: v1 → v2, d2: v2 → v1.
        // ancestors(of: "v1") walks v1 → d1.beforeRef (v2) →
        // d2.beforeRef (v1 already seen) → stop.
        let a = BASVersionArboretum(arboretumID: "arb")
            .appending(makeDelta(
                deltaID: "d1", beforeRef: "v2", afterRef: "v1"))
            .appending(makeDelta(
                deltaID: "d2", beforeRef: "v1", afterRef: "v2"))
        let path = a.ancestors(of: "v1")
        // path should terminate, not loop forever.
        XCTAssertLessThanOrEqual(path.count, 2)
    }

    // MARK: - 7. Reversible rollback path

    func testReversibleRollbackPathStopsAtFirstIrreversible() {
        let a = BASVersionArboretum(arboretumID: "arb")
            .appending(makeDelta(
                deltaID: "d1", afterRef: "v1",
                reversible: true))
            .appending(makeDelta(
                deltaID: "d2", beforeRef: "v1", afterRef: "v2",
                reversible: true))
            .appending(makeDelta(
                deltaID: "d3", beforeRef: "v2", afterRef: "v3",
                reversible: false))
            .appending(makeDelta(
                deltaID: "d4", beforeRef: "v3", afterRef: "v4",
                reversible: true))
        // Walk from v4: d4 (reversible) → d3 (non-reversible,
        // stop) — v1/v2 beyond d3 are unreachable.
        let path = a.reversibleRollbackPath(from: "v4")
        XCTAssertEqual(path.map(\.deltaID), ["d4", "d3"])
        XCTAssertFalse(path.last?.reversible ?? true)
    }

    func testReversibleRollbackPathFullyReversible() {
        let a = BASVersionArboretum(arboretumID: "arb")
            .appending(makeDelta(
                deltaID: "d1", afterRef: "v1",
                reversible: true))
            .appending(makeDelta(
                deltaID: "d2", beforeRef: "v1", afterRef: "v2",
                reversible: true))
        let path = a.reversibleRollbackPath(from: "v2")
        XCTAssertEqual(path.map(\.deltaID), ["d2", "d1"])
        XCTAssertTrue(path.allSatisfy(\.reversible))
    }

    // MARK: - 8. knownVersionRefs + rootVersionRefs

    func testKnownVersionRefsUnionBeforeAndAfter() {
        let a = BASVersionArboretum(arboretumID: "arb")
            .appending(makeDelta(
                deltaID: "d1", afterRef: "v1"))
            .appending(makeDelta(
                deltaID: "d2", beforeRef: "v1", afterRef: "v2"))
            .appending(makeDelta(
                deltaID: "d3", beforeRef: "v2", afterRef: "v3"))
        XCTAssertEqual(
            a.knownVersionRefs,
            Set(["v1", "v2", "v3"]))
    }

    func testRootVersionRefsReturnsAdmittedAfterRefs() {
        let a = BASVersionArboretum(arboretumID: "arb")
            .appending(makeDelta(
                deltaID: "d1", afterRef: "v-root",
                kind: .candidateAdmitted))
            .appending(makeDelta(
                deltaID: "d2", beforeRef: "v-root", afterRef: "v1",
                kind: .candidatePromoted))
        XCTAssertEqual(a.rootVersionRefs, ["v-root"])
    }
}

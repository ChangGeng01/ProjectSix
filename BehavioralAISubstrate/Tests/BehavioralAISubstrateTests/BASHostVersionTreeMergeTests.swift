import XCTest
@testable import BASMemory

/// M217 — coverage for `BASHostVersionTree.merging(_:)`.
///
/// CRDT-style merges are tested for three properties + per-axis
/// resolution:
///
/// 1. **Commutativity**: `a.merging(b) == b.merging(a)` for any
///    well-formed pair.
/// 2. **Associativity**: `(a.merging(b)).merging(c) ==
///    a.merging(b.merging(c))`.
/// 3. **Idempotence**: `a.merging(a) == a` (modulo sort order).
/// 4. **Per-axis resolution**:
///    - versions: union by ID, latest createdAt wins on collision
///    - pending: union of both sets
///    - frozen: union of both sets
///    - active: pick later createdAt; tie-break lexicographic
final class BASHostVersionTreeMergeTests: XCTestCase {

    private func version(
        _ id: String,
        at seconds: TimeInterval,
        approvedByPolicy: Bool = true
    ) -> BASHostVersion {
        BASHostVersion(
            versionID: id,
            createdAt: Date(timeIntervalSince1970: seconds),
            changedFields: [],
            reason: "test",
            approvedByPolicy: approvedByPolicy)
    }

    // MARK: - 1. Versions union by ID

    func testMergeVersionsUnionsByID() {
        let local = BASHostVersionTree(
            activeVersionID: "v1",
            versions: [version("v1", at: 100)])
        let remote = BASHostVersionTree(
            activeVersionID: "v2",
            versions: [version("v2", at: 200)])
        let merged = local.merging(remote)
        let ids = merged.versions.map(\.versionID)
        XCTAssertEqual(ids, ["v1", "v2"])
    }

    /// deep-audit MED: two devices merging in opposite order must yield byte-identical version arrays
    /// (the documented commutative property). For a same-versionID + same-createdAt + same-approvedByPolicy
    /// collision with DIFFERENT content, the old merge had NO tiebreak → local (existing) won, so the two
    /// orders diverged. The content-key tiebreak restores commutativity. Unfixed: ab keeps reason-A, ba
    /// keeps reason-B → RED.
    func testMergeCommutativeForSameTimeSameApprovalDifferentContent() {
        func v(_ reason: String) -> BASHostVersion {
            BASHostVersion(versionID: "v1", createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                changedFields: ["f"], reason: reason, approvedByPolicy: true)
        }
        let a = BASHostVersionTree(activeVersionID: "v1", versions: [v("reason-A")])
        let b = BASHostVersionTree(activeVersionID: "v1", versions: [v("reason-B")])
        let ab = a.merging(b).versions
        let ba = b.merging(a).versions
        XCTAssertEqual(ab.count, 1)
        XCTAssertEqual(ba.count, 1)
        XCTAssertEqual(ab.map(\.reason), ba.map(\.reason),
            "merge must be commutative regardless of local/remote order")
    }

    func testCollisionPicksLaterCreatedAt() {
        let earlier = version("v1", at: 100, approvedByPolicy: true)
        let later = version("v1", at: 500, approvedByPolicy: true)
        let local = BASHostVersionTree(
            activeVersionID: "v1", versions: [earlier])
        let remote = BASHostVersionTree(
            activeVersionID: "v1", versions: [later])
        let merged = local.merging(remote)
        XCTAssertEqual(merged.versions.count, 1)
        XCTAssertEqual(
            merged.versions[0].createdAt,
            Date(timeIntervalSince1970: 500),
            "later createdAt must win on versionID collision")
    }

    func testCollisionTieBreaksOnApprovedByPolicy() {
        // Same createdAt but one is approvedByPolicy=true; the
        // approved version wins (signed vs unsigned tiebreak).
        let unsigned = version(
            "v1", at: 100, approvedByPolicy: false)
        let signed = version(
            "v1", at: 100, approvedByPolicy: true)
        let local = BASHostVersionTree(
            activeVersionID: "v1", versions: [unsigned])
        let remote = BASHostVersionTree(
            activeVersionID: "v1", versions: [signed])
        let merged = local.merging(remote)
        XCTAssertEqual(merged.versions.count, 1)
        XCTAssertTrue(merged.versions[0].approvedByPolicy)
    }

    // MARK: - 2. Pending + frozen are unions

    func testPendingCandidatesUnion() {
        let local = BASHostVersionTree(
            activeVersionID: "v1",
            versions: [version("v1", at: 100)],
            pendingCandidateIDs: ["c1", "c2"])
        let remote = BASHostVersionTree(
            activeVersionID: "v1",
            versions: [version("v1", at: 100)],
            pendingCandidateIDs: ["c2", "c3"])
        let merged = local.merging(remote)
        XCTAssertEqual(
            merged.pendingCandidateIDs, ["c1", "c2", "c3"])
    }

    func testFrozenVersionsUnion() {
        let local = BASHostVersionTree(
            activeVersionID: "v1",
            versions: [version("v1", at: 100)],
            frozenVersionIDs: ["v1"])
        let remote = BASHostVersionTree(
            activeVersionID: "v1",
            versions: [version("v1", at: 100)],
            frozenVersionIDs: ["v2"])
        let merged = local.merging(remote)
        XCTAssertEqual(
            merged.frozenVersionIDs, ["v1", "v2"],
            "freezing on either device propagates to both — " +
            "sovereign safety doctrine")
    }

    // MARK: - 3. Active version resolution

    func testActiveResolvesToLaterCreatedAt() {
        let v1 = version("v1", at: 100)
        let v2 = version("v2", at: 200)
        let local = BASHostVersionTree(
            activeVersionID: "v1", versions: [v1, v2])
        let remote = BASHostVersionTree(
            activeVersionID: "v2", versions: [v1, v2])
        let merged = local.merging(remote)
        XCTAssertEqual(
            merged.activeVersionID, "v2",
            "v2 has later createdAt → wins as active")
    }

    func testActiveTieBreaksOnLexicographicID() {
        let v1 = version("v1", at: 100)
        let v2 = version("v2", at: 100)  // same time
        let local = BASHostVersionTree(
            activeVersionID: "v1", versions: [v1, v2])
        let remote = BASHostVersionTree(
            activeVersionID: "v2", versions: [v1, v2])
        let merged = local.merging(remote)
        XCTAssertEqual(
            merged.activeVersionID, "v1",
            "ties break on lexicographic versionID; v1 < v2")
    }

    // MARK: - 4. CRDT properties

    /// Commutativity: a.merging(b) == b.merging(a)
    func testMergeIsCommutative() {
        let v1 = version("v1", at: 100)
        let v2 = version("v2", at: 200)
        let v3 = version("v3", at: 150)
        let a = BASHostVersionTree(
            activeVersionID: "v1",
            versions: [v1],
            pendingCandidateIDs: ["c1"],
            frozenVersionIDs: [])
        let b = BASHostVersionTree(
            activeVersionID: "v2",
            versions: [v2, v3],
            pendingCandidateIDs: ["c2"],
            frozenVersionIDs: ["v3"])

        let aThenB = a.merging(b)
        let bThenA = b.merging(a)
        XCTAssertEqual(
            aThenB.versions.map(\.versionID),
            bThenA.versions.map(\.versionID))
        XCTAssertEqual(
            aThenB.pendingCandidateIDs,
            bThenA.pendingCandidateIDs)
        XCTAssertEqual(
            aThenB.frozenVersionIDs,
            bThenA.frozenVersionIDs)
        XCTAssertEqual(
            aThenB.activeVersionID,
            bThenA.activeVersionID)
    }

    /// Associativity: (a.merging(b)).merging(c) ==
    /// a.merging(b.merging(c))
    func testMergeIsAssociative() {
        let v1 = version("v1", at: 100)
        let v2 = version("v2", at: 200)
        let v3 = version("v3", at: 300)
        let a = BASHostVersionTree(
            activeVersionID: "v1",
            versions: [v1],
            pendingCandidateIDs: ["c1"])
        let b = BASHostVersionTree(
            activeVersionID: "v2",
            versions: [v2],
            pendingCandidateIDs: ["c2"])
        let c = BASHostVersionTree(
            activeVersionID: "v3",
            versions: [v3],
            frozenVersionIDs: ["v1"])

        let leftAssoc = a.merging(b).merging(c)
        let rightAssoc = a.merging(b.merging(c))
        XCTAssertEqual(
            leftAssoc.versions.map(\.versionID),
            rightAssoc.versions.map(\.versionID))
        XCTAssertEqual(
            leftAssoc.pendingCandidateIDs,
            rightAssoc.pendingCandidateIDs)
        XCTAssertEqual(
            leftAssoc.frozenVersionIDs,
            rightAssoc.frozenVersionIDs)
        XCTAssertEqual(
            leftAssoc.activeVersionID,
            rightAssoc.activeVersionID)
    }

    /// Idempotence: a.merging(a) == a (modulo sort order; the
    /// merge sorts versions by createdAt + versionID).
    func testMergeIsIdempotent() {
        let v1 = version("v1", at: 100)
        let v2 = version("v2", at: 200)
        let a = BASHostVersionTree(
            activeVersionID: "v2",
            versions: [v1, v2],
            pendingCandidateIDs: ["c1", "c2"],
            frozenVersionIDs: ["v1"])
        let merged = a.merging(a)
        // Versions must be the same set (post-merge sort may
        // reorder; we compare by IDs as a set).
        XCTAssertEqual(
            Set(merged.versions.map(\.versionID)),
            Set(a.versions.map(\.versionID)))
        XCTAssertEqual(
            merged.pendingCandidateIDs.sorted(),
            a.pendingCandidateIDs.sorted())
        XCTAssertEqual(
            merged.frozenVersionIDs.sorted(),
            a.frozenVersionIDs.sorted())
        XCTAssertEqual(
            merged.activeVersionID, a.activeVersionID)
    }

    // MARK: - 5. Edge cases

    func testEmptyTreesProduceEmptyMerge() {
        let a = BASHostVersionTree(activeVersionID: "v1")
        let b = BASHostVersionTree(activeVersionID: "v2")
        let merged = a.merging(b)
        XCTAssertTrue(merged.versions.isEmpty)
        XCTAssertTrue(merged.pendingCandidateIDs.isEmpty)
        XCTAssertTrue(merged.frozenVersionIDs.isEmpty)
        // Active falls back to one of the inputs even if neither
        // version exists in the merged set; we don't assert which
        // — just that it's deterministic.
        XCTAssertTrue(
            ["v1", "v2"].contains(merged.activeVersionID))
    }

    func testSelfMergeReturnsEquivalentTree() {
        let v1 = version("v1", at: 100)
        let a = BASHostVersionTree(
            activeVersionID: "v1", versions: [v1])
        let merged = a.merging(a)
        XCTAssertEqual(merged.activeVersionID, "v1")
        XCTAssertEqual(merged.versions.map(\.versionID), ["v1"])
    }
}

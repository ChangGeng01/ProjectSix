import XCTest
import BASMemory
@testable import QinaoMemory

/// audit F7 (2026-07-12) — the learning bundle digest binds the WHOLE entry (incl. confidence)
/// and the field framing is injective (no "|" collision).
final class QinaoLearningExportDigestTests: XCTestCase {

    private static let approveAll:
        @Sendable (QinaoMemory.LearningExportCandidate) async throws -> String?
        = { _ in "warrant" }

    private func exporter() -> QinaoLearningExporter {
        QinaoLearningExporter(approver: Self.approveAll,
                              now: { Date(timeIntervalSince1970: 1_700_000_000) })
    }
    private func cand(skeleton: String, domain: String, confidence: Double)
        -> QinaoMemory.LearningExportCandidate {
        QinaoMemory.LearningExportCandidate(
            sourceMemoryID: UUID(), generalizedSkeleton: skeleton, domain: domain,
            confidence: confidence, sensitivity: .medium)
    }

    /// A confidence flip must change the bundle digest (was byte-identical pre-fix).
    func testConfidenceFlipChangesDigest() async throws {
        let lo = try await exporter().export(candidates:
            [cand(skeleton: "S", domain: "D", confidence: 0.1)])
        let hi = try await exporter().export(candidates:
            [cand(skeleton: "S", domain: "D", confidence: 0.9)])
        XCTAssertNotEqual(lo.bundleDigest, hi.bundleDigest,
            "confidence is part of the entry — flipping it must change the bundle digest")
    }

    /// Injective framing: ["a|b","c"] and ["a","b|c"] must NOT collide (skeleton vs domain).
    func testDelimiterCollisionIsClosed() async throws {
        let x = try await exporter().export(candidates:
            [cand(skeleton: "a|b", domain: "c", confidence: 0.5)])
        let y = try await exporter().export(candidates:
            [cand(skeleton: "a", domain: "b|c", confidence: 0.5)])
        XCTAssertNotEqual(x.entries[0].contentHash, y.entries[0].contentHash,
            "a '|' inside a field must not be mistaken for a field boundary")
        XCTAssertNotEqual(x.bundleDigest, y.bundleDigest)
    }

    /// canonicalJoin is injective; canonicalConfidence is lossless & deterministic.
    func testCanonicalJoinAndConfidenceHelpers() {
        typealias E = QinaoLearningExporter
        XCTAssertNotEqual(E.canonicalJoin(["a|b", "c"]), E.canonicalJoin(["a", "b|c"]))
        XCTAssertNotEqual(E.canonicalJoin(["", "x"]), E.canonicalJoin(["x", ""]))
        XCTAssertEqual(E.canonicalJoin(["ab", "c"]), E.canonicalJoin(["ab", "c"]))
        XCTAssertNotEqual(E.canonicalConfidence(0.1), E.canonicalConfidence(0.9))
        XCTAssertEqual(E.canonicalConfidence(0.5), E.canonicalConfidence(0.5))
    }
}

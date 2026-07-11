import XCTest
@testable import BASHostKit
import BASMemory

/// Grounding increment 2 — the semantic citation ASSISTANT's commit-embedding index (hint-only;
/// the 2026-07-11 calibration probe showed sealed semantic grounding is a NO-GO: minTrueCos 0.252
/// vs maxFalseTopCos 0.614 on n=10, so nothing here ever touches the seal). The index caches one
/// embedding per (sha8, providerVersion) in SQLite — the 3,887-subject backfill runs ONCE — and
/// `hint(for:)` is a top-1 cosine + CRAG-margin gate that proposes a citation for the OPERATOR to
/// verify and cite (the deterministic increment-1 path then does the sealing).
final class BASSemanticCommitIndexTests: XCTestCase {

    /// Deterministic fake provider: fixed vectors for known texts, hash-derived unit vectors
    /// otherwise; counts embed calls so the incremental-cache property is directly observable.
    private final class CountingFakeProvider: BASMemory.BASEmbeddingProvider, @unchecked Sendable {
        var providerVersion: String { "fake-v1" }
        var dimension: Int { 4 }
        var embedCalls = 0
        var table: [String: [Float]] = [:]
        func embed(_ text: String) async -> BASEmbedding {
            embedCalls += 1
            let v = table[text] ?? {   // hash-derived fallback, deterministic
                var h = UInt64(1469598103934665603)
                for b in text.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
                var vec = (0..<4).map { Float((h >> ($0 * 8)) & 0xFF) / 255.0 + 0.01 }
                let n = vec.map { $0 * $0 }.reduce(0, +).squareRoot()
                vec = vec.map { $0 / n }
                return vec
            }()
            return BASEmbedding(vector: v, dimension: 4, providerVersion: providerVersion)
        }
    }

    private func tmpDB() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-semidx-\(UUID().uuidString).sqlite").path
    }

    private func norm(_ v: [Float]) -> [Float] {
        let n = v.map { $0 * $0 }.reduce(0, +).squareRoot()
        return v.map { $0 / n }
    }

    func testRefreshEmbedsOnceThenIsIncrementalAndPersistent() async throws {
        let db = tmpDB()
        defer { try? FileManager.default.removeItem(atPath: db) }
        let provider = CountingFakeProvider()
        provider.table["alpha subject"] = [1, 0, 0, 0]
        provider.table["beta subject"] = [0, 1, 0, 0]

        let idx = try BASSemanticCommitIndex(dbPath: db, provider: provider)
        let first = try await idx.refresh(subjectsBySha8: [
            "aaaaaaaa": "alpha subject", "bbbbbbbb": "beta subject"])
        XCTAssertEqual(first, 2, "cold cache embeds both subjects")
        XCTAssertEqual(provider.embedCalls, 2)

        let second = try await idx.refresh(subjectsBySha8: [
            "aaaaaaaa": "alpha subject", "bbbbbbbb": "beta subject",
            "cccccccc": "gamma subject"])
        XCTAssertEqual(second, 1, "warm cache embeds ONLY the new commit")
        XCTAssertEqual(provider.embedCalls, 3)
        idx.close()

        // persistence: a NEW index instance over the same file re-embeds nothing
        let provider2 = CountingFakeProvider()
        let idx2 = try BASSemanticCommitIndex(dbPath: db, provider: provider2)
        let third = try await idx2.refresh(subjectsBySha8: [
            "aaaaaaaa": "alpha subject", "bbbbbbbb": "beta subject",
            "cccccccc": "gamma subject"])
        XCTAssertEqual(third, 0, "the cache survives across processes/instances")
        XCTAssertEqual(provider2.embedCalls, 0)

        // the backfill-notice count must be the ACTUALLY-missing count (a warm cache = 0 —
        // caught live: the notice printed "backfill of 3887" on every warm add, a lying notice)
        let warm = try idx2.missingCount(subjectsBySha8: [
            "aaaaaaaa": "alpha subject", "bbbbbbbb": "beta subject",
            "cccccccc": "gamma subject"])
        XCTAssertEqual(warm, 0, "warm cache ⇒ missingCount 0 ⇒ no backfill notice")
        let mixed = try idx2.missingCount(subjectsBySha8: [
            "aaaaaaaa": "alpha subject", "dddddddd": "delta subject"])
        XCTAssertEqual(mixed, 1, "only the genuinely-uncached commit counts")
        idx2.close()
    }

    func testHintReturnsTopMatchAboveGate() async throws {
        let db = tmpDB()
        defer { try? FileManager.default.removeItem(atPath: db) }
        let provider = CountingFakeProvider()
        provider.table["alpha subject"] = [1, 0, 0, 0]
        provider.table["beta subject"] = [0, 1, 0, 0]
        provider.table["near alpha claim"] = norm([0.9, 0.1, 0, 0])   // cos≈0.99 vs alpha

        let idx = try BASSemanticCommitIndex(dbPath: db, provider: provider)
        defer { idx.close() }
        _ = try await idx.refresh(subjectsBySha8: [
            "aaaaaaaa": "alpha subject", "bbbbbbbb": "beta subject"])

        let hint = await idx.hint(for: "near alpha claim")
        XCTAssertEqual(hint?.sha8, "aaaaaaaa")
        XCTAssertGreaterThanOrEqual(hint?.cosine ?? 0, BASSemanticHintGate.calibrated.threshold)
    }

    func testHintAbstainsBelowThresholdAndOnAmbiguousMargin() async throws {
        let db = tmpDB()
        defer { try? FileManager.default.removeItem(atPath: db) }
        let provider = CountingFakeProvider()
        provider.table["alpha subject"] = [1, 0, 0, 0]
        provider.table["beta subject"] = [0, 1, 0, 0]
        provider.table["orthogonal claim"] = [0, 0, 0, 1]              // cos 0 vs both
        provider.table["ambiguous claim"] = norm([0.7, 0.7, 0, 0])     // ≈equal cos vs both

        let idx = try BASSemanticCommitIndex(dbPath: db, provider: provider)
        defer { idx.close() }
        _ = try await idx.refresh(subjectsBySha8: [
            "aaaaaaaa": "alpha subject", "bbbbbbbb": "beta subject"])

        let below = await idx.hint(for: "orthogonal claim")
        XCTAssertNil(below, "below the threshold ⇒ no hint (abstain bias)")
        let ambiguous = await idx.hint(for: "ambiguous claim")
        XCTAssertNil(ambiguous, "two near-equal candidates ⇒ CRAG margin abstains (no confident wrong hint)")
    }
}

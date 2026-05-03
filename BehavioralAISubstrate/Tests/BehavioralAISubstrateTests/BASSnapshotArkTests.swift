import XCTest
@testable import BASSovereign

/// M443 (chapter 一百十六) — drift-detector + parity-lock tests
/// for the Snapshot Ark typed wrapper.
final class BASSnapshotArkTests: XCTestCase {

    // MARK: - Construction

    func testSnapshotArkInitialises() {
        _ = BASSnapshotArk()
    }

    // MARK: - Schema version

    func testSchemaVersionIsOneZero() {
        XCTAssertEqual(BASSnapshotArk.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASSnapshotArk().schemaVersion, "1.0.0")
    }

    // MARK: - White-paper ref

    func testWhitePaperRefCitesSection3Point9() {
        XCTAssertTrue(BASSnapshotArk.whitePaperRef.contains("§3.9"))
    }

    // MARK: - Layer refs

    func testLayerRefsCoverL3L5L8L13L14() {
        let layers = BASSnapshotArk.canonicalLayerRefs
        XCTAssertTrue(layers.contains(3),
                      "Snapshot Ark wraps L3 thought-fold payloads")
        XCTAssertTrue(layers.contains(5),
                      "Snapshot Ark wraps L5 host-version-tree payloads")
        XCTAssertTrue(layers.contains(8),
                      "Snapshot Ark wraps L8 memory tier state")
        XCTAssertTrue(layers.contains(13),
                      "Snapshot Ark wraps L13 lifecycle session state")
        XCTAssertTrue(layers.contains(14),
                      "Snapshot Ark is L14 sovereign-surface")
    }

    func testLayerRefsAreInRange1To14() {
        for layer in BASSnapshotArk.canonicalLayerRefs {
            XCTAssertTrue((1...14).contains(layer),
                          "Ark layer \(layer) outside 1...14")
        }
    }

    // MARK: - Canonical wrapped types

    func testWrapsAtLeastOneType() {
        XCTAssertFalse(BASSnapshotArk.canonicalAssignedTypes.isEmpty)
    }

    func testCanonicalTypesUseBASSovereignPrefix() {
        // Every wrapped type lives in BASSovereign library.
        for typeName in BASSnapshotArk.canonicalAssignedTypes {
            XCTAssertTrue(
                typeName.hasPrefix("BASSovereign"),
                "Snapshot Ark wrapped type \(typeName) must live in " +
                "BASSovereign library (prefix `BASSovereign`)"
            )
        }
    }

    func testCanonicalTypesAreUnique() {
        let typeNames = BASSnapshotArk.canonicalAssignedTypes
        let unique = Set(typeNames)
        XCTAssertEqual(typeNames.count, unique.count,
                       "duplicate type in Snapshot Ark wrapped list")
    }

    /// The Ark must wrap the snapshot manager itself (the
    /// integrity-hash-binding + restore verification core).
    func testWrapsSnapshotManager() {
        XCTAssertTrue(
            BASSnapshotArk.canonicalAssignedTypes
                .contains("BASSovereignSnapshotManager"))
    }

    /// The Ark must wrap the clean-reboot coordinator (post-
    /// deadStop next-session bootstrap).
    func testWrapsCleanRebootCoordinator() {
        XCTAssertTrue(
            BASSnapshotArk.canonicalAssignedTypes
                .contains("BASSovereignCleanRebootCoordinator"))
    }

    /// The Ark must wrap the host-version-tree (the L5 version
    /// graph navigation surface).
    func testWrapsHostVersionTree() {
        XCTAssertTrue(
            BASSnapshotArk.canonicalAssignedTypes
                .contains("BASSovereignHostVersionTree"))
    }

    // MARK: - Round-trip Codable

    func testRoundTripCodable() throws {
        let ark = BASSnapshotArk()
        let data = try JSONEncoder().encode(ark)
        let decoded = try JSONDecoder().decode(BASSnapshotArk.self, from: data)
        XCTAssertEqual(ark, decoded)
    }
}

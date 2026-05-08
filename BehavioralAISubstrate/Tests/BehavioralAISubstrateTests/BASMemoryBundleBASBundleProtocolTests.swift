// MARK: - BASMemoryBundleBASBundleProtocolTests
// chapter 四百四 / M964

import Foundation
import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASMemoryBundleBASBundleProtocolTests:
    XCTestCase
{

    // MARK: - Fixtures

    private func makeBundle(
        atomCount: Int = 0,
        retrievedAt: Date =
            Date(timeIntervalSinceReferenceDate: 0)
    ) -> BASMemoryBundle {
        let atoms: [BASMemoryAtom] = []
        return BASMemoryBundle(
            atoms: atoms,
            retrievalTags: [],
            conflictRefs: [],
            retrievedAt: retrievedAt)
    }

    // MARK: - Conformance

    func testBASMemoryBundleConformsToBASBundleProtocol() {
        let bundle = makeBundle()
        let _: any BASBundleProtocol = bundle
        XCTAssertTrue(true,
            "M964:BASMemoryBundle conforms to BASBundleProtocol")
    }

    // MARK: - bundleID derivation

    func testBundleIDPrefixIsPinned() {
        XCTAssertEqual(
            BASMemoryBundle.bundleIDFormatPrefix,
            "memory-bundle")
    }

    func testBundleIDIncludesAtomCount() {
        let bundle = makeBundle(atomCount: 0)
        XCTAssertTrue(
            bundle.bundleID.contains("atoms-0"))
    }

    func testBundleIDIncludesTimestamp() {
        let bundle = makeBundle(
            retrievedAt: Date(
                timeIntervalSinceReferenceDate: 42.5))
        XCTAssertTrue(
            bundle.bundleID.contains("ts-42.5"))
    }

    func testBundleIDByteStableForSameInput() {
        let date = Date(timeIntervalSinceReferenceDate: 1.0)
        let b1 = makeBundle(retrievedAt: date)
        let b2 = makeBundle(retrievedAt: date)
        XCTAssertEqual(b1.bundleID, b2.bundleID,
            "M964:M892 byte-stable bundleID")
    }

    // MARK: - recordedAt mapping

    func testRecordedAtMatchesRetrievedAt() {
        let date = Date(timeIntervalSinceReferenceDate: 99)
        let bundle = makeBundle(retrievedAt: date)
        XCTAssertEqual(bundle.recordedAt, date,
            "M964:recordedAt maps to retrievedAt")
    }
}

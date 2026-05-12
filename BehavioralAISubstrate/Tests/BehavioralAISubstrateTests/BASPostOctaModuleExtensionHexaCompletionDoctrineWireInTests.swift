// MARK: - BASPostOctaModuleExtensionHexaCompletionDoctrineWireInTests
// chapter 六百七 / M1807 — wire-in PROOF tests cross-
//                          checking the M1805 hexa
//                          catalog against the 6
//                          source per-entry extension
//                          doctrines + chapter 597
//                          octa-milestone precedent
//
// ## Coverage (14 wire-in PROOF tests)
//
// For each of the 6 entries:
//   1. hexa's mNumberFirst matches source doctrine's
//      extensionMNumber
//   2. hexa's typesExtended matches source doctrine's
//      totalTypesExtended
//
// = 12 per-entry wire-in tests。
//
// Plus 2 cross-catalog invariants:
//   - hexa.moduleCountAfterAllEntries matches the
//     LAST entry's moduleCountAfter (12)
//   - hexa.moduleCountAtOctaClose matches octa's
//     totalModulesCovered (6)
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1806 → M1807

import XCTest
@testable import BASRuntimeCore

final class BASPostOctaModuleExtensionHexaCompletionDoctrineWireInTests:
    XCTestCase
{
    // MARK: - Entry 1 — BASOrgan wire-ins

    func testEntry1OrganMNumberWiresIn() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[0].mNumberFirst,
            BASOrganCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry1OrganTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[0].typesExtended,
            BASOrganCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 2 — BASMLXAdapter wire-ins

    func testEntry2MLXMNumberWiresIn() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[1].mNumberFirst,
            BASMLXAdapterCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry2MLXTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[1].typesExtended,
            BASMLXAdapterCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 3 — BASChatCompletionsAdapter wire-ins

    func testEntry3ChatCompletionsMNumberWiresIn() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[2].mNumberFirst,
            BASChatCompletionsAdapterCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry3ChatCompletionsTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[2].typesExtended,
            BASChatCompletionsAdapterCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 4 — BASAppleAdapters wire-ins

    func testEntry4AppleAdaptersMNumberWiresIn() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[3].mNumberFirst,
            BASAppleAdaptersCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry4AppleAdaptersTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[3].typesExtended,
            BASAppleAdaptersCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 5 — BASMetalSubstrate wire-ins

    func testEntry5MetalSubstrateMNumberWiresIn() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[4].mNumberFirst,
            BASMetalSubstrateCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry5MetalSubstrateTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[4].typesExtended,
            BASMetalSubstrateCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 6 — BASSovereign wire-ins

    func testEntry6SovereignMNumberWiresIn() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[5].mNumberFirst,
            BASSovereignCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry6SovereignTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[5].typesExtended,
            BASSovereignCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Cross-catalog invariants

    func testLastEntryModuleCountMatchesAggregate() {
        // PROOF — last entry's moduleCountAfter must
        // equal the aggregate moduleCountAfterAllEntries
        // (12)。
        let lastEntry =
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries.last!
        XCTAssertEqual(
            lastEntry.moduleCountAfter,
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .moduleCountAfterAllEntries)
    }

    func testModuleCountAtOctaCloseMatchesOctaTotal() {
        // PROOF — pre-post-octa module count must equal
        // chapter 597 octa-milestone totalModulesCovered。
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .moduleCountAtOctaClose,
            BASCodableExtensionOctaMilestoneCompletionDoctrine
                .totalModulesCovered)
    }
}

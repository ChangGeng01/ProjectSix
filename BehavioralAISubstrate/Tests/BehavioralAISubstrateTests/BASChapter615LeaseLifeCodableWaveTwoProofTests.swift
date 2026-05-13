// MARK: - BASChapter615LeaseLifeCodableWaveTwoProofTests
// chapter 六百一十五 / M1838 — PROOF tests for the M1837
//                              BASLeaseLife Codable
//                              extension wave 2
//                              (gap-fill)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASLeaseLife gap-fill wave 2 — 2 nested-in-enum
// String-raw-value enums within BASDeviceRouting
// become Codable:
//
//   - BASDeviceRouting.Capability (3-case String-raw:
//     cpu/gpu/ane)
//   - BASDeviceRouting.Role (2-case String-raw:
//     scout/core)
//
// Both enums get Codable for free via Swift String-
// raw-value enum synthesis。 No CodingKeys or custom
// init required。
//
// FIRST post-hexa-catalog gap-fill chapter (chapter
// 615 follows chapter 614 hexa catalog seal — starts
// a new gap-fill run heading toward the next hexa
// catalog opportunity)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these newly-Codable enums
//   - chapter 584 BASLeaseLife arc seal precedent
//   - chapter 614 gap-fill hexa catalog precedent
//     (this is the FIRST gap-fill post-hexa-seal)
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1837 → M1838

import XCTest
@testable import BASLeaseLife

final class BASChapter615LeaseLifeCodableWaveTwoProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testCapabilityConformsToCodable() {
        assertCodable(
            BASDeviceRouting.Capability.self)
    }

    func testRoleConformsToCodable() {
        assertCodable(BASDeviceRouting.Role.self)
    }
}

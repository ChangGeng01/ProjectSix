// MARK: - BASPermitEscalationLedgerTests — chapter 四百四 / M966

import Foundation
import XCTest
@testable import BASPolicy

final class BASPermitEscalationLedgerTests: XCTestCase {

    // MARK: - Fixtures

    private func makePermit(
        mode: BASActionPermitMode = .answer,
        reasonCodes: [String] = []
    ) -> BASActionPermit {
        BASActionPermit(mode: mode, reasonCodes: reasonCodes)
    }

    // MARK: - Stage enum

    func testStageEnumHasFiveCases() {
        XCTAssertEqual(
            BASPermitEscalationStage.allCases.count, 5)
    }

    func testStageRawValuesPinnedForGrep() {
        let raws = BASPermitEscalationStage.allCases.map {
            $0.rawValue
        }
        XCTAssertTrue(raws.contains("abyssal"))
        XCTAssertTrue(raws.contains("assertion-ceiling"))
        XCTAssertTrue(raws.contains("kunlun"))
        XCTAssertTrue(
            raws.contains("cthulhu-assertion-ceiling"))
        XCTAssertTrue(raws.contains("cthulhu-escalation"))
    }

    // MARK: - Stage record

    func testStageRecordFiredFalseWhenIdentity() {
        let permit = makePermit()
        let record = BASPermitEscalationStageRecord(
            stage: .abyssal,
            inputPermit: permit,
            outputPermit: permit)
        XCTAssertFalse(record.fired,
            "M966:identity transition does not fire")
    }

    func testStageRecordFiredTrueWhenModeChanges() {
        let input = makePermit(mode: .answer)
        let output = makePermit(mode: .delay)
        let record = BASPermitEscalationStageRecord(
            stage: .abyssal,
            inputPermit: input,
            outputPermit: output)
        XCTAssertTrue(record.fired)
    }

    func testStageRecordFiredTrueWhenReasonCodesEmitted() {
        let permit = makePermit()
        let record = BASPermitEscalationStageRecord(
            stage: .kunlun,
            inputPermit: permit,
            outputPermit: permit,
            reasonCodes: ["axis-deviation"])
        XCTAssertTrue(record.fired,
            "M966:emitted reason codes count as fired")
    }

    // MARK: - Ledger init + accessors

    func testEmptyLedgerFinalPermitMatchesInitial() {
        let initial = makePermit()
        let ledger = BASPermitEscalationLedger(
            initialPermit: initial)
        XCTAssertEqual(ledger.finalPermit.mode, initial.mode)
        XCTAssertEqual(ledger.firedStageCount, 0)
    }

    func testLedgerFinalPermitFollowsLastRecord() {
        let initial = makePermit(mode: .answer)
        let mid = makePermit(mode: .delay)
        let last = makePermit(mode: .escalate)
        let ledger = BASPermitEscalationLedger(
            initialPermit: initial)
            .appending(record: BASPermitEscalationStageRecord(
                stage: .abyssal,
                inputPermit: initial,
                outputPermit: mid))
            .appending(record: BASPermitEscalationStageRecord(
                stage: .kunlun,
                inputPermit: mid,
                outputPermit: last))
        XCTAssertEqual(ledger.finalPermit.mode, .escalate)
    }

    // MARK: - Aggregate reason codes

    func testAggregateReasonCodesPrefixesByStage() {
        let permit = makePermit()
        let ledger = BASPermitEscalationLedger(
            initialPermit: permit)
            .appending(record: BASPermitEscalationStageRecord(
                stage: .abyssal,
                inputPermit: permit,
                outputPermit: permit,
                reasonCodes: ["pressure-medium"]))
            .appending(record: BASPermitEscalationStageRecord(
                stage: .kunlun,
                inputPermit: permit,
                outputPermit: permit,
                reasonCodes: ["axis-shift"]))
        XCTAssertEqual(
            ledger.aggregateReasonCodes,
            ["abyssal:pressure-medium",
             "kunlun:axis-shift"])
    }

    // MARK: - Immutable updates

    func testAppendingRecordReturnsFreshLedger() {
        let permit = makePermit()
        let original = BASPermitEscalationLedger(
            initialPermit: permit)
        let updated = original.appending(
            record: BASPermitEscalationStageRecord(
                stage: .abyssal,
                inputPermit: permit,
                outputPermit: permit,
                reasonCodes: ["x"]))
        XCTAssertEqual(original.records.count, 0,
            "M966:appending must NOT mutate original")
        XCTAssertEqual(updated.records.count, 1)
    }

    // MARK: - Codable round-trip

    func testLedgerCodableRoundTrip() throws {
        let initial = makePermit(mode: .answer)
        let ledger = BASPermitEscalationLedger(
            initialPermit: initial)
            .appending(record: BASPermitEscalationStageRecord(
                stage: .kunlun,
                inputPermit: initial,
                outputPermit: makePermit(mode: .delay),
                reasonCodes: ["axis-shift"]))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(ledger)
        let decoded = try JSONDecoder().decode(
            BASPermitEscalationLedger.self, from: data)
        XCTAssertEqual(decoded, ledger)
    }

    // MARK: - Replay determinism

    func testSameInputChainProducesEqualLedgers() {
        let initial = makePermit(mode: .answer)
        let r1 = BASPermitEscalationStageRecord(
            stage: .abyssal,
            inputPermit: initial,
            outputPermit: makePermit(mode: .delay),
            reasonCodes: ["c1"])
        let l1 = BASPermitEscalationLedger(
            initialPermit: initial)
            .appending(record: r1)
        let l2 = BASPermitEscalationLedger(
            initialPermit: initial)
            .appending(record: r1)
        XCTAssertEqual(l1, l2,
            "M966:same input → same ledger (M892)")
    }

    // MARK: - Anti-magic-number constants

    func testReasonCodePrefixPinned() {
        XCTAssertEqual(
            BASPermitEscalationLedger
                .ledgerReasonCodePrefix,
            "permit-escalation-ledger")
    }

    // MARK: - chapter 四百四 v2 / M970 — build helper

    func testBuildHelperProducesFullChainLedger() {
        let initial = makePermit(mode: .answer)
        let afterA = makePermit(mode: .answer)
        let afterB = makePermit(mode: .delay)
        let afterC = makePermit(mode: .delay)
        let afterD = makePermit(mode: .escalate)
        let afterE = makePermit(mode: .escalate)
        let ledger = BASPermitEscalationLedger.build(
            initialPermit: initial,
            afterAbyssal: afterA,
            afterAssertionCeiling: afterB,
            afterAssertionCeilingReasonCodes:
                ["assertion-cap-fired"],
            afterKunlun: afterC,
            afterCthulhuAssertionCeiling: afterD,
            afterCthulhuAssertionCeilingReasonCodes:
                ["cthulhu-cap"],
            afterCthulhuEscalation: afterE)
        XCTAssertEqual(ledger.records.count, 5)
        XCTAssertEqual(ledger.finalPermit.mode, .escalate)
        XCTAssertTrue(
            ledger.aggregateReasonCodes.contains(
                "assertion-ceiling:assertion-cap-fired"))
        XCTAssertTrue(
            ledger.aggregateReasonCodes.contains(
                "cthulhu-assertion-ceiling:cthulhu-cap"))
    }

    func testBuildHelperWithIdentityChainHasZeroFired() {
        let permit = makePermit(mode: .answer)
        let ledger = BASPermitEscalationLedger.build(
            initialPermit: permit,
            afterAbyssal: permit,
            afterAssertionCeiling: permit,
            afterKunlun: permit,
            afterCthulhuAssertionCeiling: permit,
            afterCthulhuEscalation: permit)
        XCTAssertEqual(ledger.firedStageCount, 0,
            "M970:identity chain has 0 fired stages")
        XCTAssertEqual(ledger.finalPermit.mode, permit.mode)
    }

    func testBuildHelperRecordsCanonicalStageOrder() {
        let permit = makePermit()
        let ledger = BASPermitEscalationLedger.build(
            initialPermit: permit,
            afterAbyssal: permit,
            afterAssertionCeiling: permit,
            afterKunlun: permit,
            afterCthulhuAssertionCeiling: permit,
            afterCthulhuEscalation: permit)
        let stages = ledger.records.map { $0.stage }
        XCTAssertEqual(stages, [
            .abyssal,
            .assertionCeiling,
            .kunlun,
            .cthulhuAssertionCeiling,
            .cthulhuEscalation
        ])
    }

    func testBuildHelperByteStableForSameInputs() {
        let permit = makePermit()
        let l1 = BASPermitEscalationLedger.build(
            initialPermit: permit,
            afterAbyssal: permit,
            afterAssertionCeiling: permit,
            afterKunlun: permit,
            afterCthulhuAssertionCeiling: permit,
            afterCthulhuEscalation: permit)
        let l2 = BASPermitEscalationLedger.build(
            initialPermit: permit,
            afterAbyssal: permit,
            afterAssertionCeiling: permit,
            afterKunlun: permit,
            afterCthulhuAssertionCeiling: permit,
            afterCthulhuEscalation: permit)
        XCTAssertEqual(l1, l2,
            "M970:M892 byte-stable build helper")
    }
}

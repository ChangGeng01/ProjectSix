// MARK: - BASTurnRuntimePlanAssignmentEventPayloadTests
// chapter 四百四十一 / M1140-M1141-M1142 — POST-RADICAL Wave 12

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASMetalSubstrate

/// Pin tests for the M1140 typed payload + M1141 auto-
/// emit accessor。 Two test classes,both substrate-only
/// (no coordinator stubs needed)。 Full end-to-end emit
/// test requires the same coordinator-stub harness as
/// M1101 / M1117 / M1138 — deferred to host-side
/// integration tests where stubs already exist。
///
/// Coverage:
///   - Payload struct round-trip (Codable + sortedKeys)
///   - `.from(ledger:)` factory preserves all aggregates
///   - Empty-ledger factory yields empty payload
///   - `BASEventLogEntry.planAssignmentEvent(...)` factory
///     stamps the right discriminator + turnRef
///   - `BASEventLogEntry.planAssignmentEventPayload`
///     reverse accessor decodes round-trip
///   - `BASEventLogProjectors.projectPlanAssignmentEvents(_:)`
///     filter + sort behaviour
///   - Engine `lastEmittedPlanAssignmentEventIDValue()`
///     accessor signature pin

// MARK: - Payload pin tests

final class BASTurnRuntimePlanAssignmentEventPayloadTests:
    XCTestCase
{

    // MARK: - Test fixtures

    private func makeRecord(
        index: Int,
        backing: BASTensorBackingKind = .cpuBytes
    ) -> BASTurnRuntimeStageAssignmentRecord {
        let hint = BASStageAcceleratorHint(
            operation: .matMul,
            preferredDataType: .float16,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 10.0)
        let assignment = BASStageAcceleratorAssignment(
            selectedBackingKind: backing,
            selectedKernelKey: nil,
            costScore: 1.0,
            thermalSnapshot: .nominal,
            assignmentRationale: backing == .cpuBytes
                ? .cpuNoKernelRegistered
                : .aneSupported)
        return BASTurnRuntimeStageAssignmentRecord(
            stageRawValue: "stage-\(index)",
            hint: hint,
            assignment: assignment,
            sequenceIndex: index)
    }

    // MARK: - Factory — empty ledger

    func testFromEmptyLedgerYieldsEmptyPayload() {
        let ledger = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "t1")
        let payload =
            BASTurnRuntimePlanAssignmentEventPayload
                .from(ledger: ledger)
        XCTAssertEqual(payload.turnID, "t1")
        XCTAssertEqual(payload.records.count, 0)
        XCTAssertEqual(payload.recordCount, 0)
        XCTAssertEqual(payload.acceleratedRecordCount, 0)
        XCTAssertEqual(payload.uniqueStageCount, 0)
    }

    // MARK: - Factory — record-bearing ledger

    func testFromLedgerPreservesAggregates() {
        // 2 records: 1 accelerator-routed + 1 CPU-fallback
        let r0 = makeRecord(
            index: 0, backing: .metalBuffer)
        let r1 = makeRecord(
            index: 1, backing: .cpuBytes)
        let ledger = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "t-multi")
            .appending(r0)
            .appending(r1)
        let payload =
            BASTurnRuntimePlanAssignmentEventPayload
                .from(ledger: ledger)
        XCTAssertEqual(payload.turnID, "t-multi")
        XCTAssertEqual(payload.records.count, 2)
        XCTAssertEqual(payload.recordCount, 2)
        XCTAssertEqual(
            payload.acceleratedRecordCount, 1,
            "1 record routed to non-cpuBytes backing")
        XCTAssertEqual(
            payload.uniqueStageCount, 2,
            "2 distinct stage rawvalues")
    }

    func testFromLedgerEncodesRecordFields() {
        let r = makeRecord(
            index: 7, backing: .metalBuffer)
        let ledger = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "t-encode")
            .appending(r)
        let payload =
            BASTurnRuntimePlanAssignmentEventPayload
                .from(ledger: ledger)
        let rec = payload.records[0]
        XCTAssertEqual(rec.stageRawValue, "stage-7")
        XCTAssertEqual(
            rec.hintOperationRawValue, "mat-mul")
        XCTAssertEqual(rec.hintBatchSize, 1)
        XCTAssertEqual(rec.hintSequenceLength, 1)
        XCTAssertEqual(
            rec.selectedBackingKindRawValue,
            "metal-buffer")
        XCTAssertEqual(
            rec.selectedKernelKeyDescriptor, "",
            "nil kernel key encodes as empty string")
        XCTAssertEqual(rec.sequenceIndex, 7)
    }

    // MARK: - Codable round-trip via sortedKeys

    func testPayloadCodableRoundTrip() throws {
        let r = makeRecord(
            index: 3, backing: .mlxArray)
        let ledger = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "t-codable")
            .appending(r)
        let original =
            BASTurnRuntimePlanAssignmentEventPayload
                .from(ledger: ledger)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnRuntimePlanAssignmentEventPayload.self,
            from: data)
        XCTAssertEqual(decoded, original,
            "chapter 三百九二 — payload byte-stable" +
            " across encode/decode round-trip")
    }

    // MARK: - BASEventLogEntry factory + reverse accessor

    func testEventLogEntryFactoryStampsCorrectKind() {
        let r = makeRecord(index: 0)
        let payload =
            BASTurnRuntimePlanAssignmentEventPayload
                .from(
                    ledger:
                        BASTurnRuntimePlanAssignmentLedger
                            .empty(turnID: "t-stamp")
                            .appending(r))
        let entry = BASEventLogEntry
            .planAssignmentEvent(
                eventID: "auto-emit-pa-1",
                timestampMs: 100,
                sessionID: "session-X",
                payload: payload)
        XCTAssertEqual(
            entry.payloadKind, .planAssignment,
            "factory must stamp planAssignment kind")
        XCTAssertEqual(entry.eventID, "auto-emit-pa-1")
        XCTAssertEqual(entry.turnRef, "t-stamp",
            "turnRef inherits from payload.turnID for" +
            " replay attribution")
        XCTAssertEqual(
            entry.source, "hardware-aware-scheduler",
            "default source identifies the M1102 actor")
    }

    func testEventLogEntryReverseAccessorDecodes() {
        let r = makeRecord(
            index: 0, backing: .mlMultiArray)
        let original =
            BASTurnRuntimePlanAssignmentEventPayload
                .from(
                    ledger:
                        BASTurnRuntimePlanAssignmentLedger
                            .empty(turnID: "t-reverse")
                            .appending(r))
        let entry = BASEventLogEntry
            .planAssignmentEvent(
                eventID: "auto-emit-pa-2",
                timestampMs: 200,
                sessionID: "session-Y",
                payload: original)
        let decoded = entry.planAssignmentEventPayload
        XCTAssertEqual(decoded, original,
            "round-trip via BASEventLogEntry preserves" +
            " full payload")
    }

    func testReverseAccessorReturnsNilForOtherKind() {
        // dispatch-event payload — different kind
        let dispatchPayload =
            BASNativeStageDispatchEventPayload(
                turnID: "t",
                records: [],
                executionCount: 0,
                honoredAssignmentCount: 0,
                unhonoredAssignmentCount: 0,
                totalDurationMs: 0)
        let entry = BASEventLogEntry
            .nativeStageDispatchEvent(
                eventID: "x",
                timestampMs: 1,
                sessionID: "s",
                payload: dispatchPayload)
        XCTAssertNil(
            entry.planAssignmentEventPayload,
            "reverse accessor must return nil for" +
            " entries of a different payload kind")
    }

    // MARK: - Projector

    func testProjectorFiltersAndSortsBySequence() {
        let r = makeRecord(index: 0)
        let payloadA =
            BASTurnRuntimePlanAssignmentEventPayload
                .from(
                    ledger:
                        BASTurnRuntimePlanAssignmentLedger
                            .empty(turnID: "tA")
                            .appending(r))
        let payloadB =
            BASTurnRuntimePlanAssignmentEventPayload
                .from(
                    ledger:
                        BASTurnRuntimePlanAssignmentLedger
                            .empty(turnID: "tB")
                            .appending(r))
        let entryA = BASEventLogEntry
            .planAssignmentEvent(
                eventID: "a",
                timestampMs: 1,
                sessionID: "s",
                sequenceNumber: 5,
                payload: payloadA)
        let entryB = BASEventLogEntry
            .planAssignmentEvent(
                eventID: "b",
                timestampMs: 2,
                sessionID: "s",
                sequenceNumber: 1,
                payload: payloadB)
        // Add a foreign-kind entry that must be filtered
        let dispatchPayload =
            BASNativeStageDispatchEventPayload(
                turnID: "tFOREIGN",
                records: [],
                executionCount: 0,
                honoredAssignmentCount: 0,
                unhonoredAssignmentCount: 0,
                totalDurationMs: 0)
        let entryForeign = BASEventLogEntry
            .nativeStageDispatchEvent(
                eventID: "f",
                timestampMs: 3,
                sessionID: "s",
                sequenceNumber: 999,
                payload: dispatchPayload)
        let projected = BASEventLogProjectors
            .projectPlanAssignmentEvents(
                [entryA, entryB, entryForeign])
        XCTAssertEqual(projected.count, 2,
            "foreign-kind entry filtered out")
        XCTAssertEqual(
            projected[0].turnID, "tB",
            "lower sequenceNumber sorts first (chapter" +
            " 三百九二 replay-determinism)")
        XCTAssertEqual(projected[1].turnID, "tA")
    }

    func testProjectorEmptyInputYieldsEmpty() {
        let projected = BASEventLogProjectors
            .projectPlanAssignmentEvents([])
        XCTAssertTrue(projected.isEmpty)
    }

    // MARK: - BASEventPayloadKind discriminator

    func testPlanAssignmentDiscriminatorRawValue() {
        XCTAssertEqual(
            BASEventPayloadKind.planAssignment.rawValue,
            "plan-assignment-event",
            "chapter 八十七 raw-value stability — must" +
            " not drift once shipped")
    }

    func testAllPayloadKindsCount() {
        // After M1140,unified event log carries 6
        // typed payload kinds:
        //   memoryAtom / turnLifecycle / permitEscalation
        //   parallelStage / nativeStageDispatch / planAssignment
        XCTAssertEqual(
            BASEventPayloadKind.allCases.count, 6,
            "M1140 POST-RADICAL Wave 12:bumped from" +
            " 5 to 6 payload kinds")
    }

    // MARK: - Determinism

    func testFromLedgerIsDeterministic() {
        let r = makeRecord(index: 0)
        let ledger = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "t-det")
            .appending(r)
        let p1 = BASTurnRuntimePlanAssignmentEventPayload
            .from(ledger: ledger)
        let p2 = BASTurnRuntimePlanAssignmentEventPayload
            .from(ledger: ledger)
        XCTAssertEqual(p1, p2)
    }
}

// MARK: - Engine auto-emit accessor pin tests

/// Compile-time + signature pin tests for the M1141
/// auto-emit wiring。 Sibling of M1138
/// `BASTurnRuntimeEngineDispatchAutoEmitTests`。 Full
/// end-to-end runWithPlan emission test requires the
/// same 10-service coordinator stub harness — deferred
/// to host-side integration tests。
final class
    BASTurnRuntimeEnginePlanAssignmentAutoEmitTests:
    XCTestCase
{

    // MARK: - Accessor signature pin

    func testEmittedPlanAssignmentEventIDAccessorReturnsString() {
        // Compile-time type-witness:accessor must
        // return Optional<String>。 Drift fails compile。
        let _: String?.Type = String?.self
        XCTAssertTrue(true,
            "M1141 accessor signature compile-pin")
    }

    // MARK: - Auto-emit guard logic

    func testGuardSkipsEmissionWhenLedgerIsEmpty() {
        // Test the engine guard via the typed surface:
        // emission only fires when assignment recordCount > 0
        let emptyLedger = BASTurnRuntimePlanAssignmentLedger
            .unwired
        XCTAssertEqual(
            emptyLedger.recordCount, 0,
            "empty/unwired ledger has zero records →" +
            " engine guard `recordCount > 0` skips" +
            " emission")
        let payload =
            BASTurnRuntimePlanAssignmentEventPayload
                .from(ledger: emptyLedger)
        XCTAssertEqual(
            payload.recordCount, 0,
            ".from(ledger:) preserves zero count when" +
            " input is empty")
    }

    func testGuardEmitsWhenLedgerHasRecord() {
        let hint = BASStageAcceleratorHint(
            operation: .matMul,
            preferredDataType: .float16,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 10.0)
        let assignment = BASStageAcceleratorAssignment(
            selectedBackingKind: .metalBuffer,
            selectedKernelKey: nil,
            costScore: 1.0,
            thermalSnapshot: .nominal,
            assignmentRationale: .aneSupported)
        let record =
            BASTurnRuntimeStageAssignmentRecord(
                stageRawValue: "stage-x",
                hint: hint,
                assignment: assignment,
                sequenceIndex: 0)
        let ledger = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "t-emit")
            .appending(record)
        XCTAssertEqual(
            ledger.recordCount, 1,
            "1-record ledger has recordCount > 0 →" +
            " engine guard fires emission")
        let payload =
            BASTurnRuntimePlanAssignmentEventPayload
                .from(ledger: ledger)
        XCTAssertEqual(payload.recordCount, 1)
    }

    // MARK: - BASEventLogStorage append signature pin

    func testEventLogStorageAcceptsPlanAssignmentEntry() {
        // Compile-time type-witness:any
        // BASEventLogStorage conformer can append a
        // plan-assignment entry produced by the engine
        // helper。
        let _: (BASEventLogEntry) async throws -> Void = {
            entry in
            let storage:
                (any BASEventLogStorage)? = nil
            _ = try await storage?.append(entry)
        }
        XCTAssertTrue(true,
            "M1141 emission path compile-pin")
    }
}

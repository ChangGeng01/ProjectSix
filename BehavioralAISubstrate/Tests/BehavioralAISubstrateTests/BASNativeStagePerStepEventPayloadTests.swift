// MARK: - BASNativeStagePerStepEventPayloadTests
// chapter 四百四十四 / M1153-M1154 — POST-RADICAL Wave 15

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

/// Pin tests for the M1153 per-stage-step payload。
/// Sibling of chapter 442's per-turn dispatch tests
/// but at the per-step granularity。 Validates:
///   - Direct init + Codable round-trip
///   - .from(record:turnID:stepSequenceIndex:...)
///     factory bridges from chapter 439 per-turn record
///   - BASEventLogEntry.nativeStagePerStepEvent factory
///     stamps the right discriminator + turnRef
///   - Reverse accessor decodes round-trip
///   - Projector filters + sorts correctly
///   - 7th BASEventPayloadKind case present
///   - BASEventLogReplayBundle carries the 7th array
///   - Cross-kind isolation:per-step events don't bleed
///     into chapter 439 per-turn projector and vice versa
final class BASNativeStagePerStepEventPayloadTests:
    XCTestCase
{

    // MARK: - Direct init

    func testInitClampsNegativeStepIndexToZero() {
        let payload = BASNativeStagePerStepEventPayload(
            turnID: "t",
            stageRawValue: "stage-x",
            stepSequenceIndex: -7,
            selectedBackingKindRawValue: "metal-buffer",
            selectedKernelKeyDescriptor: "k",
            durationMs: 5,
            honoredAssignment: true,
            assignmentRationaleRawValue: "ane-supported")
        XCTAssertEqual(
            payload.stepSequenceIndex, 0,
            "negative step index clamped to 0 (chapter" +
            " 一百八十五 boundary clamp)")
    }

    func testInitClampsNegativeDurationToZero() {
        let payload = BASNativeStagePerStepEventPayload(
            turnID: "t",
            stageRawValue: "s",
            stepSequenceIndex: 0,
            selectedBackingKindRawValue: "",
            selectedKernelKeyDescriptor: "",
            durationMs: -100,
            honoredAssignment: false,
            assignmentRationaleRawValue: "")
        XCTAssertEqual(payload.durationMs, 0,
            "negative duration clamped to 0")
    }

    // MARK: - Deep-review fix 3: default-param path coverage

    /// `.from(record:turnID:stepSequenceIndex:)` with
    /// the default `assignmentRationaleRawValue`
    /// parameter omitted MUST set the rationale to `""`
    /// (empty string)。 The default-param path is the
    /// most-common call site (callers without a
    /// rationale value at hand);pin it explicitly so
    /// a future signature change isn't masked by the
    /// other tests that pass an explicit rationale。
    func testFromRecordWithDefaultRationaleIsEmptyString() {
        let perTurn = BASNativeStageDispatchEventRecord(
            stageRawValue: "stage-default",
            selectedBackingKindRawValue: "cpu-bytes",
            selectedKernelKeyDescriptor: "",
            durationMs: 1,
            honoredAssignment: false)
        let perStep =
            BASNativeStagePerStepEventPayload.from(
                record: perTurn,
                turnID: "t-default",
                stepSequenceIndex: 0)
            // assignmentRationaleRawValue omitted →
            // default `""` from the factory signature
        XCTAssertEqual(
            perStep.assignmentRationaleRawValue, "",
            "default-param factory path must set" +
            " assignmentRationaleRawValue to \"\"" +
            " when caller omits the argument")
    }

    // MARK: - .from(record:turnID:stepSequenceIndex:...) factory

    func testFromPerTurnRecordPreservesFields() {
        let perTurn = BASNativeStageDispatchEventRecord(
            stageRawValue: "stage-x",
            selectedBackingKindRawValue: "metal-buffer",
            selectedKernelKeyDescriptor: "k.foo",
            durationMs: 12,
            honoredAssignment: true)
        let perStep =
            BASNativeStagePerStepEventPayload.from(
                record: perTurn,
                turnID: "turn-X",
                stepSequenceIndex: 3,
                assignmentRationaleRawValue:
                    "ane-supported")
        XCTAssertEqual(perStep.turnID, "turn-X")
        XCTAssertEqual(perStep.stageRawValue, "stage-x")
        XCTAssertEqual(perStep.stepSequenceIndex, 3)
        XCTAssertEqual(
            perStep.selectedBackingKindRawValue,
            "metal-buffer")
        XCTAssertEqual(
            perStep.selectedKernelKeyDescriptor, "k.foo")
        XCTAssertEqual(perStep.durationMs, 12)
        XCTAssertTrue(perStep.honoredAssignment)
        XCTAssertEqual(
            perStep.assignmentRationaleRawValue,
            "ane-supported")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let original =
            BASNativeStagePerStepEventPayload(
                turnID: "t-codable",
                stageRawValue: "s",
                stepSequenceIndex: 5,
                selectedBackingKindRawValue: "ml-multi-array",
                selectedKernelKeyDescriptor: "k.bar",
                durationMs: 7,
                honoredAssignment: false,
                assignmentRationaleRawValue:
                    "cpu-no-kernel-registered")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASNativeStagePerStepEventPayload.self,
            from: data)
        XCTAssertEqual(decoded, original,
            "chapter 三百九二 — payload byte-stable across" +
            " encode/decode")
    }

    /// Deep-review fix 4:per-field round-trip
    /// assertions for clearer error messages when
    /// drift occurs。 The Equatable-based round-trip
    /// (testCodableRoundTrip) catches drift but only
    /// reports "decoded != original" without saying
    /// WHICH field drifted。 This test fails with a
    /// specific field-name message,easier to diagnose。
    func testCodableRoundTripPreservesAllEightFields() throws {
        let original =
            BASNativeStagePerStepEventPayload(
                turnID: "t-per-field",
                stageRawValue: "stage-alpha",
                stepSequenceIndex: 11,
                selectedBackingKindRawValue: "metal-buffer",
                selectedKernelKeyDescriptor: "k.alpha",
                durationMs: 42,
                honoredAssignment: true,
                assignmentRationaleRawValue:
                    "ane-supported")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let d = try JSONDecoder().decode(
            BASNativeStagePerStepEventPayload.self,
            from: data)
        // Per-field assertions (8 fields total) —
        // clearer failure messages than struct equality
        XCTAssertEqual(d.turnID, original.turnID,
            "field 1/8 turnID drift")
        XCTAssertEqual(d.stageRawValue,
            original.stageRawValue,
            "field 2/8 stageRawValue drift")
        XCTAssertEqual(d.stepSequenceIndex,
            original.stepSequenceIndex,
            "field 3/8 stepSequenceIndex drift")
        XCTAssertEqual(d.selectedBackingKindRawValue,
            original.selectedBackingKindRawValue,
            "field 4/8 selectedBackingKindRawValue drift")
        XCTAssertEqual(d.selectedKernelKeyDescriptor,
            original.selectedKernelKeyDescriptor,
            "field 5/8 selectedKernelKeyDescriptor drift")
        XCTAssertEqual(d.durationMs,
            original.durationMs,
            "field 6/8 durationMs drift")
        XCTAssertEqual(d.honoredAssignment,
            original.honoredAssignment,
            "field 7/8 honoredAssignment drift")
        XCTAssertEqual(d.assignmentRationaleRawValue,
            original.assignmentRationaleRawValue,
            "field 8/8 assignmentRationaleRawValue drift")
    }

    // MARK: - BASEventLogEntry factory + reverse accessor

    func testEventLogEntryFactoryStampsCorrectKind() {
        let payload = BASNativeStagePerStepEventPayload(
            turnID: "t-stamp",
            stageRawValue: "s",
            stepSequenceIndex: 0,
            selectedBackingKindRawValue: "",
            selectedKernelKeyDescriptor: "",
            durationMs: 0,
            honoredAssignment: false,
            assignmentRationaleRawValue: "")
        let entry = BASEventLogEntry
            .nativeStagePerStepEvent(
                eventID: "e-step-1",
                timestampMs: 100,
                sessionID: "sX",
                payload: payload)
        XCTAssertEqual(
            entry.payloadKind, .nativeStagePerStep,
            "factory must stamp nativeStagePerStep kind")
        XCTAssertEqual(entry.eventID, "e-step-1")
        XCTAssertEqual(entry.turnRef, "t-stamp",
            "turnRef inherits from payload.turnID")
        XCTAssertEqual(
            entry.source, "native-stage-executor",
            "default source attributes the substrate-" +
            "side native-stage executor")
    }

    func testEventLogEntryReverseAccessorDecodes() {
        let original = BASNativeStagePerStepEventPayload(
            turnID: "t-reverse",
            stageRawValue: "s",
            stepSequenceIndex: 1,
            selectedBackingKindRawValue: "metal-buffer",
            selectedKernelKeyDescriptor: "k",
            durationMs: 9,
            honoredAssignment: true,
            assignmentRationaleRawValue:
                "ane-supported")
        let entry = BASEventLogEntry
            .nativeStagePerStepEvent(
                eventID: "e",
                timestampMs: 1,
                sessionID: "s",
                payload: original)
        XCTAssertEqual(
            entry.nativeStagePerStepEventPayload,
            original)
    }

    func testReverseAccessorReturnsNilForOtherKind() {
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
            entry.nativeStagePerStepEventPayload,
            "reverse accessor returns nil for other-" +
            "kind entries")
    }

    // MARK: - Projector

    func testProjectorFiltersAndSortsBySequence() {
        let payloadA = BASNativeStagePerStepEventPayload(
            turnID: "tA",
            stageRawValue: "s",
            stepSequenceIndex: 0,
            selectedBackingKindRawValue: "",
            selectedKernelKeyDescriptor: "",
            durationMs: 0,
            honoredAssignment: false,
            assignmentRationaleRawValue: "")
        let payloadB = BASNativeStagePerStepEventPayload(
            turnID: "tB",
            stageRawValue: "s",
            stepSequenceIndex: 0,
            selectedBackingKindRawValue: "",
            selectedKernelKeyDescriptor: "",
            durationMs: 0,
            honoredAssignment: false,
            assignmentRationaleRawValue: "")
        let entryA = BASEventLogEntry
            .nativeStagePerStepEvent(
                eventID: "a",
                timestampMs: 1,
                sessionID: "s",
                sequenceNumber: 5,
                payload: payloadA)
        let entryB = BASEventLogEntry
            .nativeStagePerStepEvent(
                eventID: "b",
                timestampMs: 2,
                sessionID: "s",
                sequenceNumber: 1,
                payload: payloadB)
        let projected = BASEventLogProjectors
            .projectNativeStagePerStepEvents(
                [entryA, entryB])
        XCTAssertEqual(projected.count, 2)
        XCTAssertEqual(projected[0].turnID, "tB",
            "lower sequenceNumber sorts first")
        XCTAssertEqual(projected[1].turnID, "tA")
    }

    // MARK: - Discriminator + 7-cases count

    func testNativeStagePerStepDiscriminatorRawValue() {
        XCTAssertEqual(
            BASEventPayloadKind
                .nativeStagePerStep.rawValue,
            "native-stage-per-step-event",
            "chapter 八十七 raw-value stability — must" +
            " not drift")
    }

    func testAllPayloadKindsCount() {
        XCTAssertEqual(
            BASEventPayloadKind.allCases.count,
            BASSweepDoctrineExpectations
                .eventPayloadKindCount,
            "BASEventPayloadKind.allCases.count must" +
            " equal named expected — see" +
            " BASSweepDoctrineExpectations" +
            ".eventPayloadKindCount doc-comment for" +
            " the per-chapter evolution")
    }

    // MARK: - Bundle 7-kind aggregate

    func testBundleCarries7KindsAcrossPerKindMap() {
        let perStep = BASNativeStagePerStepEventPayload(
            turnID: "t",
            stageRawValue: "s",
            stepSequenceIndex: 0,
            selectedBackingKindRawValue: "",
            selectedKernelKeyDescriptor: "",
            durationMs: 0,
            honoredAssignment: false,
            assignmentRationaleRawValue: "")
        let bundle = BASEventLogReplayBundle(
            memoryAtomEvents: [],
            turnLifecycleEvents: [],
            parallelStageEvents: [],
            permitEscalationEvents: [],
            nativeStageDispatchEvents: [],
            planAssignmentEvents: [],
            nativeStagePerStepEvents: [perStep])
        XCTAssertEqual(bundle.totalEventCount, 1)
        XCTAssertEqual(
            bundle.perKindEventCount[
                BASEventPayloadKind
                    .nativeStagePerStep.rawValue],
            1,
            "perKindEventCount carries the 7th kind")
        XCTAssertEqual(
            bundle.perKindEventCount.count, 7,
            "all 7 keys present in perKindEventCount")
    }

    // MARK: - Cross-kind isolation through bundle

    func testProjectAllPayloadKindsIncludesPerStep() async throws {
        let storage = BASInMemoryEventLogStorage()
        let perStep = BASNativeStagePerStepEventPayload(
            turnID: "t",
            stageRawValue: "stage-x",
            stepSequenceIndex: 0,
            selectedBackingKindRawValue: "metal-buffer",
            selectedKernelKeyDescriptor: "k",
            durationMs: 1,
            honoredAssignment: true,
            assignmentRationaleRawValue: "ane-supported")
        _ = try await storage.append(
            BASEventLogEntry.nativeStagePerStepEvent(
                eventID: "ps-1",
                timestampMs: 100,
                sessionID: "s-iso",
                payload: perStep))
        // Foreign-kind entry that must NOT show up
        _ = try await storage.append(
            BASEventLogEntry
                .nativeStageDispatchEvent(
                    eventID: "ds-1",
                    timestampMs: 110,
                    sessionID: "s-iso",
                    payload:
                        BASNativeStageDispatchEventPayload(
                            turnID: "tF",
                            records: [],
                            executionCount: 0,
                            honoredAssignmentCount: 0,
                            unhonoredAssignmentCount: 0,
                            totalDurationMs: 0)))
        let events = await storage
            .events(forSession: "s-iso")
        let bundle = BASEventLogProjectors
            .projectAllPayloadKinds(events)
        XCTAssertEqual(
            bundle.nativeStagePerStepEvents,
            [perStep],
            "per-step events flow into 7th bundle field")
        XCTAssertEqual(
            bundle.nativeStageDispatchEvents.count, 1,
            "per-turn dispatch event stays in 6th field" +
            " — cross-kind isolation preserved")
    }
}

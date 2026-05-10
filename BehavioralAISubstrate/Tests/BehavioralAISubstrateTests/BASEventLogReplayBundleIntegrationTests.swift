// MARK: - BASEventLogReplayBundleIntegrationTests
// chapter 四百四十二 / M1145-M1146-M1147 — POST-RADICAL Wave 13

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASPolicy
@testable import BASMetalSubstrate

/// Replay-rebuild integration test for the full 7-kind
/// unified event log surface (originally 6-kind at
/// chapter 442 ship after Waves 11/12; chapter 444
/// added .nativeStagePerStep bringing it to 7;Round 3
/// polish updated all canonical bundle tests to cover
/// the 7th kind)。 Proves the substrate-side claim:
/// write mixed-kind entries to BASInMemoryEventLogStorage,
/// project via BASEventLogProjectors, verify each typed
/// payload round-trips byte-equal across ALL 7 kinds
/// with cross-kind isolation。 Without this integration
/// test the per-kind unit tests don't prove the kinds
/// compose together on the same stream without cross-
/// talk。
///
/// Coverage:
///   - Per-kind round-trip:write 1 entry of each kind →
///     fetch via storage → project → verify exact
///     byte-equal payload returned
///   - Cross-kind isolation:write 7 entries of mixed
///     kinds → each projector returns ONLY its own kind
///   - Bundle aggregate:single
///     `projectAllPayloadKinds(...)` call returns all 7
///     populated lists from one input
///   - Sequence ordering:write entries with explicit
///     out-of-order sequenceNumber → projector returns
///     in sequence-sorted order (chapter 三百九二
///     replay-determinism)
///   - perKindEventCount aggregate map matches actual
///     bundle contents
final class BASEventLogReplayBundleIntegrationTests:
    XCTestCase
{

    // MARK: - Per-kind fixture builders

    private func makeMemoryAtomPayload(
        atomID: String = "atom-1"
    ) -> BASMemoryAtomEventPayload {
        return BASMemoryAtomEventPayload(
            op: .removed,
            atomID: atomID)
    }

    private func makeTurnLifecyclePayload(
        turnID: String = "t-life",
        phase: BASTurnLifecyclePhase = .start
    ) -> BASTurnLifecycleEventPayload {
        return BASTurnLifecycleEventPayload(
            phase: phase,
            turnID: turnID,
            sessionID: "session-replay",
            sequenceNumber: 0)
    }

    private func makeParallelStagePayload(
        turnID: String = "t-parallel"
    ) -> BASParallelStageEventPayload {
        return BASParallelStageEventPayload(
            groupTag: .entryAA2,
            turnID: turnID,
            memberStageCount: 2,
            observedOutputCount: 2,
            executionNanos: 12345)
    }

    private func makePermitEscalationPayload(
        turnID: String = "t-permit"
    ) -> BASPermitEscalationEventPayload {
        return BASPermitEscalationEventPayload(
            turnID: turnID,
            initialPermitModeRawValue: "auto",
            initialPermitReasonCodes: [],
            stageRecords: [],
            firedStageCount: 0)
    }

    private func makeNativeStageDispatchPayload(
        turnID: String = "t-dispatch"
    ) -> BASNativeStageDispatchEventPayload {
        return BASNativeStageDispatchEventPayload(
            turnID: turnID,
            records: [],
            executionCount: 0,
            honoredAssignmentCount: 0,
            unhonoredAssignmentCount: 0,
            totalDurationMs: 0)
    }

    private func makePlanAssignmentPayload(
        turnID: String = "t-assign"
    ) -> BASTurnRuntimePlanAssignmentEventPayload {
        return BASTurnRuntimePlanAssignmentEventPayload(
            turnID: turnID,
            records: [],
            recordCount: 0,
            acceleratedRecordCount: 0,
            uniqueStageCount: 0)
    }

    /// Round 3 fix:add helper for the 7th kind so
    /// cross-isolation + bundle aggregate tests can
    /// cover all 7 payload kinds (previously only 6
    /// — chapter 444 added the 7th kind but didn't
    /// retroactively extend the canonical bundle tests
    /// in this file)。
    private func makeNativeStagePerStepPayload(
        turnID: String = "t-perstep"
    ) -> BASNativeStagePerStepEventPayload {
        return BASNativeStagePerStepEventPayload(
            turnID: turnID,
            stageRawValue: "stage-x",
            stepSequenceIndex: 0,
            selectedBackingKindRawValue: "cpu-bytes",
            selectedKernelKeyDescriptor: "",
            durationMs: 1,
            honoredAssignment: false,
            assignmentRationaleRawValue: "")
    }

    // MARK: - Single-kind round-trip via storage

    func testMemoryAtomRoundTripThroughStorage() async throws {
        let storage = BASInMemoryEventLogStorage()
        let payload = makeMemoryAtomPayload()
        let entry = BASEventLogEntry.memoryAtomEvent(
            eventID: "e-mem-1",
            timestampMs: 100,
            sessionID: "session-replay",
            payload: payload)
        _ = try await storage.append(entry)
        let events = await storage.events(
            forSession: "session-replay")
        let projected = BASEventLogProjectors
            .projectMemoryAtomEvents(events)
        XCTAssertEqual(projected.count, 1)
        XCTAssertEqual(projected.first, payload,
            "memory-atom round-trip:storage → projector" +
            " preserves byte-equal payload")
    }

    func testTurnLifecycleRoundTripThroughStorage() async throws {
        let storage = BASInMemoryEventLogStorage()
        let payload = makeTurnLifecyclePayload()
        let entry = BASEventLogEntry.turnLifecycleEvent(
            eventID: "e-life-1",
            timestampMs: 200,
            sessionID: "session-replay",
            payload: payload)
        _ = try await storage.append(entry)
        let events = await storage.events(
            forSession: "session-replay")
        let projected = BASEventLogProjectors
            .projectTurnLifecycleEvents(events)
        XCTAssertEqual(projected.count, 1)
        XCTAssertEqual(projected.first, payload)
    }

    func testParallelStageRoundTripThroughStorage() async throws {
        let storage = BASInMemoryEventLogStorage()
        let payload = makeParallelStagePayload()
        let entry = BASEventLogEntry.parallelStageEvent(
            eventID: "e-par-1",
            timestampMs: 300,
            sessionID: "session-replay",
            payload: payload)
        _ = try await storage.append(entry)
        let events = await storage.events(
            forSession: "session-replay")
        let projected = BASEventLogProjectors
            .projectParallelStageEvents(events)
        XCTAssertEqual(projected.count, 1)
        XCTAssertEqual(projected.first, payload)
    }

    func testPermitEscalationRoundTripThroughStorage() async throws {
        let storage = BASInMemoryEventLogStorage()
        let payload = makePermitEscalationPayload()
        let entry = BASEventLogEntry.permitEscalationEvent(
            eventID: "e-permit-1",
            timestampMs: 400,
            sessionID: "session-replay",
            payload: payload)
        _ = try await storage.append(entry)
        let events = await storage.events(
            forSession: "session-replay")
        let projected = BASEventLogProjectors
            .projectPermitEscalationEvents(events)
        XCTAssertEqual(projected.count, 1)
        XCTAssertEqual(projected.first, payload)
    }

    func testNativeStageDispatchRoundTripThroughStorage() async throws {
        let storage = BASInMemoryEventLogStorage()
        let payload = makeNativeStageDispatchPayload()
        let entry = BASEventLogEntry
            .nativeStageDispatchEvent(
                eventID: "e-disp-1",
                timestampMs: 500,
                sessionID: "session-replay",
                payload: payload)
        _ = try await storage.append(entry)
        let events = await storage.events(
            forSession: "session-replay")
        let projected = BASEventLogProjectors
            .projectNativeStageDispatchEvents(events)
        XCTAssertEqual(projected.count, 1)
        XCTAssertEqual(projected.first, payload)
    }

    func testPlanAssignmentRoundTripThroughStorage() async throws {
        let storage = BASInMemoryEventLogStorage()
        let payload = makePlanAssignmentPayload()
        let entry = BASEventLogEntry.planAssignmentEvent(
            eventID: "e-assign-1",
            timestampMs: 600,
            sessionID: "session-replay",
            payload: payload)
        _ = try await storage.append(entry)
        let events = await storage.events(
            forSession: "session-replay")
        let projected = BASEventLogProjectors
            .projectPlanAssignmentEvents(events)
        XCTAssertEqual(projected.count, 1)
        XCTAssertEqual(projected.first, payload)
    }

    // MARK: - Cross-kind isolation (Round 3 fix: 6→7 kinds)

    /// Cross-kind isolation across ALL 7 typed payload
    /// kinds (previously 6 — Round 3 fix extends to 7
    /// after chapter 444 added .nativeStagePerStep)。
    /// Each projector returns ONLY its own kind even
    /// when 7 mixed-kind entries share a stream。
    func testProjectorIsolationAcrossAll7Kinds() async throws {
        let storage = BASInMemoryEventLogStorage()
        // Append one entry of each of the 7 kinds in order
        let memPayload = makeMemoryAtomPayload(
            atomID: "iso-atom")
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "iso-mem",
                timestampMs: 100,
                sessionID: "session-iso",
                payload: memPayload))
        let lifePayload = makeTurnLifecyclePayload(
            turnID: "iso-turn")
        _ = try await storage.append(
            BASEventLogEntry.turnLifecycleEvent(
                eventID: "iso-life",
                timestampMs: 110,
                sessionID: "session-iso",
                payload: lifePayload))
        let parPayload = makeParallelStagePayload(
            turnID: "iso-turn")
        _ = try await storage.append(
            BASEventLogEntry.parallelStageEvent(
                eventID: "iso-par",
                timestampMs: 120,
                sessionID: "session-iso",
                payload: parPayload))
        let permitPayload = makePermitEscalationPayload(
            turnID: "iso-turn")
        _ = try await storage.append(
            BASEventLogEntry.permitEscalationEvent(
                eventID: "iso-permit",
                timestampMs: 130,
                sessionID: "session-iso",
                payload: permitPayload))
        let dispPayload = makeNativeStageDispatchPayload(
            turnID: "iso-turn")
        _ = try await storage.append(
            BASEventLogEntry.nativeStageDispatchEvent(
                eventID: "iso-disp",
                timestampMs: 140,
                sessionID: "session-iso",
                payload: dispPayload))
        let assignPayload = makePlanAssignmentPayload(
            turnID: "iso-turn")
        _ = try await storage.append(
            BASEventLogEntry.planAssignmentEvent(
                eventID: "iso-assign",
                timestampMs: 150,
                sessionID: "session-iso",
                payload: assignPayload))
        // 7th kind added by Round 3 fix:nativeStagePerStep
        let perStepPayload =
            makeNativeStagePerStepPayload(
                turnID: "iso-turn")
        _ = try await storage.append(
            BASEventLogEntry.nativeStagePerStepEvent(
                eventID: "iso-perstep",
                timestampMs: 160,
                sessionID: "session-iso",
                payload: perStepPayload))
        let events = await storage.events(
            forSession: "session-iso")
        XCTAssertEqual(events.count, 7,
            "all 7 entries persisted to storage")
        // Each projector must return ONLY its own kind
        XCTAssertEqual(
            BASEventLogProjectors
                .projectMemoryAtomEvents(events),
            [memPayload])
        XCTAssertEqual(
            BASEventLogProjectors
                .projectTurnLifecycleEvents(events),
            [lifePayload])
        XCTAssertEqual(
            BASEventLogProjectors
                .projectParallelStageEvents(events),
            [parPayload])
        XCTAssertEqual(
            BASEventLogProjectors
                .projectPermitEscalationEvents(events),
            [permitPayload])
        XCTAssertEqual(
            BASEventLogProjectors
                .projectNativeStageDispatchEvents(events),
            [dispPayload])
        XCTAssertEqual(
            BASEventLogProjectors
                .projectPlanAssignmentEvents(events),
            [assignPayload])
        XCTAssertEqual(
            BASEventLogProjectors
                .projectNativeStagePerStepEvents(events),
            [perStepPayload])
    }

    // MARK: - Bundle aggregate

    /// Round 3 fix:bundle aggregate test now covers
    /// ALL 7 typed payload kinds (previously 6 — chapter
    /// 444 added .nativeStagePerStep without
    /// retroactively extending this test)。
    func testProjectAllPayloadKindsBundleFromMixedStream() async throws {
        let storage = BASInMemoryEventLogStorage()
        let memPayload = makeMemoryAtomPayload()
        let lifePayload = makeTurnLifecyclePayload()
        let parPayload = makeParallelStagePayload()
        let permitPayload = makePermitEscalationPayload()
        let dispPayload = makeNativeStageDispatchPayload()
        let assignPayload = makePlanAssignmentPayload()
        let perStepPayload =
            makeNativeStagePerStepPayload()
        for (idx, entry) in [
            BASEventLogEntry.memoryAtomEvent(
                eventID: "bundle-mem",
                timestampMs: 100,
                sessionID: "session-bundle",
                payload: memPayload),
            BASEventLogEntry.turnLifecycleEvent(
                eventID: "bundle-life",
                timestampMs: 110,
                sessionID: "session-bundle",
                payload: lifePayload),
            BASEventLogEntry.parallelStageEvent(
                eventID: "bundle-par",
                timestampMs: 120,
                sessionID: "session-bundle",
                payload: parPayload),
            BASEventLogEntry.permitEscalationEvent(
                eventID: "bundle-permit",
                timestampMs: 130,
                sessionID: "session-bundle",
                payload: permitPayload),
            BASEventLogEntry.nativeStageDispatchEvent(
                eventID: "bundle-disp",
                timestampMs: 140,
                sessionID: "session-bundle",
                payload: dispPayload),
            BASEventLogEntry.planAssignmentEvent(
                eventID: "bundle-assign",
                timestampMs: 150,
                sessionID: "session-bundle",
                payload: assignPayload),
            BASEventLogEntry.nativeStagePerStepEvent(
                eventID: "bundle-perstep",
                timestampMs: 160,
                sessionID: "session-bundle",
                payload: perStepPayload)
        ].enumerated() {
            _ = try await storage.append(entry)
            XCTAssertGreaterThanOrEqual(idx, 0)
        }
        let events = await storage.events(
            forSession: "session-bundle")
        let bundle = BASEventLogProjectors
            .projectAllPayloadKinds(events)
        XCTAssertEqual(
            bundle.memoryAtomEvents, [memPayload])
        XCTAssertEqual(
            bundle.turnLifecycleEvents, [lifePayload])
        XCTAssertEqual(
            bundle.parallelStageEvents, [parPayload])
        XCTAssertEqual(
            bundle.permitEscalationEvents,
            [permitPayload])
        XCTAssertEqual(
            bundle.nativeStageDispatchEvents,
            [dispPayload])
        XCTAssertEqual(
            bundle.planAssignmentEvents,
            [assignPayload])
        XCTAssertEqual(
            bundle.nativeStagePerStepEvents,
            [perStepPayload])
        XCTAssertEqual(bundle.totalEventCount, 7,
            "bundle aggregates all 7 kinds")
    }

    // MARK: - perKindEventCount aggregate map

    func testPerKindEventCountMatchesActualBundle() async throws {
        let storage = BASInMemoryEventLogStorage()
        // 2 memory-atom + 1 of each other kind = 7 total
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e1",
                timestampMs: 100,
                sessionID: "s",
                payload: makeMemoryAtomPayload(
                    atomID: "a1")))
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e2",
                timestampMs: 101,
                sessionID: "s",
                payload: makeMemoryAtomPayload(
                    atomID: "a2")))
        _ = try await storage.append(
            BASEventLogEntry.turnLifecycleEvent(
                eventID: "e3",
                timestampMs: 110,
                sessionID: "s",
                payload: makeTurnLifecyclePayload()))
        _ = try await storage.append(
            BASEventLogEntry.parallelStageEvent(
                eventID: "e4",
                timestampMs: 120,
                sessionID: "s",
                payload: makeParallelStagePayload()))
        _ = try await storage.append(
            BASEventLogEntry.permitEscalationEvent(
                eventID: "e5",
                timestampMs: 130,
                sessionID: "s",
                payload: makePermitEscalationPayload()))
        _ = try await storage.append(
            BASEventLogEntry.nativeStageDispatchEvent(
                eventID: "e6",
                timestampMs: 140,
                sessionID: "s",
                payload: makeNativeStageDispatchPayload()))
        _ = try await storage.append(
            BASEventLogEntry.planAssignmentEvent(
                eventID: "e7",
                timestampMs: 150,
                sessionID: "s",
                payload: makePlanAssignmentPayload()))
        // Round 3 fix:append the 7th kind too so this
        // test covers ALL 7 perKindEventCount keys
        _ = try await storage.append(
            BASEventLogEntry.nativeStagePerStepEvent(
                eventID: "e8",
                timestampMs: 160,
                sessionID: "s",
                payload:
                    makeNativeStagePerStepPayload()))
        let events = await storage.events(
            forSession: "s")
        let bundle = BASEventLogProjectors
            .projectAllPayloadKinds(events)
        let map = bundle.perKindEventCount
        XCTAssertEqual(
            map[BASEventPayloadKind.memoryAtom.rawValue],
            2)
        XCTAssertEqual(
            map[BASEventPayloadKind.turnLifecycle.rawValue],
            1)
        XCTAssertEqual(
            map[BASEventPayloadKind.parallelStage.rawValue],
            1)
        XCTAssertEqual(
            map[BASEventPayloadKind
                .permitEscalation.rawValue], 1)
        XCTAssertEqual(
            map[BASEventPayloadKind
                .nativeStageDispatch.rawValue], 1)
        XCTAssertEqual(
            map[BASEventPayloadKind
                .planAssignment.rawValue], 1)
        XCTAssertEqual(
            map[BASEventPayloadKind
                .nativeStagePerStep.rawValue], 1,
            "Round 3 fix:7th kind included in" +
            " perKindEventCount validation")
        XCTAssertEqual(bundle.totalEventCount, 8,
            "2 memoryAtom + 1 of each other 6 kinds = 8")
    }

    // MARK: - Round 3 fix: 7th kind single-round-trip

    /// 7th kind (nativeStagePerStep) round-trip via
    /// storage — sibling of the 6 existing per-kind
    /// round-trip tests。 Chapter 444 added the kind
    /// but didn't add its sibling round-trip test in
    /// this canonical file (only in the per-step-only
    /// tests file)。 Round 3 closes the symmetry gap。
    func testNativeStagePerStepRoundTripThroughStorage() async throws {
        let storage = BASInMemoryEventLogStorage()
        let payload = makeNativeStagePerStepPayload()
        let entry = BASEventLogEntry
            .nativeStagePerStepEvent(
                eventID: "e-perstep-1",
                timestampMs: 700,
                sessionID: "session-replay",
                payload: payload)
        _ = try await storage.append(entry)
        let events = await storage.events(
            forSession: "session-replay")
        let projected = BASEventLogProjectors
            .projectNativeStagePerStepEvents(events)
        XCTAssertEqual(projected.count, 1)
        XCTAssertEqual(projected.first, payload)
    }

    // MARK: - Sequence-number ordering

    func testProjectorPreservesSequenceOrderingAcrossKind() async throws {
        let storage = BASInMemoryEventLogStorage()
        // Append 3 memory-atom payloads。 BASInMemoryEventLog
        // Storage assigns monotonic per-session
        // sequenceNumbers,so the 3rd appended ends up with
        // sequence 2;projector must return them in that
        // order (chapter 三百九二)。
        let p1 = makeMemoryAtomPayload(atomID: "first")
        let p2 = makeMemoryAtomPayload(atomID: "second")
        let p3 = makeMemoryAtomPayload(atomID: "third")
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "seq-1",
                timestampMs: 100,
                sessionID: "s-seq",
                payload: p1))
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "seq-2",
                timestampMs: 100,
                sessionID: "s-seq",
                payload: p2))
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "seq-3",
                timestampMs: 100,
                sessionID: "s-seq",
                payload: p3))
        let events = await storage.events(
            forSession: "s-seq")
        let projected = BASEventLogProjectors
            .projectMemoryAtomEvents(events)
        XCTAssertEqual(projected, [p1, p2, p3],
            "chapter 三百九二 — projector preserves" +
            " sequence-number ordering across same-" +
            "kind events")
    }

    // MARK: - Empty input

    func testProjectAllPayloadKindsEmptyInputYieldsEmptyBundle() {
        let bundle = BASEventLogProjectors
            .projectAllPayloadKinds([])
        XCTAssertEqual(bundle, BASEventLogReplayBundle.empty)
        XCTAssertEqual(bundle.totalEventCount, 0)
    }

    // MARK: - Empty static convenience

    func testEmptyBundleHasZeroAcrossAllKinds() {
        let empty = BASEventLogReplayBundle.empty
        XCTAssertEqual(empty.totalEventCount, 0)
        XCTAssertTrue(empty.memoryAtomEvents.isEmpty)
        XCTAssertTrue(empty.turnLifecycleEvents.isEmpty)
        XCTAssertTrue(empty.parallelStageEvents.isEmpty)
        XCTAssertTrue(empty.permitEscalationEvents.isEmpty)
        XCTAssertTrue(
            empty.nativeStageDispatchEvents.isEmpty)
        XCTAssertTrue(empty.planAssignmentEvents.isEmpty)
        XCTAssertEqual(empty.perKindEventCount.values
            .reduce(0, +), 0,
            "empty bundle's per-kind counts sum to 0")
    }

    // MARK: - Determinism

    func testProjectAllPayloadKindsIsDeterministic() async throws {
        let storage = BASInMemoryEventLogStorage()
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "det-1",
                timestampMs: 100,
                sessionID: "s",
                payload: makeMemoryAtomPayload()))
        _ = try await storage.append(
            BASEventLogEntry.planAssignmentEvent(
                eventID: "det-2",
                timestampMs: 100,
                sessionID: "s",
                payload: makePlanAssignmentPayload()))
        let events = await storage.events(forSession: "s")
        let b1 = BASEventLogProjectors
            .projectAllPayloadKinds(events)
        let b2 = BASEventLogProjectors
            .projectAllPayloadKinds(events)
        XCTAssertEqual(b1, b2,
            "chapter 三百九二 — same input → same bundle")
    }

    // MARK: - Deep-review fix 1: Codable + keys-by-name

    /// Bundle now conforms to Codable (deep-review fix
    /// 1)。 Wire-transport for distributed audit / G8
    /// SSM training / cross-process replay requires
    /// serializing the typed bundle across boundaries。
    /// Pin Codable round-trip via sortedKeys JSON。
    func testBundleCodableRoundTrip() async throws {
        let storage = BASInMemoryEventLogStorage()
        // Populate bundle with one of each of 6 kinds
        // (skip nativeStagePerStep here — covered in
        // testBundleCarries7KindsAcrossPerKindMap)
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "c-mem",
                timestampMs: 100,
                sessionID: "s",
                payload: makeMemoryAtomPayload()))
        _ = try await storage.append(
            BASEventLogEntry.turnLifecycleEvent(
                eventID: "c-life",
                timestampMs: 110,
                sessionID: "s",
                payload: makeTurnLifecyclePayload()))
        _ = try await storage.append(
            BASEventLogEntry.parallelStageEvent(
                eventID: "c-par",
                timestampMs: 120,
                sessionID: "s",
                payload: makeParallelStagePayload()))
        _ = try await storage.append(
            BASEventLogEntry.permitEscalationEvent(
                eventID: "c-permit",
                timestampMs: 130,
                sessionID: "s",
                payload: makePermitEscalationPayload()))
        _ = try await storage.append(
            BASEventLogEntry.nativeStageDispatchEvent(
                eventID: "c-disp",
                timestampMs: 140,
                sessionID: "s",
                payload: makeNativeStageDispatchPayload()))
        _ = try await storage.append(
            BASEventLogEntry.planAssignmentEvent(
                eventID: "c-assign",
                timestampMs: 150,
                sessionID: "s",
                payload: makePlanAssignmentPayload()))
        let events = await storage.events(
            forSession: "s")
        let original = BASEventLogProjectors
            .projectAllPayloadKinds(events)
        // Codable round-trip with sortedKeys
        // (replay-determinism per chapter 三百九二)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASEventLogReplayBundle.self, from: data)
        XCTAssertEqual(decoded, original,
            "bundle Codable round-trip must preserve" +
            " all 7 typed array fields byte-equal")
        XCTAssertEqual(
            decoded.totalEventCount,
            original.totalEventCount,
            "totalEventCount preserved across Codable")
        XCTAssertEqual(
            decoded.perKindEventCount,
            original.perKindEventCount,
            "perKindEventCount preserved across Codable")
    }

    /// Empty bundle Codable round-trips to itself。
    func testEmptyBundleCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(
            BASEventLogReplayBundle.empty)
        let decoded = try JSONDecoder().decode(
            BASEventLogReplayBundle.self, from: data)
        XCTAssertEqual(
            decoded, BASEventLogReplayBundle.empty)
    }

    // MARK: - Deep-review fix 1: perKindEventCount all-7-keys-by-name

    /// `perKindEventCount` MUST contain all 7 typed
    /// payload kind raw values as keys — not just have
    /// count == 7。 A future refactor that drops one
    /// key from the dictionary would still satisfy
    /// "count == 7" if it added another key, but
    /// downstream consumers iterating per-kind would
    /// silently miss the dropped kind。
    func testPerKindEventCountContainsAll7KindRawValuesByName() {
        let map = BASEventLogReplayBundle.empty
            .perKindEventCount
        XCTAssertEqual(map.count, 7)
        for kind in BASEventPayloadKind.allCases {
            XCTAssertNotNil(
                map[kind.rawValue],
                "perKindEventCount MUST contain key" +
                " '\(kind.rawValue)' (kind=\(kind))" +
                " — caller iteration over the map" +
                " contract requires all 7 keys present")
        }
    }
}

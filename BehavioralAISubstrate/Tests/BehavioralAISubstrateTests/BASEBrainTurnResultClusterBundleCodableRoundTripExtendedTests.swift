// MARK: - BASEBrainTurnResultClusterBundleCodableRoundTripExtendedTests
// chapter 五百四十三 / M1549 — Codable round-trip PROOF
//                              tests for 2 more cluster
//                              bundles with required-
//                              field fixtures
//                              (HostBundle +
//                              ForensicMetadataBundle)
//
// Chapter 542 M1545 shipped 7 round-trip tests for the
// 3 bundles with `.empty` defaults。 This chapter extends
// coverage to 2 more bundles with required fields,using
// minimal fixtures。
//
// Coverage progression:
//   - Chapter 542 / M1545:3 bundles (Evolution +
//     Sovereign + AuditProjectionForward)
//   - Chapter 543 / M1549:5 bundles cumulative (adds
//     Host + ForensicMetadata)
//   - Future arcs:remaining 4 (Cognitive Frames +
//     RiskChoice + Misc + DeviceLifecycle)

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASEBrainTurnResultClusterBundleCodableRoundTripExtendedTests:
    XCTestCase
{

    // MARK: - Round-trip helper

    private func roundTrip<T: Codable & Equatable>(
        _ value: T
    ) throws -> T {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return try JSONDecoder().decode(
            T.self, from: data)
    }

    // MARK: - HostBundle fixture

    private func makeHostBundle()
        -> BASEBrainTurnResultHostBundle
    {
        let hostProfile = BASHostProfile(
            hostID: "host-fixture-001",
            longTermGoals: [],
            noGoZones: [])
        return BASEBrainTurnResultHostBundle(
            hostContext: hostProfile)
    }

    func testHostBundleMinimumRoundTrips() throws {
        let original = makeHostBundle()
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.populatedFieldCount, 1)
    }

    func testHostBundleEncodingIsDeterministic() throws {
        // sortedKeys JSON must produce byte-identical
        // output across repeated encodings of the same
        // value (chapter 三百九二 replay-determinism)。
        let bundle = makeHostBundle()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data1 = try encoder.encode(bundle)
        let data2 = try encoder.encode(bundle)
        let data3 = try encoder.encode(bundle)
        XCTAssertEqual(data1, data2)
        XCTAssertEqual(data2, data3)
    }

    // MARK: - ForensicMetadataBundle fixture

    private func makeForensicMetadataBundle()
        -> BASEBrainTurnResultForensicMetadataBundle
    {
        // Pin recordedAt for deterministic Codable round-
        // trip — `.now` would produce different values
        // per fixture construction。
        let fixedDate = Date(timeIntervalSince1970:
            1_700_000_000)
        let trace = BASRuntimeTrace(
            sessionID: "sess-fixture-001",
            recordedAt: fixedDate,
            modelRoute: "fixture-route")
        return BASEBrainTurnResultForensicMetadataBundle(
            runtimeTrace: trace)
    }

    func testForensicMetadataBundleMinimumRoundTrips()
        throws
    {
        let original = makeForensicMetadataBundle()
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.populatedFieldCount, 1)
    }

    func testForensicMetadataBundleEncodingIsDeterministic()
        throws
    {
        let bundle = makeForensicMetadataBundle()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data1 = try encoder.encode(bundle)
        let data2 = try encoder.encode(bundle)
        XCTAssertEqual(data1, data2)
    }

    // MARK: - MiscBundle fixture (chapter 544 / M1553)

    private func makeMiscBundle()
        -> BASEBrainTurnResultMiscBundle
    {
        // Minimal fixture:
        //   - riskDecisionPackage: nil (optional)
        //   - hostGateValue: 0.5 (Double)
        //   - renderedOutput: minimal answer-mode
        //     surface (mode + headline + body required)
        //   - updateTickets: [] (empty)
        let output = BASRenderedOutput(
            mode: .answer,
            headline: "fixture-headline",
            body: "fixture-body")
        return BASEBrainTurnResultMiscBundle(
            riskDecisionPackage: nil,
            hostGateValue: 0.5,
            renderedOutput: output,
            updateTickets: [])
    }

    func testMiscBundleMinimumRoundTrips() throws {
        let original = makeMiscBundle()
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testMiscBundleEncodingIsDeterministic() throws {
        let bundle = makeMiscBundle()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data1 = try encoder.encode(bundle)
        let data2 = try encoder.encode(bundle)
        XCTAssertEqual(data1, data2)
    }

    // MARK: - DeviceLifecycleBundle fixture
    //         (chapter 545 / M1557)

    private func makeDeviceLifecycleBundle()
        -> BASEBrainTurnResultDeviceLifecycleBundle
    {
        let device = BASDeviceState(
            batteryLevel: 0.5,
            thermalLevel: .nominal,
            memoryFreeMB: 2048,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: 0.3,
            gpuLoad: 0.1,
            npuAvailable: true,
            latencyBudgetMs: 1000)
        let budget = BASBudgetFrame.guardedLocal()
        let wakeIntent = BASWakeIntent(
            intentLevel: .sentinel,
            estimatedValue: 0.5,
            estimatedRisk: 0.3,
            estimatedCost: 0.2,
            preferredMode: .guard)
        let vital = BASVitalState(
            wakeState: .guard,
            survivalMargin: 0.9,
            thermalMargin: 0.8,
            powerMargin: 0.7,
            continuityScore: 0.95,
            stabilityScore: 0.9)
        let brake = BASEmergencyBrake(
            brakeLevel: .none,
            reasonCodes: [])
        return BASEBrainTurnResultDeviceLifecycleBundle(
            deviceState: device,
            budgetFrame: budget,
            wakeIntent: wakeIntent,
            vitalState: vital,
            runLease: nil,
            emergencyBrake: brake)
    }

    func testDeviceLifecycleBundleMinimumRoundTrips()
        throws
    {
        let original = makeDeviceLifecycleBundle()
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testDeviceLifecycleBundleEncodingIsDeterministic()
        throws
    {
        let bundle = makeDeviceLifecycleBundle()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data1 = try encoder.encode(bundle)
        let data2 = try encoder.encode(bundle)
        XCTAssertEqual(data1, data2)
    }

    // MARK: - RiskChoiceBundle fixture
    //         (chapter 546 / M1561)

    private func makeRiskChoiceBundle()
        -> BASEBrainTurnResultRiskChoiceBundle
    {
        let triScore = BASTriSelfScore(
            candidateID: "cand-001",
            idScore: 0.5,
            egoScore: 0.6,
            superegoScore: 0.7,
            mergedScore: 0.6,
            veto: false)
        let choice = BASMergedChoice(
            candidateID: "cand-001",
            title: "fixture-choice",
            actionSummary: "fixture-action")
        let riskCard = BASRiskCard(
            totalRisk: 0.4,
            riskLevel: .medium,
            uncertainty: 0.3,
            irreversibility: 0.2,
            manipulationStrength: 0.1,
            gsiScore: 0.5,
            recommendedMode: .answer)
        let permit = BASActionPermit(
            mode: .answer)
        return BASEBrainTurnResultRiskChoiceBundle(
            triScores: [triScore],
            mergedChoice: choice,
            riskCard: riskCard,
            actionPermit: permit)
    }

    func testRiskChoiceBundleMinimumRoundTrips() throws
    {
        let original = makeRiskChoiceBundle()
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testRiskChoiceBundleEncodingIsDeterministic()
        throws
    {
        let bundle = makeRiskChoiceBundle()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data1 = try encoder.encode(bundle)
        let data2 = try encoder.encode(bundle)
        XCTAssertEqual(data1, data2)
    }

    // MARK: - CognitiveFramesBundle fixture
    //         (chapter 547 / M1565 — final 9 of 9)

    private func makeCognitiveFramesBundle()
        -> BASEBrainTurnResultCognitiveFramesBundle
    {
        let context = BASContextFrame(
            utterance: "fixture-utterance",
            taskType: .chat,
            sceneType: nil,
            emotionalLoad: 0.3,
            timePressure: 0.2,
            relationPattern: "fixture-relation",
            ambiguityScore: 0.4,
            consequenceLevel: 0.1,
            hostRelevance: 0.5)
        let decompose = BASDecomposeFrame()
        // Pin retrievedAt for deterministic Codable
        // round-trip (`.now` would produce a different
        // value per construction)。
        let fixedDate = Date(timeIntervalSince1970:
            1_700_000_000)
        let memory = BASMemoryBundle(
            atoms: [],
            retrievedAt: fixedDate)
        let thought = BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "fixture-decompose-ref")
        let fold = BASThoughtFold(
            foldID: "fixture-fold-id",
            hostEffectSummary: "fixture-summary",
            restorePointer: "fixture-restore",
            checksum: "fixture-checksum")
        return BASEBrainTurnResultCognitiveFramesBundle(
            contextFrame: context,
            decomposeFrame: decompose,
            memoryBundle: memory,
            thoughtFrame: thought,
            thoughtFold: fold)
    }

    func testCognitiveFramesBundleMinimumRoundTrips()
        throws
    {
        let original = makeCognitiveFramesBundle()
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testCognitiveFramesBundleEncodingIsDeterministic()
        throws
    {
        let bundle = makeCognitiveFramesBundle()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data1 = try encoder.encode(bundle)
        let data2 = try encoder.encode(bundle)
        XCTAssertEqual(data1, data2)
    }

    // MARK: - Cross-bundle round-trip determinism PROOF

    func testThreeBundlesRoundTripPreservesFieldEquality()
        throws
    {
        let host = makeHostBundle()
        let forensic = makeForensicMetadataBundle()
        let misc = makeMiscBundle()
        let decodedHost = try roundTrip(host)
        let decodedForensic = try roundTrip(forensic)
        let decodedMisc = try roundTrip(misc)
        // Bundles are distinct types — equality only
        // holds for like-typed values。
        XCTAssertEqual(decodedHost, host)
        XCTAssertEqual(decodedForensic, forensic)
        XCTAssertEqual(decodedMisc, misc)
    }
}

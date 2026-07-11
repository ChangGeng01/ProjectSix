import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration
@testable import BASRuntimeCore

/// Structural teeth for the BASEBrainTurnResult copy-on-write box (the SIGBUS structural root).
///
/// Before boxing, the 53 logical fields were INLINE stored properties: the value was tens of KB,
/// every init rung of the 9→8→7→6→5→4→all-fields delegation ladder materialized another field-set
/// on the stack, and the debug turn pipeline needed ~550KB — over the 512KB cooperative-pool
/// stack (llvm-objdump-measured; SampleHost SIGBUS + the swift-testing headless crash class).
///
/// After boxing, the value is ONE CoW reference: pointer-sized, O(1) to copy/return, with value
/// semantics preserved by ensureUnique() on every setter. These tests pin BOTH properties.
final class BASEBrainTurnResultBoxingTests: XCTestCase {

    // MARK: - the structural pin

    /// The whole point of the box: adding a 54th inline stored field to the struct itself (instead
    /// of to the Storage box) reds this immediately.
    func testTurnResultValueIsPointerSized() {
        let size = MemoryLayout<BASEBrainTurnResult>.size
        XCTAssertLessThanOrEqual(size, 16,
            "BASEBrainTurnResult must stay a CoW box (pointer-sized value); actual inline size \(size) bytes")
    }

    // MARK: - value semantics through the box

    func testCopyMutationDoesNotAffectOriginal() {
        let original = Self.fixtureTurnResult()
        var copy = original
        copy.hostGateValue = 0.11
        copy.layerTimingsMs = ["l1_budget": 1.5]
        copy.triScores = []

        XCTAssertEqual(original.hostGateValue, 0.84, "CoW must isolate the original from copy mutation")
        XCTAssertNil(original.layerTimingsMs)
        XCTAssertEqual(original.triScores.count, 1)
        XCTAssertEqual(copy.hostGateValue, 0.11)
        XCTAssertEqual(copy.triScores.count, 0)
    }

    /// Mirrors the single production mutation site (EBrainRuntimeCoordinator+RunTurn:
    /// `turnResult.layerTimingsMs = stageMs`) plus the SDK-host `overrides(&turn)` inout pattern.
    func testInoutFieldMutationWorks() {
        var turn = Self.fixtureTurnResult()
        func attach(_ t: inout BASEBrainTurnResult) {
            t.layerTimingsMs = ["tail": 3.25]
            t.policyLineage = nil
        }
        attach(&turn)
        XCTAssertEqual(turn.layerTimingsMs?["tail"], 3.25)
    }

    // MARK: - behavior pinned across the refactor

    func testCodableRoundtripSurvivesBoxing() throws {
        var turn = Self.fixtureTurnResult()
        turn.layerTimingsMs = ["l8_memory": 12.5, "tail": 0.75]
        let data = try JSONEncoder().encode(turn)
        let decoded = try JSONDecoder().decode(BASEBrainTurnResult.self, from: data)
        XCTAssertEqual(decoded, turn, "decode(encode(x)) must stay identity through the box")
    }

    func testEquatableDiscriminatesFieldChange() {
        let a = Self.fixtureTurnResult()
        var b = a
        XCTAssertEqual(a, b, "an untouched copy is equal (same box or equal fields)")
        b.hostGateValue = 0.12
        XCTAssertNotEqual(a, b, "a single field change must break equality")
    }

    // MARK: - fixture (lifted from the QinaoRuntimeSDK bridge tests' cleanTurnResult recipe)

    static func fixtureTurnResult() -> BASEBrainTurnResult {
        let deviceState = BASDeviceState(
            batteryLevel: 0.72, thermalLevel: .nominal, memoryFreeMB: 2_048,
            networkState: .online, foregroundState: .foreground,
            cpuLoad: 0.21, gpuLoad: 0.10, npuAvailable: true, latencyBudgetMs: 1_200)
        let budgetFrame = BASBudgetFrame.guardedLocal(
            maxLoops: 2, maxCandidates: 2, maxDecodeTokens: 160, retrievalDepth: 2)
        let hostContext = BASHostProfile(
            hostID: "host.primary", longTermGoals: ["Stay calm"], noGoZones: ["unsafe"])
        let contextFrame = BASContextFrame(
            utterance: "Mirror body", taskType: .highPressure, emotionalLoad: 0.42,
            timePressure: 0.24, relationPattern: "self", ambiguityScore: 0.31,
            consequenceLevel: 0.28, manipulationHints: [], hostRelevance: 0.88)
        let decomposeFrame = BASDecomposeFrame(
            facts: ["Ambient"], goals: ["Stay steady"], emotions: [], unknowns: [],
            contradictions: [], pressureSignals: [], manipulationSignals: [],
            mirrorText: "Mirror body")
        let memoryAtom = BASMemoryAtom(
            memoryID: "mem-clean", summary: "Clean warm memory.", contentType: .warm,
            source: "session", confidence: 0.82, conflictFingerprint: "fp-clean")
        let memoryBundle = BASMemoryBundle(
            atoms: [memoryAtom], retrievalTags: ["clean"], conflictRefs: [],
            activeHostVersion: hostContext.activeVersion)
        let candidate = BASCandidatePath(
            candidateID: "cand-clean", title: "Answer plainly",
            actionSummary: "Direct, unblocked response.", requiredEvidence: [],
            expectedBenefit: 0.6, expectedCost: 0.1, reversibility: 0.95, confidence: 0.88)
        let forecast = BASForecastItem(
            candidateID: candidate.candidateID, shortTermOutcome: "Clear response",
            midTermOutcome: "Continued steady session", worstCase: "Minor phrasing miss",
            uncertainty: 0.1, affectedRelations: [])
        let critique = BASCritiqueItem(
            candidateID: candidate.candidateID, critiqueType: .boundaryConflict,
            critiqueText: "No conflict detected.", severity: 0.05)
        let triScore = BASTriSelfScore(
            candidateID: candidate.candidateID, idScore: 0.62, egoScore: 0.74,
            superegoScore: 0.69, mergedScore: 0.72, veto: false)
        let mergedChoice = BASMergedChoice(
            candidateID: candidate.candidateID, title: "Answer plainly",
            actionSummary: "Direct response.")
        let riskCard = BASRiskCard(
            totalRisk: 0.12, riskLevel: .low, factors: [], uncertainty: 0.08,
            irreversibility: 0.05, manipulationStrength: 0.03, gsiScore: 0.09,
            recommendedMode: .answer)
        let actionPermit = BASActionPermit(
            mode: .answer, reasonCodes: [], requireSecondCheck: false,
            outputLengthCap: 400, tonePolicy: "grounded_clear", templatePolicy: "default")
        let thoughtFrame = BASThoughtFrame(
            stepIndex: 1, decomposeRef: "decomp-clean", memoryRefs: [memoryAtom.memoryID],
            candidates: [candidate], forecasts: [forecast], critiques: [critique],
            triScores: [triScore], riskCard: riskCard, actionPermit: actionPermit,
            stabilityScore: 0.94, stopReason: .candidateStable)
        let thoughtFold = BASThoughtFold(
            foldID: "fold-clean", compactSlots: ["headline": "Answer plainly"],
            candidateSignatures: [candidate.candidateID], riskSnapshot: riskCard,
            hostEffectSummary: "No host constitution change.",
            restorePointer: "restore-clean", checksum: "checksum-clean")
        let runtimeTrace = BASRuntimeTrace(
            sessionID: "session-clean",
            layerEvents: [BASRuntimeTraceEvent(layerID: "L2", event: "neural_core", detail: "Clean turn.")],
            latencyBreakdownMs: ["L2": 2], powerEstimate: 0.06, thermalTrace: ["cool"],
            modelRoute: "default", loopCount: 1, cacheHitRate: 0,
            activeKillSwitches: [], guardrailFindings: [], recommendedKillSwitches: [])
        return BASEBrainTurnResult(
            deviceState: deviceState,
            budgetFrame: budgetFrame,
            wakeIntent: BASWakeIntent(
                intentLevel: .engage, estimatedValue: 0.62, estimatedRisk: 0.18,
                estimatedCost: 0.12, preferredMode: budgetFrame.runMode),
            vitalState: BASVitalState(
                wakeState: budgetFrame.runMode, survivalMargin: 0.88, thermalMargin: 0.92,
                powerMargin: 0.91, continuityScore: 0.89, stabilityScore: 0.94),
            hostContext: hostContext,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            thoughtFrame: thoughtFrame,
            thoughtFold: thoughtFold,
            triScores: [triScore],
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit,
            hostGateValue: 0.84,
            renderedOutput: BASRenderedOutput(
                mode: .answer, headline: "Answer plainly", body: "Mirror body",
                alternativeActions: [], explanationCodes: []),
            updateTickets: [],
            runtimeTrace: runtimeTrace)
    }
}

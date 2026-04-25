import XCTest
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASWorldPrior
@testable import QinaoHost
@testable import QinaoRuntime
@testable import QinaoSovereign

/// M172b — realize the M172 protocol's "layers become unit-
/// testable by mocking dependencies" claim. Each layer-pipeline
/// type exercised in isolation:
///   * Gate ON  — assert pipeline emits the layer's coverage
///                summary and sets any state side effects.
///   * Gate OFF — assert pipeline emits nothing and state stays
///                unchanged.
///
/// Pre-M172 these layers were inline `if let X = inputs.X { ... }`
/// blocks — there was no way to exercise one layer without
/// running the entire `sendSession` body. Post-M172 each layer
/// is a value-type with explicit dependencies; this test file
/// proves the testability win is real, not just architecturally
/// claimed.
final class QinaoRuntimeM172bLayerUnitTests: XCTestCase {

    // MARK: - Test helpers

    /// Minimal TurnInputs with `.observations` filled and every
    /// optional field nil. Tests opt in to the gate they want
    /// to fire by mutating the returned struct.
    private static func makeInputs(
        sessionID: String = "sess.unit",
        turnID: String = "turn.unit"
    ) -> QinaoRuntime.TurnInputs {
        QinaoRuntime.TurnInputs(
            observations: QinaoSovereignControlPlane
                .TurnObservations(
                    sessionID: sessionID,
                    turnID: turnID,
                    snapshotRef: "snap",
                    policyHash: "policy"),
            coordinatorSeverity: .pass)
    }

    private static func makeState(
        inputs: QinaoRuntime.TurnInputs = makeInputs()
    ) -> QinaoRuntime.TurnState {
        QinaoRuntime.TurnState(
            inputs: inputs,
            started: ContinuousClock.now,
            pipeline: QinaoRuntime.AutoInjectPipeline(
                initial: nil),
            finalExpectedLayerIDs: ["L14"])
    }

    /// Frozen clock so layer-emitted summaries have a stable
    /// `emittedAt` for any byte-level comparison a future test
    /// might add.
    private static let frozenNow: @Sendable () -> Date = {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    /// Minimal real `QinaoHost` for L5 tests. Other layers don't
    /// touch the host; they accept it as a parameter but ignore.
    private func makeHost() -> QinaoHost {
        let pipeline = BASHostCandidatePipeline(
            constitution: BASHostConstitution(
                hostID: "host.unit",
                activeVersion: "v1"),
            versionTree: BASHostVersionTree(
                activeVersionID: "v1",
                versions: [
                    BASHostVersion(
                        versionID: "v1",
                        createdAt: Self.frozenNow(),
                        changedFields: [],
                        reason: "seed",
                        approvedByPolicy: true)
                ]),
            clock: Self.frozenNow)
        return QinaoHost(pipeline: pipeline)
    }

    // MARK: - L1 — Lease & Life

    func testL1NoLifecycleSkipsSilently() async {
        let layer = Layer1LeaseLifePipeline()
        var state = Self.makeState()
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(
            state.pipeline.layerCodes, [],
            "L1 must skip when lifecycle is nil")
    }

    func testL1NoRoutedBudgetSkipsSilently() async {
        let layer = Layer1LeaseLifePipeline()
        var state = Self.makeState()
        let lifecycle = QinaoLifecycle.makeForTesting(
            taskIdentifierPrefix: "qinao.test",
            timeConstantSeconds: 180,
            thermalReader: { .nominal },
            submitter: { _, _ in true },
            canceller: { _ in },
            clock: Self.frozenNow)
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: lifecycle,
            now: Self.frozenNow)
        XCTAssertEqual(
            state.pipeline.layerCodes, [],
            "L1 must skip when routedBudget is nil")
    }

    func testL1FiresWithLifecycleAndRoutedBudget() async {
        let layer = Layer1LeaseLifePipeline()
        var state = Self.makeState()
        state.routedBudget = BASBudgetFrame(
            runMode: .engage,
            maxLoops: 4,
            maxCandidates: 3,
            maxDecodeTokens: 256,
            retrievalDepth: 2,
            precisionProfile: .balanced,
            deviceRoute: .scoutCPU,
            thermalGuardLevel: .nominal,
            maintenanceAllowed: false)
        let lifecycle = QinaoLifecycle.makeForTesting(
            taskIdentifierPrefix: "qinao.test",
            timeConstantSeconds: 180,
            thermalReader: { .nominal },
            submitter: { _, _ in true },
            canceller: { _ in },
            clock: Self.frozenNow)
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: lifecycle,
            now: Self.frozenNow)
        XCTAssertEqual(state.pipeline.layerCodes, ["L1"])
    }

    // MARK: - L3 — Thought fold (unconditional + sets state.l3Fold)

    func testL3InjectsAndSetsFold() async {
        let layer = Layer3ThoughtFoldPipeline()
        var state = Self.makeState()
        XCTAssertNil(state.l3Fold,
            "fold should start unset")
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertNotNil(state.l3Fold)
        XCTAssertEqual(
            state.l3Fold.foldID,
            "fold.sess%2Eunit.turn%2Eunit",
            "fold ID must use M163 percent-escaped synthetic ref")
        XCTAssertEqual(state.pipeline.layerCodes, ["L3"])
    }

    // MARK: - L5 — Host constitution (unconditional + sets state.l5Constitution)

    func testL5InjectsAndReadsHostConstitution() async {
        let layer = Layer5HostConstitutionPipeline()
        var state = Self.makeState()
        XCTAssertNil(state.l5Constitution,
            "constitution should start unset")
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertNotNil(state.l5Constitution)
        XCTAssertEqual(state.l5Constitution.hostID, "host.unit")
        XCTAssertEqual(state.pipeline.layerCodes, ["L5"])
    }

    // MARK: - L6 — Presence (gated by contextFrame)

    func testL6NoContextFrameSkips() async {
        let layer = Layer6PresencePipeline()
        var state = Self.makeState()
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(state.pipeline.layerCodes, [])
    }

    func testL6FiresWithContextFrame() async {
        let layer = Layer6PresencePipeline()
        var inputs = Self.makeInputs()
        inputs.contextFrame = BASContextFrame(
            utterance: "u", taskType: .chat,
            emotionalLoad: 0.1, timePressure: 0.1,
            relationPattern: "self",
            ambiguityScore: 0.1, consequenceLevel: 0.1,
            hostRelevance: 0.5)
        var state = Self.makeState(inputs: inputs)
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(state.pipeline.layerCodes, ["L6"])
    }

    // MARK: - L7 — Decomposition (gated by decomposeFrame)

    func testL7NoDecomposeFrameSkips() async {
        let layer = Layer7DecompositionPipeline()
        var state = Self.makeState()
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(state.pipeline.layerCodes, [])
    }

    func testL7FiresWithDecomposeFrame() async {
        let layer = Layer7DecompositionPipeline()
        var inputs = Self.makeInputs()
        inputs.decomposeFrame = BASDecomposeFrame(
            facts: ["f"], goals: ["g"])
        var state = Self.makeState(inputs: inputs)
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(state.pipeline.layerCodes, ["L7"])
    }

    // MARK: - L8 — Memory (gated by memoryBundle)

    func testL8NoMemoryBundleSkips() async {
        let layer = Layer8MemoryPipeline()
        var state = Self.makeState()
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(state.pipeline.layerCodes, [])
    }

    func testL8FiresWithMemoryBundle() async {
        let layer = Layer8MemoryPipeline()
        var inputs = Self.makeInputs()
        inputs.memoryBundle = BASMemoryBundle(atoms: [])
        var state = Self.makeState(inputs: inputs)
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(state.pipeline.layerCodes, ["L8"])
    }

    // MARK: - L4/L10/L11 — ThoughtFrame cluster

    func testL4_10_11_NoThoughtFrameSkips() async {
        let layer = Layer4_10_11_ThoughtFramePipeline()
        var state = Self.makeState()
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(state.pipeline.layerCodes, [])
    }

    func testL4_10_11_FiresThreeLayersFromOneGate() async {
        let layer = Layer4_10_11_ThoughtFramePipeline()
        var inputs = Self.makeInputs()
        inputs.thoughtFrame = BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "d",
            stabilityScore: 0.5)
        var state = Self.makeState(inputs: inputs)
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(
            state.pipeline.layerCodes,
            ["L4", "L10", "L11"],
            "thoughtFrame gate fires three coverage summaries " +
            "in stable order: L4 (worldPrior), L10 (tribunal), " +
            "L11 (risk)")
    }

    // MARK: - L13 — Update tickets (gated by updateTickets non-empty)

    func testL13EmptyTicketsSkips() async {
        let layer = Layer13UpdateTicketPipeline()
        var state = Self.makeState()
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(state.pipeline.layerCodes, [])
    }

    // MARK: - L2 — Neural organ (gated by neuralOrganMap)

    func testL2NoOrganMapSkips() async {
        let layer = Layer2NeuralOrganPipeline()
        var state = Self.makeState()
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(state.pipeline.layerCodes, [])
    }

    // MARK: - L12 — Soft hand (co-gated thoughtFrame + renderedOutput)

    func testL12NeitherInputSkips() async {
        let layer = Layer12SoftHandPipeline()
        var state = Self.makeState()
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(state.pipeline.layerCodes, [])
    }

    func testL12OnlyThoughtFrameSkips() async {
        let layer = Layer12SoftHandPipeline()
        var inputs = Self.makeInputs()
        inputs.thoughtFrame = BASThoughtFrame(
            stepIndex: 0, decomposeRef: "d",
            stabilityScore: 0.5)
        var state = Self.makeState(inputs: inputs)
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(
            state.pipeline.layerCodes, [],
            "L12 requires BOTH thoughtFrame AND renderedOutput")
    }

    func testL12OnlyRenderedOutputSkips() async {
        let layer = Layer12SoftHandPipeline()
        var inputs = Self.makeInputs()
        inputs.renderedOutput = BASRenderedOutput(
            mode: .answer, headline: "h", body: "b")
        var state = Self.makeState(inputs: inputs)
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(
            state.pipeline.layerCodes, [],
            "L12 requires BOTH thoughtFrame AND renderedOutput")
    }

    func testL12FiresWithBothInputs() async {
        let layer = Layer12SoftHandPipeline()
        var inputs = Self.makeInputs()
        inputs.thoughtFrame = BASThoughtFrame(
            stepIndex: 0, decomposeRef: "d",
            stabilityScore: 0.5)
        inputs.renderedOutput = BASRenderedOutput(
            mode: .answer, headline: "h", body: "b")
        var state = Self.makeState(inputs: inputs)
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(state.pipeline.layerCodes, ["L12"])
    }

    // MARK: - L9 — Candidate frontier (gated by candidateFrontier)

    func testL9NoFrontierSkips() async {
        let layer = Layer9CandidateFrontierPipeline()
        var state = Self.makeState()
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        XCTAssertEqual(state.pipeline.layerCodes, [])
    }

    // MARK: - Cross-layer invariant

    /// A layer that doesn't fire its gate must NOT touch
    /// state.l3Fold or state.l5Constitution. Pre-M172 some
    /// layers shared local state with surrounding inline code
    /// — extracting them to value types removed that hazard,
    /// and this test pins it.
    func testNonFiringLayersDoNotTouchSharedState() async {
        let layer = Layer6PresencePipeline()
        var state = Self.makeState()
        // Both shared fields start nil.
        XCTAssertNil(state.l3Fold)
        XCTAssertNil(state.l5Constitution)
        await layer.process(
            state: &state,
            host: makeHost(),
            lifecycle: nil,
            now: Self.frozenNow)
        // Layer's gate is OFF (no contextFrame); shared fields
        // must remain untouched.
        XCTAssertNil(state.l3Fold)
        XCTAssertNil(state.l5Constitution)
    }
}

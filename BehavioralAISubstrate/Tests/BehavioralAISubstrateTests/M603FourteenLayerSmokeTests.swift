import XCTest
@testable import BASHostKit
@testable import BASOrchestration

/// **M603 chapter 一百七十三 — 14-layer smoke tests**.
///
/// User invocation: "14层 每层都冒烟测试 以此发挥最大作用 找到瑕疵".
///
/// Drives real `BASHostRuntime` turn and asserts each of the
/// expected per-layer `<layer>.coverage:<status>` audit signalRefs
/// actually emits. If substrate ever drops a layer's emission
/// (e.g. via refactoring), this test catches it.
///
/// Coverage layers emitted by `EBrainRuntimeCoordinator+SovereignCommit.swift`:
///   - presence.coverage          (L1 wake / vital-presence)
///   - leaseLife.coverage         (L1 lease + thermal)
///   - decomposition.coverage     (L2 senses)
///   - neuralOrgan.coverage       (L2 organ adapter)
///   - thoughtFold.coverage       (L3 fold)
///   - worldPrior.coverage        (L4 world prior)
///   - hostConstitution.coverage  (L5 host)
///   - hippocampal.coverage       (L8 memory)
///   - risk.coverage              (L11 wind gate)
///   - softHand.coverage          (L12 soft hand)
///   - updateTicket.coverage      (L13 evolution ticket)
///   - reconciliation.severity    (cross-layer L14 reconcile)
///
/// Plus Kunlun + Cthulhu doctrine layers verified separately
/// (M598 chapter 一百六十九 + M384 chapter 八十九 etc).
final class M603FourteenLayerSmokeTests: XCTestCase {

    /// Drive a single turn and assert each coverage emission
    /// fires. Doctrine: every turn should populate every layer's
    /// observation bundle. If any layer is silent, substrate has
    /// a coverage drift.
    func testTurnEmitsAllExpectedLayerCoverageCodes() throws {
        let runtime = BASHostRuntime(
            configuration: .fixtureGeneric)
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt:
                    "Should I take this important decision today?",
                title: "smoke-14-layer",
                riskLevel: .medium))
        let turn = try XCTUnwrap(result.eBrainTurn)
        let signalRefs = turn.sovereignAuditEntry?
            .signalRefs.map { String($0) } ?? []

        // 11 per-layer coverage prefixes that MUST appear
        let expectedPrefixes = [
            "presence.coverage:",
            "leaseLife.coverage:",
            "decomposition.coverage:",
            "neuralOrgan.coverage:",
            "thoughtFold.coverage:",
            "worldPrior.coverage:",
            "hostConstitution.coverage:",
            "hippocampal.coverage:",
            "risk.coverage:",
            "softHand.coverage:",
            "updateTicket.coverage:",
        ]
        for prefix in expectedPrefixes {
            let found = signalRefs.contains { ref in
                ref.hasPrefix(prefix)
            }
            XCTAssertTrue(
                found,
                """
                Layer coverage emission missing: \(prefix)
                Substrate may have dropped this layer's
                observation bundle. Expected substrate to emit
                exactly one `\(prefix)<full|partial|empty>`
                per turn.

                signalRefs sample: \(signalRefs.prefix(20))
                """)
        }
    }

    /// Reconciliation verdict fires (L14 cross-layer audit).
    func testTurnEmitsReconciliationVerdict() throws {
        let runtime = BASHostRuntime(
            configuration: .fixtureGeneric)
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "Test reconciliation verdict.",
                title: "smoke-l14-reconcile",
                riskLevel: .low))
        let turn = try XCTUnwrap(result.eBrainTurn)
        let signalRefs = turn.sovereignAuditEntry?
            .signalRefs.map { String($0) } ?? []
        XCTAssertTrue(
            signalRefs.contains { $0
                .hasPrefix("reconciliation.severity:") },
            "Expected reconciliation.severity:<level> emission")
        XCTAssertTrue(
            signalRefs.contains { $0
                .hasPrefix("reconciliation.observed:") },
            "Expected reconciliation.observed:<L1+L2+...> emission")
    }

    /// Kunlun doctrine layers (chapters 八十九 - 一百二十七) fire.
    /// Subset: axis (L4) + permit escalation hint (L11) + audit
    /// projection emissions.
    func testTurnEmitsKunlunDoctrineCoverage() throws {
        let runtime = BASHostRuntime(
            configuration: .fixtureGeneric)
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt:
                    "Kunlun axis test prompt for high-risk decision.",
                title: "smoke-kunlun",
                riskLevel: .high))
        let turn = try XCTUnwrap(result.eBrainTurn)
        let signalRefs = turn.sovereignAuditEntry?
            .signalRefs.map { String($0) } ?? []
        // Kunlun axis emission
        XCTAssertTrue(
            signalRefs.contains { $0
                .hasPrefix("kunlun.axis.center:") },
            "Expected kunlun.axis.center:<score> emission")
    }

    /// Cthulhu doctrine layers (chapter 八十九+) fire — at least
    /// the abyssal magnitude code that's emitted unconditionally
    /// per turn.
    func testTurnEmitsCthulhuDoctrineCoverage() throws {
        let runtime = BASHostRuntime(
            configuration: .fixtureGeneric)
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "Cthulhu pressure test.",
                title: "smoke-cthulhu",
                riskLevel: .medium))
        let turn = try XCTUnwrap(result.eBrainTurn)
        let signalRefs = turn.sovereignAuditEntry?
            .signalRefs.map { String($0) } ?? []
        XCTAssertTrue(
            signalRefs.contains { $0
                .hasPrefix("abyssal.magnitude:") },
            "Expected abyssal.magnitude:<float> emission")
    }

    /// Doctrine pin: 4 chapter 一百六十二 typed projection fields
    /// MUST be populated on every turn (chapter 一百六十四 dead-code
    /// removal proved them by-construction).
    func testTurnPopulatesAllTypedProjectionFields() throws {
        let runtime = BASHostRuntime(
            configuration: .fixtureGeneric)
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "Test all projections populated.",
                title: "smoke-projections",
                riskLevel: .medium))
        let turn = try XCTUnwrap(result.eBrainTurn)
        // 4 typed fields wired chapter 一百五十三 + 一百五十六
        XCTAssertNotNil(
            turn.kunlunAxisAlignment,
            "kunlunAxisAlignment must populate (chapter 153 wire)")
        XCTAssertNotNil(
            turn.humanAnchorSignal,
            "humanAnchorSignal must populate (chapter 153 wire)")
        XCTAssertNotNil(
            turn.abyssalPressure,
            "abyssalPressure must populate (chapter 153 wire)")
        XCTAssertNotNil(
            turn.unknownReserve,
            "unknownReserve must populate (chapter 153 wire)")
        XCTAssertNotNil(
            turn.kunlunHeavenGatePermit,
            "kunlunHeavenGatePermit must populate (chapter 156 wire)")
        XCTAssertNotNil(
            turn.kunlunRiverOriginTrace,
            "kunlunRiverOriginTrace must populate (chapter 156 wire)")
        XCTAssertNotNil(
            turn.yaochiSanctumEntry,
            "yaochiSanctumEntry must populate (chapter 156 wire)")
    }

    /// Procedural fuzz test: run 10 turns with varying prompts
    /// and assert ALL turns emit ALL expected layer coverages.
    /// If any layer drops on certain inputs, this test catches it.
    func testProceduralFuzzAllLayersAcrossVariedPrompts() throws {
        let runtime = BASHostRuntime(
            configuration: .fixtureGeneric)
        let prompts = [
            "Should I quit my job today?",
            "What's a safer alternative path?",
            "Help me understand this complex decision.",
            "I'm anxious about this irreversible choice.",
            "Compare these two options for me.",
            "What if I'm wrong about everything?",
            "Walk me through the consequences.",
            "Is there a less drastic option?",
            "How do I know when to pause?",
            "Show me the trade-offs explicitly.",
        ]
        let riskLevels: [BASHostRiskLevel] = [
            .low, .medium, .high,
        ]
        let workflows: [BASHostWorkflowProfile] = [
            .primary, .comparative, .reflective,
        ]
        let expectedPrefixes = [
            "presence.coverage:",
            "leaseLife.coverage:",
            "decomposition.coverage:",
            "neuralOrgan.coverage:",
            "thoughtFold.coverage:",
            "worldPrior.coverage:",
            "hostConstitution.coverage:",
            "hippocampal.coverage:",
            "risk.coverage:",
            "softHand.coverage:",
            "updateTicket.coverage:",
        ]
        for (iter, prompt) in prompts.enumerated() {
            let risk = riskLevels[iter % riskLevels.count]
            let workflow = workflows[iter % workflows.count]
            let result = try runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: workflow,
                    surface: .application,
                    prompt: prompt,
                    title: "fuzz-\(iter)",
                    riskLevel: risk))
            let turn = try XCTUnwrap(result.eBrainTurn)
            let signalRefs = turn.sovereignAuditEntry?
                .signalRefs.map { String($0) } ?? []
            for prefix in expectedPrefixes {
                let found = signalRefs.contains { ref in
                    ref.hasPrefix(prefix)
                }
                XCTAssertTrue(
                    found,
                    """
                    Iter \(iter) (prompt: \"\(prompt)\",
                    risk: \(risk), workflow: \(workflow))
                    missing layer coverage: \(prefix)
                    """)
            }
        }
    }
}

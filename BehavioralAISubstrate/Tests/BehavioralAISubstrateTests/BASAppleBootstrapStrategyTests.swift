import Foundation
import Testing
@testable import BASAppleAdapters
@testable import BASMemory

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BASApple Bootstrap Strategy")
struct BASAppleBootstrapStrategyTests {
    @Test("ordered template IDs use substrate ordering over host bootstrap inputs")
    func orderedTemplateIDsUseSubstrateOrdering() {
        let now = Date(timeIntervalSince1970: 1_744_000_100)
        let ordered = BASAppleBootstrapStrategyAdapter.orderedTemplateIDs(
            modeID: "primary",
            riskLevelID: "medium",
            recommendedTemplateIDs: ["tomorrow_box_interrupt", "fallback_template"],
            templates: [
                BASAppleCurrentBrainBootstrapHostTemplateInput(
                    id: "fallback_template",
                    modeID: "primary",
                    riskLevelID: "medium",
                    isPinned: false,
                    successCount: 8,
                    updatedAt: now
                ),
                BASAppleCurrentBrainBootstrapHostTemplateInput(
                    id: "tomorrow_box_interrupt",
                    modeID: "primary",
                    riskLevelID: "medium",
                    isPinned: true,
                    successCount: 2,
                    updatedAt: now.addingTimeInterval(-60)
                ),
                BASAppleCurrentBrainBootstrapHostTemplateInput(
                    id: "wrong_mode",
                    modeID: "reflective",
                    riskLevelID: "medium",
                    isPinned: true,
                    successCount: 99,
                    updatedAt: now.addingTimeInterval(60)
                )
            ]
        )

        #expect(ordered == ["tomorrow_box_interrupt", "fallback_template"])
    }

    @Test("ordered failure pattern IDs use substrate ordering over host bootstrap inputs")
    func orderedFailurePatternIDsUseSubstrateOrdering() {
        let now = Date(timeIntervalSince1970: 1_744_000_200)
        let ordered = BASAppleBootstrapStrategyAdapter.orderedFailurePatternIDs(
            modeID: "primary",
            failurePatterns: [
                BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                    id: "night_fast_path_failure",
                    modeID: "primary",
                    suppressionWeight: 0.9,
                    evidenceCount: 2,
                    updatedAt: now
                ),
                BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                    id: "proceed_without_pause_failure",
                    modeID: "primary",
                    suppressionWeight: 0.9,
                    evidenceCount: 4,
                    updatedAt: now.addingTimeInterval(-60)
                ),
                BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                    id: "reflective_only_failure",
                    modeID: "reflective",
                    suppressionWeight: 1.0,
                    evidenceCount: 10,
                    updatedAt: now.addingTimeInterval(60)
                )
            ]
        )

        #expect(ordered == ["proceed_without_pause_failure", "night_fast_path_failure"])
    }

    @Test("session seed builder trims fragments and resolves the active priming mode")
    func sessionSeedBuilderTrimsAndResolvesActiveMode() {
        let seed = BASAppleBootstrapStrategyAdapter.resolveActiveSessionSeed(
            promptFragmentsByModeID: [
                BASDecisionMode.comparative.identifier: ["  Should I move?  ", "", " protect savings "],
                BASDecisionMode.reflective.identifier: ["This would be ignored"]
            ],
            modePriority: [
                BASDecisionMode.primary.identifier,
                BASDecisionMode.comparative.identifier,
                BASDecisionMode.reflective.identifier
            ],
            taskGraphModeID: "reflective",
            taskGraphPromptSeed: "task graph fallback"
        )

        #expect(seed.modeID == "comparative")
        #expect(seed.promptSeed == "Should I move? protect savings")
        #expect(
            BASAppleBootstrapStrategyAdapter.promptSeed(
                fragments: ["  one  ", "", "two", "   "]
            ) == "one two"
        )
    }

    @Test("invalid bootstrap strategy identifiers recover instead of crashing")
    func invalidBootstrapIdentifiersRecover() {
        let seed = BASAppleBootstrapStrategyAdapter.resolveActiveSessionSeed(
            promptFragmentsByModeID: [
                "unsupported-mode": ["this should be ignored"],
                BASDecisionMode.primary.identifier: ["  safe fallback  "]
            ],
            modePriority: [
                "unsupported-mode",
                BASDecisionMode.primary.identifier
            ],
            taskGraphModeID: "unsupported-task-graph",
            taskGraphPromptSeed: "task graph fallback",
            defaultModeID: "unsupported-default"
        )

        #expect(seed.modeID == BASDecisionMode.primary.identifier)
        #expect(seed.promptSeed == "safe fallback")

        let orderedTemplateIDs = BASAppleBootstrapStrategyAdapter.orderedTemplateIDs(
            modeID: "unsupported-mode",
            riskLevelID: "unsupported-risk",
            recommendedTemplateIDs: ["valid_template"],
            templates: [
                BASAppleCurrentBrainBootstrapHostTemplateInput(
                    id: "valid_template",
                    modeID: BASDecisionMode.primary.identifier,
                    riskLevelID: "low",
                    isPinned: false,
                    successCount: 3,
                    updatedAt: .now
                ),
                BASAppleCurrentBrainBootstrapHostTemplateInput(
                    id: "invalid_template_mode",
                    modeID: "unsupported-mode",
                    riskLevelID: "low",
                    isPinned: true,
                    successCount: 10,
                    updatedAt: .now
                ),
                BASAppleCurrentBrainBootstrapHostTemplateInput(
                    id: "invalid_template_risk",
                    modeID: BASDecisionMode.primary.identifier,
                    riskLevelID: "unsupported-risk",
                    isPinned: true,
                    successCount: 10,
                    updatedAt: .now
                )
            ]
        )

        #expect(orderedTemplateIDs == ["valid_template"])

        let orderedFailurePatternIDs = BASAppleBootstrapStrategyAdapter.orderedFailurePatternIDs(
            modeID: "unsupported-mode",
            failurePatterns: [
                BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                    id: "valid_failure",
                    modeID: BASDecisionMode.primary.identifier,
                    suppressionWeight: 0.7,
                    evidenceCount: 2,
                    updatedAt: .now
                ),
                BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                    id: "invalid_failure",
                    modeID: "unsupported-mode",
                    suppressionWeight: 0.9,
                    evidenceCount: 5,
                    updatedAt: .now
                )
            ]
        )

        #expect(orderedFailurePatternIDs == ["valid_failure"])
    }
}
#endif

import Foundation
import Testing
@testable import BASAppleAdapters

@Suite("BASApple Bootstrap Strategy")
struct BASAppleBootstrapStrategyTests {
    @Test("default template seeds stay stable and cover the bootstrap catalog")
    func defaultTemplateSeedsStayStable() {
        let now = Date(timeIntervalSince1970: 1_744_000_000)
        let seeds = BASAppleBootstrapStrategyAdapter.defaultTemplateSeeds(now: now)

        #expect(seeds.map(\.id) == [
            "tomorrow_box_interrupt",
            "brief_warm_nudge",
            "reflective_question",
            "slow_delay_guard"
        ])
        #expect(seeds.allSatisfy { $0.createdAt == now && $0.updatedAt == now })
    }

    @Test("ordered template IDs use substrate ordering over host bootstrap inputs")
    func orderedTemplateIDsUseSubstrateOrdering() {
        let now = Date(timeIntervalSince1970: 1_744_000_100)
        let ordered = BASAppleBootstrapStrategyAdapter.orderedTemplateIDs(
            modeID: "quick",
            riskLevelID: "medium",
            recommendedTemplateIDs: ["tomorrow_box_interrupt", "fallback_template"],
            templates: [
                BASAppleCurrentBrainBootstrapHostTemplateInput(
                    id: "fallback_template",
                    modeID: "quick",
                    riskLevelID: "medium",
                    isPinned: false,
                    successCount: 8,
                    updatedAt: now
                ),
                BASAppleCurrentBrainBootstrapHostTemplateInput(
                    id: "tomorrow_box_interrupt",
                    modeID: "quick",
                    riskLevelID: "medium",
                    isPinned: true,
                    successCount: 2,
                    updatedAt: now.addingTimeInterval(-60)
                ),
                BASAppleCurrentBrainBootstrapHostTemplateInput(
                    id: "wrong_mode",
                    modeID: "mirror",
                    riskLevelID: "medium",
                    isPinned: true,
                    successCount: 99,
                    updatedAt: now.addingTimeInterval(60)
                )
            ]
        )

        #expect(ordered == ["tomorrow_box_interrupt", "fallback_template"])
    }

    @Test("failure synthesis extracts night and proceed guards from negative history")
    func failureSynthesisExtractsBootstrapGuards() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.autoupdatingCurrent
        components.year = 2026
        components.month = 4
        components.day = 11
        components.hour = 23
        let lateNight = components.date ?? .distantPast

        let seeds = BASAppleBootstrapStrategyAdapter.synthesizedFailurePatternSeeds(
            from: [
                BASAppleFailureHistoryEventInput(
                    createdAt: lateNight,
                    reflectionOutcomeID: "regrettedIt",
                    finalActionID: "goAheadAnyway"
                ),
                BASAppleFailureHistoryEventInput(
                    createdAt: lateNight.addingTimeInterval(-3600),
                    reflectionOutcomeID: "feltEmptier",
                    finalActionID: "continueMindfully"
                ),
                BASAppleFailureHistoryEventInput(
                    createdAt: lateNight.addingTimeInterval(-7200),
                    reflectionOutcomeID: "okay",
                    finalActionID: "wait90s"
                )
            ],
            now: lateNight
        )

        #expect(seeds.map(\.id) == ["night_fast_path_failure", "proceed_without_pause_failure"])
        #expect(seeds.allSatisfy { $0.modeID == "quick" })
        #expect(seeds.first?.evidenceCount == 2)
        #expect(seeds.last?.evidenceCount == 2)
    }

    @Test("ordered failure pattern IDs use substrate ordering over host bootstrap inputs")
    func orderedFailurePatternIDsUseSubstrateOrdering() {
        let now = Date(timeIntervalSince1970: 1_744_000_200)
        let ordered = BASAppleBootstrapStrategyAdapter.orderedFailurePatternIDs(
            modeID: "quick",
            failurePatterns: [
                BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                    id: "night_fast_path_failure",
                    modeID: "quick",
                    suppressionWeight: 0.9,
                    evidenceCount: 2,
                    updatedAt: now
                ),
                BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                    id: "proceed_without_pause_failure",
                    modeID: "quick",
                    suppressionWeight: 0.9,
                    evidenceCount: 4,
                    updatedAt: now.addingTimeInterval(-60)
                ),
                BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                    id: "mirror_only_failure",
                    modeID: "mirror",
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
            quickPromptFragments: nil,
            balancePromptFragments: ["  Should I move?  ", "", " protect savings "],
            mirrorPromptFragments: ["This would be ignored"],
            taskGraphModeID: "mirror",
            taskGraphPromptSeed: "task graph fallback"
        )

        #expect(seed.modeID == "balance")
        #expect(seed.promptSeed == "Should I move? protect savings")
        #expect(
            BASAppleBootstrapStrategyAdapter.promptSeed(
                fragments: ["  one  ", "", "two", "   "]
            ) == "one two"
        )
    }
}

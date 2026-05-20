import Foundation
import BASHostKit

enum BeforeProductBootstrapSemantics {
    static func defaultTemplateSeeds(now: Date = .now) -> [BASAppleInterventionTemplateSeed] {
        [
            BASAppleInterventionTemplateSeed(
                id: "tomorrow_box_interrupt",
                createdAt: now,
                updatedAt: now,
                title: "Night-message cooling",
                summary: "Lower the heat, then move the message into tomorrow.",
                body: [
                    "Step back from the send button.",
                    "Name what this message is trying to fix right now.",
                    "Move it into a deferred hold before you reread it."
                ],
                modeID: DecisionMode.quick.substrateModeID,
                riskLevelID: InterventionRiskLevel.medium.rawValue,
                isPinned: true,
                successCount: 0
            ),
            BASAppleInterventionTemplateSeed(
                id: "brief_warm_nudge",
                createdAt: now,
                updatedAt: now,
                title: "Impulse-buy cooling",
                summary: "Short, warm friction before spending from blur.",
                body: [
                    "Pause the purchase.",
                    "Name whether this is need, relief, or reward.",
                    "Reopen it in daylight."
                ],
                modeID: DecisionMode.quick.substrateModeID,
                riskLevelID: InterventionRiskLevel.low.rawValue,
                isPinned: true,
                successCount: 0
            ),
            BASAppleInterventionTemplateSeed(
                id: "reflective_question",
                createdAt: now,
                updatedAt: now,
                title: "Anxiety loop interruption",
                summary: "Use one question and one grounded action instead of more spinning.",
                body: [
                    "What are you trying to make go away quickly?",
                    "Choose one small grounded action.",
                    "Do not solve the whole future right now."
                ],
                modeID: DecisionMode.mirror.substrateModeID,
                riskLevelID: InterventionRiskLevel.medium.rawValue,
                isPinned: true,
                successCount: 0
            ),
            BASAppleInterventionTemplateSeed(
                id: "slow_delay_guard",
                createdAt: now,
                updatedAt: now,
                title: "Self-blame recovery",
                summary: "Slow the cadence, keep it honest, and stop adding punishment.",
                body: [
                    "Name what happened without adding contempt.",
                    "Choose one boundary step, not a life sentence.",
                    "If needed, move the call into a deferred hold."
                ],
                modeID: DecisionMode.mirror.substrateModeID,
                riskLevelID: InterventionRiskLevel.high.rawValue,
                isPinned: true,
                successCount: 0
            )
        ]
    }

    static func synthesizedFailurePatternSeeds(
        from events: [CheckEvent],
        now: Date = .now
    ) -> [BASAppleFailurePatternSeed] {
        let negativeEvents = events.filter {
            guard let outcome = $0.reflectionOutcome else { return false }
            return outcome == .regrettedIt || outcome == .feltEmptier
        }

        guard !negativeEvents.isEmpty else {
            return []
        }

        let nightFailures = negativeEvents.filter {
            let hour = Calendar.autoupdatingCurrent.component(.hour, from: $0.createdAt)
            return hour >= 22 || hour < 5
        }
        let proceedFailures = negativeEvents.filter {
            $0.finalAction == .goAheadAnyway || $0.finalAction == .continueMindfully
        }

        var seeds: [BASAppleFailurePatternSeed] = []
        if nightFailures.count >= 2 {
            seeds.append(
                BASAppleFailurePatternSeed(
                    id: "night_fast_path_failure",
                    createdAt: now,
                    updatedAt: now,
                    modeID: DecisionMode.quick.substrateModeID,
                    title: "Night fast paths backfire",
                    detail: "Fast action at night has repeatedly ended in regret or emptiness.",
                    cadenceTag: "night_fast_path",
                    suppressionWeight: min(1, 0.4 + Double(nightFailures.count) * 0.12),
                    evidenceCount: nightFailures.count
                )
            )
        }
        if proceedFailures.count >= 2 {
            seeds.append(
                BASAppleFailurePatternSeed(
                    id: "proceed_without_pause_failure",
                    createdAt: now,
                    updatedAt: now,
                    modeID: DecisionMode.quick.substrateModeID,
                    title: "Proceeding too fast backfires",
                    detail: "Going forward without a pause has repeatedly ended badly.",
                    cadenceTag: "proceed_fast",
                    suppressionWeight: min(1, 0.4 + Double(proceedFailures.count) * 0.1),
                    evidenceCount: proceedFailures.count
                )
            )
        }

        return seeds.sorted {
            if $0.suppressionWeight == $1.suppressionWeight {
                return $0.id < $1.id
            }
            return $0.suppressionWeight > $1.suppressionWeight
        }
    }
}

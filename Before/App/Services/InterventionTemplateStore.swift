import Foundation
import SwiftData

enum InterventionTemplateStore {
    static func ensureDefaults(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<InterventionTemplateRecord>())) ?? []
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for template in defaultTemplates where byID[template.id] == nil {
            context.insert(template)
        }
        if context.hasChanges {
            try? context.save()
        }
    }

    static func selectTemplates(
        in context: ModelContext,
        mode: DecisionMode,
        riskLevel: InterventionRiskLevel,
        recommendedArmIDs: [String]
    ) -> [InterventionTemplateRecord] {
        ensureDefaults(in: context)
        let descriptor = FetchDescriptor<InterventionTemplateRecord>(
            sortBy: [SortDescriptor(\.successCount, order: .reverse), SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let templates = (try? context.fetch(descriptor)) ?? []
        return templates
            .filter { $0.mode == mode && $0.riskLevel == riskLevel }
            .sorted { lhs, rhs in
                let lhsPriority = recommendedArmIDs.firstIndex(of: lhs.id) ?? Int.max
                let rhsPriority = recommendedArmIDs.firstIndex(of: rhs.id) ?? Int.max
                if lhsPriority == rhsPriority {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhsPriority < rhsPriority
            }
    }

    private static var defaultTemplates: [InterventionTemplateRecord] {
        [
            InterventionTemplateRecord(
                id: "tomorrow_box_interrupt",
                title: "Night-message cooling",
                summary: "Lower the heat, then move the message into tomorrow.",
                body: [
                    "Step back from the send button.",
                    "Name what this message is trying to fix right now.",
                    "Put it into Tomorrow Box before you reread it."
                ],
                mode: .quick,
                riskLevel: .medium,
                isPinned: true
            ),
            InterventionTemplateRecord(
                id: "brief_warm_nudge",
                title: "Impulse-buy cooling",
                summary: "Short, warm friction before spending from blur.",
                body: [
                    "Pause the purchase.",
                    "Name whether this is need, relief, or reward.",
                    "Reopen it in daylight."
                ],
                mode: .quick,
                riskLevel: .low,
                isPinned: true
            ),
            InterventionTemplateRecord(
                id: "reflective_question",
                title: "Anxiety loop interruption",
                summary: "Use one question and one grounded action instead of more spinning.",
                body: [
                    "What are you trying to make go away quickly?",
                    "Choose one small grounded action.",
                    "Do not solve the whole future right now."
                ],
                mode: .mirror,
                riskLevel: .medium,
                isPinned: true
            ),
            InterventionTemplateRecord(
                id: "slow_delay_guard",
                title: "Self-blame recovery",
                summary: "Slow the cadence, keep it honest, and stop adding punishment.",
                body: [
                    "Name what happened without adding contempt.",
                    "Choose one boundary step, not a life sentence.",
                    "If needed, move the call into Tomorrow Box."
                ],
                mode: .mirror,
                riskLevel: .high,
                isPinned: true
            )
        ]
    }
}

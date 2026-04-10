import Foundation
import SwiftData
import BASAppleAdapters

enum InterventionTemplateStore {
    static func ensureDefaults(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<InterventionTemplateRecord>())) ?? []
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for seed in BASAppleBootstrapStrategyAdapter.defaultTemplateSeeds() where byID[seed.id] == nil {
            context.insert(
                InterventionTemplateRecord(
                    id: seed.id,
                    createdAt: seed.createdAt,
                    updatedAt: seed.updatedAt,
                    title: seed.title,
                    summary: seed.summary,
                    body: seed.body,
                    mode: DecisionMode(rawValue: seed.modeID) ?? .quick,
                    riskLevel: InterventionRiskLevel(rawValue: seed.riskLevelID) ?? .low,
                    isPinned: seed.isPinned,
                    successCount: seed.successCount
                )
            )
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
        let orderedIDs = BASAppleBootstrapStrategyAdapter.orderedTemplateIDs(
            modeID: mode.rawValue,
            riskLevelID: riskLevel.rawValue,
            recommendedTemplateIDs: recommendedArmIDs,
            templates: templates.map { template in
                BASAppleCurrentBrainBootstrapHostTemplateInput(
                    id: template.id,
                    modeID: template.mode.rawValue,
                    riskLevelID: template.riskLevel.rawValue,
                    isPinned: template.isPinned,
                    successCount: template.successCount,
                    updatedAt: template.updatedAt
                )
            }
        )
        let priorityByID = Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().map { ($0.element, $0.offset) })
        return templates
            .filter { priorityByID[$0.id] != nil }
            .sorted { lhs, rhs in
                let lhsPriority = priorityByID[lhs.id] ?? Int.max
                let rhsPriority = priorityByID[rhs.id] ?? Int.max
                if lhsPriority == rhsPriority {
                    return lhs.id < rhs.id
                }
                return lhsPriority < rhsPriority
            }
    }
}

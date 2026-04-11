import Foundation
import SwiftData
import BASHostKit

enum FailurePatternStore {
    static func syncFromHistory(in context: ModelContext) {
        let failures = BeforeProductBootstrapSemantics.synthesizedFailurePatternSeeds(
            from: recentFailureHistoryEvents(in: context)
        )
        let existing = (try? context.fetch(FetchDescriptor<FailurePatternRecord>())) ?? []
        var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for failure in failures {
            if let record = byID[failure.id] {
                record.updatedAt = failure.updatedAt
                record.detail = failure.detail
                record.suppressionWeight = failure.suppressionWeight
                record.evidenceCount = failure.evidenceCount
            } else {
                let record = FailurePatternRecord(
                    id: failure.id,
                    createdAt: failure.createdAt,
                    updatedAt: failure.updatedAt,
                    mode: DecisionMode.fromSubstrateModeID(failure.modeID) ?? .quick,
                    title: failure.title,
                    detail: failure.detail,
                    cadenceTag: failure.cadenceTag,
                    suppressionWeight: failure.suppressionWeight,
                    evidenceCount: failure.evidenceCount
                )
                context.insert(record)
                byID[failure.id] = record
            }
        }

        if context.hasChanges {
            try? context.save()
        }
    }

    static func selectedFailurePatterns(
        in context: ModelContext,
        mode: DecisionMode
    ) -> [FailurePatternRecord] {
        syncFromHistory(in: context)
        let descriptor = FetchDescriptor<FailurePatternRecord>(
            sortBy: [SortDescriptor(\.suppressionWeight, order: .reverse), SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let patterns = (try? context.fetch(descriptor)) ?? []
        let orderedIDs = BASAppleBootstrapStrategyAdapter.orderedFailurePatternIDs(
            modeID: mode.substrateModeID,
            failurePatterns: patterns.map { pattern in
                BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                    id: pattern.id,
                    modeID: pattern.mode.substrateModeID,
                    suppressionWeight: pattern.suppressionWeight,
                    evidenceCount: pattern.evidenceCount,
                    updatedAt: pattern.updatedAt
                )
            }
        )
        let priorityByID = Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().map { ($0.element, $0.offset) })
        return patterns
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

    private static func recentFailureHistoryEvents(
        in context: ModelContext
    ) -> [CheckEvent] {
        let descriptor = FetchDescriptor<CheckEvent>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }
}

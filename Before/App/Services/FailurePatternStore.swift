import Foundation
import SwiftData

enum FailurePatternStore {
    static func syncFromHistory(in context: ModelContext) {
        let failures = recentFailurePatterns(in: context)
        let existing = (try? context.fetch(FetchDescriptor<FailurePatternRecord>())) ?? []
        var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for failure in failures {
            if let record = byID[failure.id] {
                record.updatedAt = .now
                record.detail = failure.detail
                record.suppressionWeight = failure.suppressionWeight
                record.evidenceCount = failure.evidenceCount
            } else {
                context.insert(failure)
                byID[failure.id] = failure
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
        let orderedIDs = BehavioralAISubstrateBridge.orderedFailurePatternIDs(
            mode: mode,
            failurePatterns: patterns
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

    private static func recentFailurePatterns(in context: ModelContext) -> [FailurePatternRecord] {
        let descriptor = FetchDescriptor<CheckEvent>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let events = (try? context.fetch(descriptor)) ?? []
        let negative = events.filter {
            guard let outcome = $0.reflectionOutcome else { return false }
            return outcome == .regrettedIt || outcome == .feltEmptier
        }

        guard !negative.isEmpty else { return [] }

        let nightFailures = negative.filter {
            let hour = Calendar.autoupdatingCurrent.component(.hour, from: $0.createdAt)
            return hour >= 22 || hour < 5
        }
        let proceedFailures = negative.filter {
            $0.finalAction == .goAheadAnyway || $0.finalAction == .continueMindfully
        }

        var results: [FailurePatternRecord] = []
        if nightFailures.count >= 2 {
            results.append(
                FailurePatternRecord(
                    id: "night_fast_path_failure",
                    mode: .quick,
                    title: "Night fast paths backfire",
                    detail: "Fast action at night has repeatedly ended in regret or emptiness.",
                    cadenceTag: "night_fast_path",
                    suppressionWeight: min(1, 0.4 + Double(nightFailures.count) * 0.12),
                    evidenceCount: nightFailures.count
                )
            )
        }
        if proceedFailures.count >= 2 {
            results.append(
                FailurePatternRecord(
                    id: "proceed_without_pause_failure",
                    mode: .quick,
                    title: "Proceeding too fast backfires",
                    detail: "Going forward without a pause has repeatedly ended badly.",
                    cadenceTag: "proceed_fast",
                    suppressionWeight: min(1, 0.4 + Double(proceedFailures.count) * 0.1),
                    evidenceCount: proceedFailures.count
                )
            )
        }
        return results
    }
}

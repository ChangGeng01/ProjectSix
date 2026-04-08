import Foundation

struct ReviewModeSummary: Identifiable, Equatable {
    let mode: DecisionMode
    let count: Int
    let title: String
    let detail: String

    var id: DecisionMode { mode }
}

struct ReviewInsight: Identifiable, Equatable {
    let eyebrow: String
    let title: String
    let detail: String
    let symbolName: String

    var id: String { "\(eyebrow)-\(title)" }
}

enum DecisionReviewEngine {
    static func summaries(
        quick: [CheckEvent],
        balance: [BalanceDecisionRecord],
        mirror: [MirrorDecisionRecord]
    ) -> [ReviewModeSummary] {
        [
            quickSummary(from: quick),
            balanceSummary(from: balance),
            mirrorSummary(from: mirror)
        ]
        .compactMap { $0 }
    }

    static func insights(
        quick: [CheckEvent],
        balance: [BalanceDecisionRecord],
        mirror: [MirrorDecisionRecord],
        tomorrowCount: Int
    ) -> [ReviewInsight] {
        var results: [ReviewInsight] = []

        if let scenario = mostFrequent(in: quick.map(\.scenario)),
           let verdict = mostFrequent(in: quick.map(\.verdict)) {
            results.append(
                ReviewInsight(
                    eyebrow: "Fast pattern",
                    title: "\(scenario.title) is your loudest quick trigger.",
                    detail: "Most fast calls currently land on \(verdict.title.lowercased()).",
                    symbolName: scenario.symbolName
                )
            )
        }

        if let focusTitle = mostFrequent(in: balance.map(\.focusTitle)) {
            results.append(
                ReviewInsight(
                    eyebrow: "Trade-off pattern",
                    title: "\(focusTitle) keeps taking the lead.",
                    detail: "Your balance boards keep circling back to this dimension first.",
                    symbolName: DecisionMode.balance.symbolName
                )
            )
        }

        if let actionTitle = mostFrequent(in: mirror.map(\.nextActionTitle)),
           let latestTension = mirror.sorted(by: { $0.updatedAt > $1.updatedAt }).first?.coreTension,
           !latestTension.isEmpty {
            results.append(
                ReviewInsight(
                    eyebrow: "Heavier pattern",
                    title: "\(actionTitle) keeps surfacing in the mirror.",
                    detail: latestTension,
                    symbolName: DecisionMode.mirror.symbolName
                )
            )
        }

        if tomorrowCount > 0 {
            results.append(
                ReviewInsight(
                    eyebrow: "Buffer",
                    title: "Tomorrow Box is holding \(tomorrowCount) \(tomorrowCount == 1 ? "decision" : "decisions").",
                    detail: "Delay is becoming part of how you decide, not just what you avoid.",
                    symbolName: "archivebox"
                )
            )
        }

        return results
    }

    private static func quickSummary(from events: [CheckEvent]) -> ReviewModeSummary? {
        guard !events.isEmpty else { return nil }

        let scenario = mostFrequent(in: events.map(\.scenario)) ?? .other
        let verdict = mostFrequent(in: events.map(\.verdict)) ?? .pause

        return ReviewModeSummary(
            mode: .quick,
            count: events.count,
            title: "Quick checks",
            detail: "\(scenario.title) shows up most, and \(verdict.title.lowercased()) is your most common fast call."
        )
    }

    private static func balanceSummary(from records: [BalanceDecisionRecord]) -> ReviewModeSummary? {
        guard !records.isEmpty else { return nil }

        let focusTitle = mostFrequent(in: records.map(\.focusTitle)) ?? "Clarity"
        return ReviewModeSummary(
            mode: .balance,
            count: records.count,
            title: "Balance boards",
            detail: "\(focusTitle) is the dimension you keep coming back to."
        )
    }

    private static func mirrorSummary(from records: [MirrorDecisionRecord]) -> ReviewModeSummary? {
        guard !records.isEmpty else { return nil }

        let actionTitle = mostFrequent(in: records.map(\.nextActionTitle)) ?? "Look closer"
        return ReviewModeSummary(
            mode: .mirror,
            count: records.count,
            title: "Mirror sessions",
            detail: "\(actionTitle) keeps surfacing when the question gets heavier."
        )
    }

    private static func mostFrequent<Value: Hashable>(in values: [Value]) -> Value? {
        values
            .reduce(into: [Value: Int]()) { counts, value in
                counts[value, default: 0] += 1
            }
            .max { lhs, rhs in
                if lhs.value == rhs.value {
                    return String(describing: lhs.key) > String(describing: rhs.key)
                }
                return lhs.value < rhs.value
            }?
            .key
    }
}

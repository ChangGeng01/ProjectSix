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

struct ReviewProfileRow: Identifiable, Equatable {
    let title: String
    let detail: String?
    let count: Int

    var id: String { "\(title)-\(count)" }
}

struct ReviewProfileSection: Identifiable, Equatable {
    let title: String
    let rows: [ReviewProfileRow]

    var id: String { title }
}

struct ReviewProfile: Equatable {
    let mode: DecisionMode
    let title: String
    let subtitle: String
    let sections: [ReviewProfileSection]
}

struct DecisionReviewTimelineEntryPresentation: Equatable {
    enum HeaderAccentStyle: Equatable {
        case capsule
        case accent
    }

    let title: String
    let secondaryLine: String?
    let labelTitle: String
    let labelSymbolName: String
    let headerAccentText: String
    let headerAccentStyle: HeaderAccentStyle
    let supplementaryLine: String?
    let timestamp: Date
    let footerAccentText: String?
}

struct DecisionReviewRecentEntryPresentation: Equatable {
    let title: String
    let secondaryLine: String?
    let labelTitle: String
    let labelSymbolName: String
    let timestamp: Date
    let footerText: String
}

struct DecisionReviewDetailRow: Identifiable, Equatable {
    let title: String
    let value: String

    var id: String { title }
}

struct DecisionReviewDetailPresentation: Equatable {
    let eyebrow: String
    let title: String
    let subtitle: String
    let reopenTitle: String
    let rows: [DecisionReviewDetailRow]
}

enum ReviewProfileEntry: Identifiable {
    case quick(CheckEvent)
    case balance(BalanceDecisionRecord)
    case mirror(MirrorDecisionRecord)

    var id: String {
        switch self {
        case .quick(let event):
            "quick-\(event.id.uuidString)"
        case .balance(let record):
            "balance-\(record.id.uuidString)"
        case .mirror(let record):
            "mirror-\(record.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .quick(let event):
            event.currentPerspective
        case .balance(let record):
            record.prompt
        case .mirror(let record):
            record.prompt
        }
    }

    var detail: String {
        switch self {
        case .quick(let event):
            event.afterPerspective
        case .balance(let record):
            record.focusSummary
        case .mirror(let record):
            record.coreTension
        }
    }

    var actionTitle: String {
        switch self {
        case .quick(let event):
            event.verdict.title
        case .balance(let record):
            record.focusTitle
        case .mirror(let record):
            record.nextActionTitle
        }
    }

    var mode: DecisionMode {
        switch self {
        case .quick:
            .quick
        case .balance:
            .balance
        case .mirror:
            .mirror
        }
    }

    var timestamp: Date {
        switch self {
        case .quick(let event):
            event.createdAt
        case .balance(let record):
            record.updatedAt
        case .mirror(let record):
            record.updatedAt
        }
    }

    func matches(_ record: DeveloperDecisionReplayRecord) -> Bool {
        id == record.id
    }
}

enum DecisionReviewEngine {
    static func detailPresentation(
        for event: CheckEvent
    ) -> DecisionReviewDetailPresentation {
        var rows = [
            detailRow("Scenario", event.scenario.title),
            detailRow("Verdict", event.verdict.title),
            detailRow("Why now", event.motivation.title),
            detailRow("Usually after", event.expectedOutcome.title),
            detailRow("Pull-back", event.controlLevel.title)
        ]
        .compactMap { $0 }

        if let noteRow = detailRow("Note", event.note) {
            rows.append(noteRow)
        }

        if let reflection = event.reflectionOutcome,
           let reflectionRow = detailRow("Reflection", reflection.title) {
            rows.append(reflectionRow)
        }

        if let reflectionNote = event.reflectionNote,
           let reflectionNoteRow = detailRow("After note", reflectionNote) {
            rows.append(reflectionNoteRow)
        }

        return DecisionReviewDetailPresentation(
            eyebrow: "Quick check",
            title: event.currentPerspective,
            subtitle: event.afterPerspective,
            reopenTitle: "Reopen this check",
            rows: rows
        )
    }

    static func detailPresentation(
        for record: BalanceDecisionRecord
    ) -> DecisionReviewDetailPresentation {
        DecisionReviewDetailPresentation(
            eyebrow: "Balance board",
            title: record.prompt,
            subtitle: record.focusSummary,
            reopenTitle: "Reopen this board",
            rows: [
                detailRow("What you want", record.desire),
                detailRow("What you protect", record.concern),
                detailRow("Reality", record.constraint),
                detailRow("Long-term", record.longTerm),
                detailRow("Focus", record.focusTitle),
                detailRow("Next action", record.nextAction)
            ]
            .compactMap { $0 }
        )
    }

    static func detailPresentation(
        for record: MirrorDecisionRecord
    ) -> DecisionReviewDetailPresentation {
        DecisionReviewDetailPresentation(
            eyebrow: "Mirror",
            title: record.prompt,
            subtitle: record.coreTension,
            reopenTitle: "Reopen this mirror",
            rows: [
                detailRow("Emotion", record.emotion),
                detailRow("Relationship", record.relationship),
                detailRow("Reality", record.reality),
                detailRow("Long-term", record.longTerm),
                detailRow("Self", record.selfLens),
                detailRow("Mirror action", record.nextActionTitle),
                detailRow("Next step", record.nextAction)
            ]
            .compactMap { $0 }
        )
    }

    static func timelineEntryPresentation(
        for event: CheckEvent
    ) -> DecisionReviewTimelineEntryPresentation {
        DecisionReviewTimelineEntryPresentation(
            title: event.currentPerspective,
            secondaryLine: event.afterPerspective,
            labelTitle: event.scenario.title,
            labelSymbolName: event.scenario.symbolName,
            headerAccentText: event.verdict.title,
            headerAccentStyle: .capsule,
            supplementaryLine: nil,
            timestamp: event.createdAt,
            footerAccentText: event.reflectionOutcome?.title
        )
    }

    static func timelineEntryPresentation(
        for record: BalanceDecisionRecord
    ) -> DecisionReviewTimelineEntryPresentation {
        DecisionReviewTimelineEntryPresentation(
            title: record.prompt,
            secondaryLine: record.focusSummary,
            labelTitle: "Balance board",
            labelSymbolName: DecisionMode.balance.symbolName,
            headerAccentText: record.focusTitle,
            headerAccentStyle: .accent,
            supplementaryLine: record.nextAction,
            timestamp: record.updatedAt,
            footerAccentText: nil
        )
    }

    static func timelineEntryPresentation(
        for record: MirrorDecisionRecord
    ) -> DecisionReviewTimelineEntryPresentation {
        DecisionReviewTimelineEntryPresentation(
            title: record.prompt,
            secondaryLine: record.coreTension,
            labelTitle: "Mirror",
            labelSymbolName: DecisionMode.mirror.symbolName,
            headerAccentText: record.nextActionTitle,
            headerAccentStyle: .accent,
            supplementaryLine: record.nextAction,
            timestamp: record.updatedAt,
            footerAccentText: nil
        )
    }

    static func recentEntryPresentation(
        for entry: ReviewProfileEntry
    ) -> DecisionReviewRecentEntryPresentation {
        DecisionReviewRecentEntryPresentation(
            title: entry.title,
            secondaryLine: entry.detail,
            labelTitle: entry.mode.title,
            labelSymbolName: entry.mode.symbolName,
            timestamp: entry.timestamp,
            footerText: entry.actionTitle
        )
    }

    private static func detailRow(
        _ title: String,
        _ value: String
    ) -> DecisionReviewDetailRow? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }
        return DecisionReviewDetailRow(title: title, value: trimmedValue)
    }

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

    static func profile(
        for mode: DecisionMode,
        quick: [CheckEvent],
        balance: [BalanceDecisionRecord],
        mirror: [MirrorDecisionRecord]
    ) -> ReviewProfile? {
        switch mode {
        case .quick:
            guard !quick.isEmpty else { return nil }
            return ReviewProfile(
                mode: .quick,
                title: "See what your fast calls keep becoming.",
                subtitle: "Quick checks matter when they expose repeat patterns, not just isolated urges.",
                sections: [
                    ReviewProfileSection(
                        title: "Scenarios",
                        rows: rankedRows(
                            quick.map(\.scenario.title),
                            detail: { _ in "Where fast blur tends to start." }
                        )
                    ),
                    ReviewProfileSection(
                        title: "Verdicts",
                        rows: rankedRows(
                            quick.map(\.verdict.title),
                            detail: { _ in "How the stoplight most often lands." }
                        )
                    ),
                    ReviewProfileSection(
                        title: "Reflections",
                        rows: rankedRows(
                            quick.compactMap(\.reflectionOutcome?.title),
                            detail: { _ in "How it actually felt afterward." }
                        )
                    )
                ]
                .filter { !$0.rows.isEmpty }
            )
        case .balance:
            guard !balance.isEmpty else { return nil }
            return ReviewProfile(
                mode: .balance,
                title: "See which trade-off dimension keeps leading.",
                subtitle: "Balance boards help when they reveal what keeps taking priority before the final choice is even made.",
                sections: [
                    ReviewProfileSection(
                        title: "Wants",
                        rows: rankedRows(
                            balance.map(\.desire),
                            detail: { _ in "What you keep wanting first." }
                        )
                    ),
                    ReviewProfileSection(
                        title: "Concerns",
                        rows: rankedRows(
                            balance.map(\.concern),
                            detail: { _ in "What you keep trying to protect." }
                        )
                    ),
                    ReviewProfileSection(
                        title: "Constraints",
                        rows: rankedRows(
                            balance.map(\.constraint),
                            detail: { _ in "The hard edge reality keeps bringing back." }
                        )
                    ),
                    ReviewProfileSection(
                        title: "Long-term",
                        rows: rankedRows(
                            balance.map(\.longTerm),
                            detail: { _ in "What future-you seems to care about most." }
                        )
                    ),
                    ReviewProfileSection(
                        title: "Focus titles",
                        rows: rankedRows(
                            balance.map(\.focusTitle),
                            detail: { _ in "The trade-off frame you return to most." }
                        )
                    )
                ]
                .filter { !$0.rows.isEmpty }
            )
        case .mirror:
            guard !mirror.isEmpty else { return nil }
            return ReviewProfile(
                mode: .mirror,
                title: "See what the heavier questions keep asking of you.",
                subtitle: "Mirror sessions become useful when you can see which tensions and next moves keep surfacing.",
                sections: [
                    ReviewProfileSection(
                        title: "Emotions",
                        rows: rankedRows(
                            mirror.map(\.emotion),
                            detail: { _ in "What you keep feeling before the heavier question sharpens." }
                        )
                    ),
                    ReviewProfileSection(
                        title: "Relationship patterns",
                        rows: rankedRows(
                            mirror.map(\.relationship),
                            detail: { _ in "What structure or pattern keeps returning under the latest moment." }
                        )
                    ),
                    ReviewProfileSection(
                        title: "Reality",
                        rows: rankedRows(
                            mirror.map(\.reality),
                            detail: { _ in "The constraint that keeps staying in the room." }
                        )
                    ),
                    ReviewProfileSection(
                        title: "Long-term",
                        rows: rankedRows(
                            mirror.map(\.longTerm),
                            detail: { _ in "The future cost you keep circling." }
                        )
                    ),
                    ReviewProfileSection(
                        title: "Self lens",
                        rows: rankedRows(
                            mirror.map(\.selfLens),
                            detail: { _ in "What the heavier question keeps doing to your sense of self." }
                        )
                    ),
                    ReviewProfileSection(
                        title: "Mirror actions",
                        rows: rankedRows(
                            mirror.map(\.nextActionTitle),
                            detail: { _ in "The kind of honesty the mirror keeps pulling toward." }
                        )
                    )
                ]
                .filter { !$0.rows.isEmpty }
            )
        }
    }

    static func recentEntries(
        for mode: DecisionMode,
        quick: [CheckEvent],
        balance: [BalanceDecisionRecord],
        mirror: [MirrorDecisionRecord],
        limit: Int = 3
    ) -> [ReviewProfileEntry] {
        switch mode {
        case .quick:
            quick
                .sorted(by: { $0.createdAt > $1.createdAt })
                .prefix(limit)
                .map(ReviewProfileEntry.quick)
        case .balance:
            balance
                .sorted(by: { $0.updatedAt > $1.updatedAt })
                .prefix(limit)
                .map(ReviewProfileEntry.balance)
        case .mirror:
            mirror
                .sorted(by: { $0.updatedAt > $1.updatedAt })
                .prefix(limit)
                .map(ReviewProfileEntry.mirror)
        }
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

    private static func rankedRows(
        _ values: [String],
        detail: (String) -> String?
    ) -> [ReviewProfileRow] {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String: Int]()) { counts, value in
                counts[value, default: 0] += 1
            }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .map { key, count in
                ReviewProfileRow(title: key, detail: detail(key), count: count)
            }
    }
}

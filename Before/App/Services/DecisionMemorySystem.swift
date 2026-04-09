import Foundation
import SwiftData

struct DecisionMemoryDraft: Sendable {
    let id: String
    let type: DecisionMemoryType
    let topic: String
    let headline: String
    let value: String
    let confidence: Double
    let priority: Double
    let source: DecisionMemorySource
    let lastConfirmedAt: Date
    let decayPolicy: DecisionMemoryDecayPolicy
    let retrievalTags: [String]
    let evidenceCount: Int
    let provenanceSummary: String
    let promotionPolicy: PromotionPolicy

    var fingerprint: String {
        [
            id,
            type.rawValue,
            topic,
            headline,
            value,
            String(format: "%.3f", confidence),
            String(format: "%.3f", priority),
            source.rawValue,
            lastConfirmedAt.ISO8601Format(),
            decayPolicy.rawValue,
            retrievalTags.sorted().joined(separator: "|"),
            String(evidenceCount)
        ]
        .joined(separator: "::")
    }

    func makeRecord(observationCount: Int) -> DecisionMemoryRecord {
        DecisionMemoryRecord(
            id: id,
            type: type,
            topic: topic,
            headline: headline,
            value: value,
            confidence: confidence,
            priority: priority,
            source: source,
            lastConfirmedAt: lastConfirmedAt,
            decayPolicy: decayPolicy,
            retrievalTags: retrievalTags,
            evidenceCount: evidenceCount,
            observationCount: observationCount,
            provenanceSummary: provenanceSummary
        )
    }
}

enum DecisionMemorySystem {
    private struct BrainMemoryItem {
        let id: String
        let type: DecisionMemoryType
        let headline: String
        let priority: Double
        let confidence: Double
        let retrievalTags: [String]
        let lastConfirmedAt: Date
        let decayPolicy: DecisionMemoryDecayPolicy
        let isPending: Bool

        init(record: DecisionMemoryRecord) {
            id = record.id
            type = record.type
            headline = record.headline
            priority = record.priority
            confidence = record.confidence
            retrievalTags = record.retrievalTags
            lastConfirmedAt = record.lastConfirmedAt
            decayPolicy = record.decayPolicy
            isPending = false
        }

        init(candidate: DecisionMemoryCandidateRecord) {
            id = candidate.id
            type = candidate.type
            headline = candidate.headline
            priority = candidate.priority
            confidence = candidate.confidence
            retrievalTags = candidate.retrievalTags
            lastConfirmedAt = candidate.lastObservedAt
            decayPolicy = candidate.decayPolicy
            isPending = candidate.status == .pending
        }
    }

    static func refreshStoredMemories(
        in context: ModelContext,
        now: Date = .now
    ) -> [DecisionMemoryRecord] {
        let drafts = deriveMemoryDrafts(in: context, now: now)
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    return lhs.lastConfirmedAt > rhs.lastConfirmedAt
                }
                return lhs.priority > rhs.priority
            }

        return DecisionMemoryGovernor.reconcile(
            drafts: drafts,
            in: context
        )
    }

    static func loadBrainState(
        mode: DecisionMode,
        prompt: String,
        context: ModelContext,
        now: Date = .now
    ) -> DecisionBrainState {
        let recentCheckEvents = fetchCheckEvents(in: context)
        let records = fetchMemoryRecords(in: context)
        let candidates = fetchCandidateRecords(in: context)

        let resolvedRecords: [DecisionMemoryRecord]
        let resolvedCandidates: [DecisionMemoryCandidateRecord]
        if records.isEmpty && candidates.isEmpty {
            resolvedRecords = refreshStoredMemories(in: context, now: now)
            resolvedCandidates = fetchCandidateRecords(in: context)
        } else {
            resolvedRecords = records
            resolvedCandidates = candidates
        }

        let brainItems = buildBrainItems(
            records: resolvedRecords,
            candidates: resolvedCandidates
        )

        guard !brainItems.isEmpty else {
            return DecisionBrainState(
                profileCore: [],
                activeGoals: [],
                relevantMemories: [],
                sessionBiases: defaultSessionBiases(for: mode),
                retrievalTags: Array(queryTags(for: mode, prompt: prompt)).sorted(),
                reactionWeights: DecisionReactionWeights.defaults(for: mode),
                memoryGovernance: .empty,
                loadedAt: now
            )
        }

        let queryTags = queryTags(for: mode, prompt: prompt)
        let orderedItems = brainItems.sorted {
            score($0, mode: mode, queryTags: queryTags, now: now) >
                score($1, mode: mode, queryTags: queryTags, now: now)
        }

        let profileItems = selectItems(
            from: orderedItems,
            limit: 2,
            matching: { $0.type == .identity || $0.type == .preference }
        )
        let profileCore = orderedUnique(profileItems.map(\.headline))

        let goalItems = selectItems(
            from: orderedItems,
            limit: 2,
            excludingIDs: Set(profileItems.map(\.id)),
            matching: { $0.type == .goal }
        )
        let activeGoals = orderedUnique(goalItems.map(\.headline))

        let relevantItems = selectItems(
            from: orderedItems,
            limit: 3,
            excludingIDs: Set(profileItems.map(\.id) + goalItems.map(\.id)),
            matching: { _ in true }
        )
        let relevantMemories = orderedUnique(relevantItems.map(\.headline))
        let selectedItems = profileItems + goalItems + relevantItems

        let reactionWeights = buildReactionWeights(
            mode: mode,
            queryTags: queryTags,
            orderedItems: orderedItems,
            checkEvents: recentCheckEvents,
            records: resolvedRecords,
            profileCore: profileCore,
            activeGoals: activeGoals,
            relevantMemories: relevantMemories
        )

        let memoryGovernance = buildMemoryGovernanceState(
            records: resolvedRecords,
            candidates: resolvedCandidates,
            selectedItems: selectedItems
        )

        let sessionBiases = buildSessionBiases(
            mode: mode,
            queryTags: queryTags,
            records: resolvedRecords,
            profileCore: profileCore,
            relevantMemories: relevantMemories,
            reactionWeights: reactionWeights,
            now: now
        )

        return DecisionBrainState(
            profileCore: profileCore,
            activeGoals: activeGoals,
            relevantMemories: relevantMemories,
            sessionBiases: sessionBiases,
            retrievalTags: Array(queryTags).sorted(),
            reactionWeights: reactionWeights,
            memoryGovernance: memoryGovernance,
            loadedAt: now
        )
    }

    static func fetchMemoryRecords(in context: ModelContext) -> [DecisionMemoryRecord] {
        (try? context.fetch(FetchDescriptor<DecisionMemoryRecord>())) ?? []
    }

    static func fetchCandidateRecords(in context: ModelContext) -> [DecisionMemoryCandidateRecord] {
        (try? context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())) ?? []
    }

    static func fetchCheckEvents(in context: ModelContext) -> [CheckEvent] {
        (try? context.fetch(
            FetchDescriptor<CheckEvent>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )) ?? []
    }

    private static func buildBrainItems(
        records: [DecisionMemoryRecord],
        candidates: [DecisionMemoryCandidateRecord]
    ) -> [BrainMemoryItem] {
        let pendingCandidates = candidates
            .filter { $0.status == .pending }
            .map(BrainMemoryItem.init(candidate:))
        let activeRecords = records.map(BrainMemoryItem.init(record:))

        var byID: [String: BrainMemoryItem] = [:]
        for item in activeRecords + pendingCandidates {
            if let existing = byID[item.id], memorySort(existing, item) {
                continue
            }
            byID[item.id] = item
        }
        return Array(byID.values)
    }

    private static func buildMemoryGovernanceState(
        records: [DecisionMemoryRecord],
        candidates: [DecisionMemoryCandidateRecord],
        selectedItems: [BrainMemoryItem]
    ) -> DecisionMemoryGovernanceState {
        let pendingCandidateCount = candidates.filter { $0.status == .pending }.count
        let promotedCandidateCount = candidates.filter { $0.status == .promoted }.count
        let loadedPendingMemoryCount = selectedItems.filter(\.isPending).count

        return DecisionMemoryGovernanceState(
            totalRecordCount: records.count,
            totalCandidateCount: candidates.count,
            pendingCandidateCount: pendingCandidateCount,
            promotedCandidateCount: promotedCandidateCount,
            loadedPromotedMemoryCount: selectedItems.count - loadedPendingMemoryCount,
            loadedPendingMemoryCount: loadedPendingMemoryCount
        )
    }

    private static func deriveMemoryDrafts(
        in context: ModelContext,
        now: Date
    ) -> [DecisionMemoryDraft] {
        let checkEvents = (try? context.fetch(
            FetchDescriptor<CheckEvent>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )) ?? []
        let balanceRecords = (try? context.fetch(
            FetchDescriptor<BalanceDecisionRecord>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        )) ?? []
        let mirrorRecords = (try? context.fetch(
            FetchDescriptor<MirrorDecisionRecord>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        )) ?? []
        let reminders = (try? context.fetch(
            FetchDescriptor<SelfReminder>(sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)])
        )) ?? []

        var drafts: [DecisionMemoryDraft] = []
        drafts += preferenceDrafts(reminders: reminders, checkEvents: checkEvents, now: now)
        drafts += goalDrafts(balanceRecords: balanceRecords, mirrorRecords: mirrorRecords)
        drafts += situationalDrafts(checkEvents: checkEvents, balanceRecords: balanceRecords, mirrorRecords: mirrorRecords)
        drafts += semanticDrafts(checkEvents: checkEvents, now: now)
        drafts += supportDrafts(checkEvents: checkEvents)

        var unique: [String: DecisionMemoryDraft] = [:]
        for draft in drafts {
            if let existing = unique[draft.id], memorySort(existing, draft) {
                continue
            }
            unique[draft.id] = draft
        }

        return Array(unique.values)
    }

    private static func preferenceDrafts(
        reminders: [SelfReminder],
        checkEvents: [CheckEvent],
        now: Date
    ) -> [DecisionMemoryDraft] {
        var drafts: [DecisionMemoryDraft] = []
        let reminderLengths = reminders.map { $0.content.count }
        let noteLengths = checkEvents
            .map(\.note)
            .map { normalized($0) }
            .filter { !$0.isEmpty }
            .map(\.count)
        let allLengths = reminderLengths + noteLengths

        if allLengths.count >= 3 {
            let averageLength = Double(allLengths.reduce(0, +)) / Double(allLengths.count)
            if averageLength <= 96 {
                drafts.append(
                    DecisionMemoryDraft(
                        id: "preference.communication.concise",
                        type: .preference,
                        topic: "communication_style",
                        headline: "Short, direct language lands better.",
                        value: "Prefer brief, concrete phrasing over long explanations.",
                        confidence: 0.78,
                        priority: 0.92,
                        source: .pattern,
                        lastConfirmedAt: maxDate(
                            reminders.map(\.lastUsedAt) + checkEvents.map(\.createdAt),
                            fallback: now
                        ),
                        decayPolicy: .slow,
                        retrievalTags: ["style", "communication", "concise", "direct"],
                        evidenceCount: allLengths.count,
                        provenanceSummary: "Derived from repeated short reminders and recent quick-check note length.",
                        promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 3)
                    )
                )
            }
        }

        return drafts
    }

    private static func goalDrafts(
        balanceRecords: [BalanceDecisionRecord],
        mirrorRecords: [MirrorDecisionRecord]
    ) -> [DecisionMemoryDraft] {
        let balanceGoals = balanceRecords.compactMap { record -> (String, Date)? in
            let value = normalized(record.longTerm)
            return value.isEmpty ? nil : (value, record.updatedAt)
        }
        let mirrorGoals = mirrorRecords.compactMap { record -> (String, Date)? in
            let value = normalized(record.longTerm)
            return value.isEmpty ? nil : (value, record.updatedAt)
        }

        let grouped = Dictionary(grouping: balanceGoals + mirrorGoals, by: \.0)
        return grouped
            .sorted { lhs, rhs in
                let lhsDate = lhs.value.map(\.1).max() ?? .distantPast
                let rhsDate = rhs.value.map(\.1).max() ?? .distantPast
                return lhsDate > rhsDate
            }
            .prefix(3)
            .enumerated()
            .map { index, pair in
                let goal = pair.key
                let items = pair.value
                let lastConfirmedAt = items.map(\.1).max() ?? .now
                let headline = clipped(goal, limit: 120)

                return DecisionMemoryDraft(
                    id: "goal.\(slug(goal))",
                    type: .goal,
                    topic: "active_goal_\(index + 1)",
                    headline: headline,
                    value: goal,
                    confidence: 0.82,
                    priority: max(0.65, 0.95 - (Double(index) * 0.08)),
                    source: .history,
                    lastConfirmedAt: lastConfirmedAt,
                    decayPolicy: .medium,
                    retrievalTags: tags(from: goal) + ["goal", "long_term"],
                    evidenceCount: items.count,
                    provenanceSummary: "Promoted from repeated long-term fields in balance and mirror workspaces.",
                    promotionPolicy: .immediate
                )
            }
    }

    private static func situationalDrafts(
        checkEvents: [CheckEvent],
        balanceRecords: [BalanceDecisionRecord],
        mirrorRecords: [MirrorDecisionRecord]
    ) -> [DecisionMemoryDraft] {
        var drafts: [DecisionMemoryDraft] = []

        if let event = checkEvents.first {
            let note = normalized(event.note)
            let headline = note.isEmpty
                ? "Recently revisiting \(event.scenario.title.lowercased()) pressure."
                : "Recently carrying: \(clipped(note, limit: 96))"

            drafts.append(
                DecisionMemoryDraft(
                    id: "situational.quick.latest",
                    type: .situational,
                    topic: "recent_quick_loop",
                    headline: headline,
                    value: note.isEmpty ? event.scenario.title : note,
                    confidence: 0.7,
                    priority: 0.72,
                    source: .history,
                    lastConfirmedAt: event.createdAt,
                    decayPolicy: .fast,
                    retrievalTags: [event.scenario.rawValue, "quick", "recent"] + tags(from: note),
                    evidenceCount: 1,
                    provenanceSummary: "Candidate memory staged from the latest quick-check loop.",
                    promotionPolicy: .candidateOnly
                )
            )
        }

        if let record = balanceRecords.first {
            let prompt = normalized(record.prompt)
            if !prompt.isEmpty {
                drafts.append(
                    DecisionMemoryDraft(
                        id: "situational.balance.latest",
                        type: .situational,
                        topic: "recent_balance_board",
                        headline: "Recently weighing: \(clipped(prompt, limit: 96))",
                        value: prompt,
                        confidence: 0.74,
                        priority: 0.76,
                        source: .history,
                        lastConfirmedAt: record.updatedAt,
                        decayPolicy: .fast,
                        retrievalTags: ["balance", "recent"] + tags(from: prompt),
                        evidenceCount: 1,
                        provenanceSummary: "Candidate memory staged from the latest balance board.",
                        promotionPolicy: .candidateOnly
                    )
                )
            }
        }

        if let record = mirrorRecords.first {
            let prompt = normalized(record.prompt)
            if !prompt.isEmpty {
                drafts.append(
                    DecisionMemoryDraft(
                        id: "situational.mirror.latest",
                        type: .situational,
                        topic: "recent_mirror_question",
                        headline: "Recently reflecting on: \(clipped(prompt, limit: 96))",
                        value: prompt,
                        confidence: 0.78,
                        priority: 0.82,
                        source: .history,
                        lastConfirmedAt: record.updatedAt,
                        decayPolicy: .fast,
                        retrievalTags: ["mirror", "recent"] + tags(from: prompt),
                        evidenceCount: 1,
                        provenanceSummary: "Candidate memory staged from the latest mirror workspace.",
                        promotionPolicy: .candidateOnly
                    )
                )
            }
        }

        return drafts
    }

    private static func semanticDrafts(
        checkEvents: [CheckEvent],
        now: Date
    ) -> [DecisionMemoryDraft] {
        var drafts: [DecisionMemoryDraft] = []
        let scenarioGroups = Dictionary(grouping: checkEvents, by: \.scenario)
        if let dominantScenario = scenarioGroups
            .filter({ $0.value.count >= 2 })
            .max(by: { $0.value.count < $1.value.count }) {
            drafts.append(
                DecisionMemoryDraft(
                    id: "semantic.scenario.\(dominantScenario.key.rawValue)",
                    type: .semantic,
                    topic: "repeat_scenario",
                    headline: "\(dominantScenario.key.title) pressure keeps recurring.",
                    value: dominantScenario.key.title,
                    confidence: 0.75,
                    priority: 0.8,
                    source: .pattern,
                    lastConfirmedAt: dominantScenario.value.map(\.createdAt).max() ?? now,
                    decayPolicy: .slow,
                    retrievalTags: [dominantScenario.key.rawValue, "pattern", "repeat"],
                    evidenceCount: dominantScenario.value.count,
                    provenanceSummary: "Derived from repeated quick-check events in the same scenario.",
                    promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 2)
                )
            )
        }

        let lateNightEvents = checkEvents.filter { event in
            let hour = Calendar.current.component(.hour, from: event.createdAt)
            return hour >= 21 || hour < 6
        }
        if lateNightEvents.count >= 3, lateNightEvents.count * 2 >= checkEvents.count {
            drafts.append(
                DecisionMemoryDraft(
                    id: "semantic.pattern.late_night",
                    type: .semantic,
                    topic: "late_night_regulation",
                    headline: "Late sessions need lighter, shorter guidance.",
                    value: "late_night_support",
                    confidence: 0.73,
                    priority: 0.77,
                    source: .pattern,
                    lastConfirmedAt: lateNightEvents.map(\.createdAt).max() ?? now,
                    decayPolicy: .slow,
                    retrievalTags: ["night", "late", "fatigue", "support"],
                    evidenceCount: lateNightEvents.count,
                    provenanceSummary: "Derived from repeated late-night quick-check history.",
                    promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 3)
                )
            )
        }

        return drafts
    }

    private static func supportDrafts(checkEvents: [CheckEvent]) -> [DecisionMemoryDraft] {
        let actionGroups = Dictionary(grouping: checkEvents, by: \.finalAction)

        return actionGroups
            .filter { $0.value.count >= 2 }
            .sorted { $0.value.count > $1.value.count }
            .prefix(2)
            .compactMap { action, events in
                let (headline, tags): (String, [String]) = switch action {
                case .decideTomorrow:
                    (
                        "Putting it into Tomorrow Box often breaks the loop.",
                        ["support", "tomorrow", "delay", "loop_break"]
                    )
                case .leaveStimulus:
                    (
                        "Stepping away from the trigger usually helps faster.",
                        ["support", "stimulus", "step_away", "interrupt"]
                    )
                case .wait90s:
                    (
                        "A short pause usually creates enough space to reset.",
                        ["support", "pause", "wait", "interrupt"]
                    )
                case .goAheadAnyway, .continueMindfully:
                    (
                        "When it is genuinely aligned, acting cleanly beats over-processing.",
                        ["support", "aligned", "action", "clarity"]
                    )
                }

                return DecisionMemoryDraft(
                    id: "support.action.\(action.rawValue)",
                    type: .support,
                    topic: "action_support",
                    headline: headline,
                    value: action.title,
                    confidence: 0.72,
                    priority: 0.79,
                    source: .history,
                    lastConfirmedAt: events.map(\.createdAt).max() ?? .now,
                    decayPolicy: .medium,
                    retrievalTags: tags + ["quick", action.rawValue],
                    evidenceCount: events.count,
                    provenanceSummary: "Derived from repeated successful quick-check final actions.",
                    promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 2)
                )
            }
    }

    private static func buildSessionBiases(
        mode: DecisionMode,
        queryTags: Set<String>,
        records: [DecisionMemoryRecord],
        profileCore: [String],
        relevantMemories: [String],
        reactionWeights: DecisionReactionWeights,
        now: Date
    ) -> [String] {
        var biases = defaultSessionBiases(for: mode)

        if reactionWeights.briefLanguage >= 0.7 ||
            profileCore.contains(where: { $0.localizedCaseInsensitiveContains("short") || $0.localizedCaseInsensitiveContains("direct") }) {
            biases.append("Keep the language short and concrete.")
        }

        if queryTags.contains("night") || queryTags.contains("late") {
            biases.append("Avoid heavy, high-friction guidance late at night.")
        }

        if (queryTags.contains("night") || queryTags.contains("late")),
           records.contains(where: { $0.topic == "late_night_regulation" }) {
            biases.append("Keep the cognitive load light right now.")
        }

        if reactionWeights.lowCognitiveLoad >= 0.72 {
            biases.append("Keep the cognitive load light right now.")
        }

        if mode == .quick,
           (reactionWeights.interruptiveActionBias >= 0.74 ||
           relevantMemories.contains(where: {
               $0.localizedCaseInsensitiveContains("Tomorrow Box") ||
               $0.localizedCaseInsensitiveContains("pause") ||
               $0.localizedCaseInsensitiveContains("trigger")
           })) {
            biases.append("Favor interruptive next steps over extra analysis.")
        }

        if mode == .mirror, reactionWeights.boundaryNamingBias >= 0.8 {
            biases.append("Name the real boundary before softening it.")
        }

        if mode == .balance, reactionWeights.tradeoffClarityBias >= 0.8 {
            biases.append("Keep the trade-off explicit before polishing the language.")
        }

        let hour = Calendar.current.component(.hour, from: now)
        if hour >= 22 || hour < 6 {
            biases.append("Avoid heavy, high-friction guidance late at night.")
        }

        return orderedUnique(biases)
    }

    private static func defaultSessionBiases(for mode: DecisionMode) -> [String] {
        switch mode {
        case .quick:
            ["Interrupt the loop before explaining too much."]
        case .balance:
            ["Keep the trade-off explicit and bounded."]
        case .mirror:
            ["Name the tension before suggesting anything."]
        }
    }

    private static func buildReactionWeights(
        mode: DecisionMode,
        queryTags: Set<String>,
        orderedItems: [BrainMemoryItem],
        checkEvents: [CheckEvent],
        records: [DecisionMemoryRecord],
        profileCore: [String],
        activeGoals: [String],
        relevantMemories: [String]
    ) -> DecisionReactionWeights {
        var weights = DecisionReactionWeights.defaults(for: mode)
        let memoryText = (
            profileCore +
            activeGoals +
            relevantMemories +
            orderedItems.prefix(6).map(\.headline)
        )
        .joined(separator: " ")
        .lowercased()

        if records.contains(where: { $0.id == "preference.communication.concise" }) ||
            memoryText.contains("short") ||
            memoryText.contains("direct") {
            weights.briefLanguage += 0.24
            weights.warmDirectTone += 0.08
        }

        if queryTags.contains("night") ||
            queryTags.contains("late") ||
            records.contains(where: { $0.id == "semantic.pattern.late_night" }) {
            weights.lowCognitiveLoad += 0.3
            weights.briefLanguage += 0.12
            weights.warmDirectTone += 0.06
        }

        if mode == .quick &&
            (records.contains(where: { $0.id == "support.action.decideTomorrow" }) ||
             records.contains(where: { $0.id == "support.action.wait90s" }) ||
             records.contains(where: { $0.id == "support.action.leaveStimulus" }) ||
             memoryText.contains("tomorrow box") ||
             memoryText.contains("pause") ||
            memoryText.contains("trigger")) {
            weights.interruptiveActionBias += 0.24
        }

        let positiveInterruptiveReflections = checkEvents.filter { event in
            guard let reflection = event.reflectionOutcome else { return false }
            return interruptiveActions.contains(event.finalAction) && positiveReflectionOutcomes.contains(reflection)
        }.count

        let negativeProceedReflections = checkEvents.filter { event in
            guard let reflection = event.reflectionOutcome else { return false }
            return proceedActions.contains(event.finalAction) && negativeReflectionOutcomes.contains(reflection)
        }.count

        let positiveProceedReflections = checkEvents.filter { event in
            guard let reflection = event.reflectionOutcome else { return false }
            return proceedActions.contains(event.finalAction) && positiveReflectionOutcomes.contains(reflection)
        }.count

        if positiveInterruptiveReflections > 0 || negativeProceedReflections > 0 {
            let interruptiveBoost = Double(positiveInterruptiveReflections + negativeProceedReflections) * 0.08
            weights.interruptiveActionBias += min(0.28, interruptiveBoost)
            weights.lowCognitiveLoad += min(0.16, Double(positiveInterruptiveReflections) * 0.05)
        }

        if positiveProceedReflections > 0 {
            let proceedStability = min(0.18, Double(positiveProceedReflections) * 0.05)
            weights.interruptiveActionBias -= proceedStability
            weights.warmDirectTone += min(0.1, Double(positiveProceedReflections) * 0.03)
        }

        if mode == .mirror ||
            memoryText.contains("shrinking") ||
            memoryText.contains("boundary") ||
            memoryText.contains("cost") ||
            memoryText.contains("relationship") {
            weights.boundaryNamingBias += 0.18
            weights.warmDirectTone += 0.06
        }

        if mode == .balance ||
            queryTags.contains("tradeoff") ||
            queryTags.contains("constraint") ||
            memoryText.contains("trade-off") ||
            memoryText.contains("cash versus") ||
            memoryText.contains("protect sleep") {
            weights.tradeoffClarityBias += 0.22
        }

        return rounded(clamped(weights))
    }

    private static let interruptiveActions: Set<CheckAction> = [
        .wait90s,
        .leaveStimulus,
        .decideTomorrow
    ]

    private static let proceedActions: Set<CheckAction> = [
        .goAheadAnyway,
        .continueMindfully
    ]

    private static let positiveReflectionOutcomes: Set<ReflectionOutcome> = [
        .betterThanExpected,
        .okay,
        .notNeeded
    ]

    private static let negativeReflectionOutcomes: Set<ReflectionOutcome> = [
        .regrettedIt,
        .feltEmptier
    ]

    private static func queryTags(for mode: DecisionMode, prompt: String) -> Set<String> {
        var tagsSet = Set(tags(from: prompt))
        tagsSet.insert(mode.rawValue)
        switch mode {
        case .quick:
            tagsSet.insert("quick")
        case .balance:
            tagsSet.insert("balance")
        case .mirror:
            tagsSet.insert("mirror")
        }
        return tagsSet
    }

    private static func score(
        _ memory: BrainMemoryItem,
        mode: DecisionMode,
        queryTags: Set<String>,
        now: Date
    ) -> Double {
        let overlap = Double(Set(memory.retrievalTags).intersection(queryTags).count)
        let typeBoost: Double = switch (mode, memory.type) {
        case (.quick, .support):
            3.4
        case (.quick, .semantic):
            2.8
        case (.quick, .situational):
            2.4
        case (.balance, .goal), (.balance, .semantic):
            3.0
        case (.mirror, .situational), (.mirror, .semantic), (.mirror, .goal):
            3.4
        case (_, .preference), (_, .identity):
            1.8
        default:
            1.0
        }

        let ageInDays = max(0, now.timeIntervalSince(memory.lastConfirmedAt) / 86_400)
        let decayMultiplier: Double = switch memory.decayPolicy {
        case .stable:
            1.0
        case .slow:
            max(0.82, 1.0 - (ageInDays / 240))
        case .medium:
            max(0.65, 1.0 - (ageInDays / 120))
        case .fast:
            max(0.45, 1.0 - (ageInDays / 45))
        }

        let pendingPenalty = memory.isPending ? 0.88 : 1.0
        return ((memory.priority * 5) + (memory.confidence * 3) + overlap + typeBoost) *
            decayMultiplier *
            pendingPenalty
    }

    private static func memorySort(_ lhs: DecisionMemoryDraft, _ rhs: DecisionMemoryDraft) -> Bool {
        if lhs.priority == rhs.priority {
            return lhs.lastConfirmedAt > rhs.lastConfirmedAt
        }
        return lhs.priority > rhs.priority
    }

    private static func memorySort(_ lhs: BrainMemoryItem, _ rhs: BrainMemoryItem) -> Bool {
        if lhs.priority == rhs.priority {
            if lhs.isPending != rhs.isPending {
                return !lhs.isPending
            }
            return lhs.lastConfirmedAt > rhs.lastConfirmedAt
        }
        return lhs.priority > rhs.priority
    }

    private static func selectItems(
        from orderedItems: [BrainMemoryItem],
        limit: Int,
        excludingIDs: Set<String> = [],
        matching predicate: (BrainMemoryItem) -> Bool
    ) -> [BrainMemoryItem] {
        var selected: [BrainMemoryItem] = []
        var seenHeadlines = Set<String>()

        for item in orderedItems where predicate(item) {
            guard !excludingIDs.contains(item.id) else { continue }
            guard seenHeadlines.insert(item.headline).inserted else { continue }
            selected.append(item)
            if selected.count == limit {
                break
            }
        }

        return selected
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func clipped(_ value: String, limit: Int) -> String {
        let normalizedValue = normalized(value)
        guard normalizedValue.count > limit else { return normalizedValue }
        return String(normalizedValue.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let lowered = normalized(value).lowercased()
        let scalarView = lowered.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let slug = String(scalarView)
            .split(separator: "-")
            .prefix(8)
            .joined(separator: "-")
        return slug.isEmpty ? "memory" : slug
    }

    private static func tags(from text: String) -> [String] {
        let stopwords: Set<String> = [
            "the", "and", "for", "that", "with", "this", "from", "into",
            "have", "just", "been", "than", "then", "they", "them",
            "want", "need", "feel", "will", "your", "about", "after",
            "before", "would", "should", "could", "again", "really",
            "maybe", "because", "when", "what", "where", "while", "into"
        ]

        let tokens = normalized(text)
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 && !stopwords.contains($0) }

        return orderedUnique(Array(tokens.prefix(8)))
    }

    private static func maxDate(_ values: [Date], fallback: Date) -> Date {
        values.max() ?? fallback
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func clamped(_ weights: DecisionReactionWeights) -> DecisionReactionWeights {
        DecisionReactionWeights(
            briefLanguage: max(0, min(1, weights.briefLanguage)),
            warmDirectTone: max(0, min(1, weights.warmDirectTone)),
            lowCognitiveLoad: max(0, min(1, weights.lowCognitiveLoad)),
            interruptiveActionBias: max(0, min(1, weights.interruptiveActionBias)),
            boundaryNamingBias: max(0, min(1, weights.boundaryNamingBias)),
            tradeoffClarityBias: max(0, min(1, weights.tradeoffClarityBias))
        )
    }

    private static func rounded(_ weights: DecisionReactionWeights) -> DecisionReactionWeights {
        DecisionReactionWeights(
            briefLanguage: roundedWeight(weights.briefLanguage),
            warmDirectTone: roundedWeight(weights.warmDirectTone),
            lowCognitiveLoad: roundedWeight(weights.lowCognitiveLoad),
            interruptiveActionBias: roundedWeight(weights.interruptiveActionBias),
            boundaryNamingBias: roundedWeight(weights.boundaryNamingBias),
            tradeoffClarityBias: roundedWeight(weights.tradeoffClarityBias)
        )
    }

    private static func roundedWeight(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

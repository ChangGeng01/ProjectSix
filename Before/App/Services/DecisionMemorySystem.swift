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
    let tier: DecisionMemoryTier = .warm

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

    func makeRecord(
        observationCount: Int,
        lifecycleState: DecisionMemoryLifecycleState = .active,
        lastReviewedAt: Date? = nil
    ) -> DecisionMemoryRecord {
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
            provenanceSummary: provenanceSummary,
            lifecycleState: lifecycleState,
            lastReviewedAt: lastReviewedAt,
            tier: tier
        )
    }
}

enum DecisionMemorySystem {
    static let projectionRecordLimit = 72
    static let projectionCandidateLimit = 32
    static let projectionCheckEventLimit = 96

    struct BrainStateGovernanceSnapshot {
        let totalRecordCount: Int
        let totalCandidateCount: Int
        let pendingCandidateCount: Int
        let promotedCandidateCount: Int
        let deferredCandidateCount: Int
        let admittedCandidateCount: Int
    }

    struct BrainStateProjection {
        let checkEvents: [CheckEvent]
        let records: [DecisionMemoryRecord]
        let candidates: [DecisionMemoryCandidateRecord]
        let governanceSnapshot: BrainStateGovernanceSnapshot
        let refreshedAt: Date
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

    static func refreshProjection(
        in context: ModelContext,
        now: Date = .now
    ) -> BrainStateProjection {
        var governanceSnapshot = fetchGovernanceSnapshot(in: context)
        let records = fetchMemoryRecords(
            in: context,
            limit: projectionRecordLimit
        )
        let candidates = fetchCandidateRecords(
            in: context,
            limit: projectionCandidateLimit
        )
        let resolvedRecords: [DecisionMemoryRecord]
        let resolvedCandidates: [DecisionMemoryCandidateRecord]

        if governanceSnapshot.totalRecordCount == 0 && governanceSnapshot.totalCandidateCount == 0 {
            resolvedRecords = Array(
                refreshStoredMemories(in: context, now: now)
                    .prefix(projectionRecordLimit)
            )
            governanceSnapshot = fetchGovernanceSnapshot(in: context)
            resolvedCandidates = fetchCandidateRecords(
                in: context,
                limit: projectionCandidateLimit
            )
        } else {
            resolvedRecords = records
            resolvedCandidates = candidates
        }

        let checkEvents = fetchCheckEvents(in: context)
        let balanceRecords = fetchBalanceRecords(in: context)
        let mirrorRecords = fetchMirrorRecords(in: context)
        EmbeddingMemoryStore.rebuildIndex(
            records: resolvedRecords,
            candidates: resolvedCandidates,
            checkEvents: checkEvents,
            balance: balanceRecords,
            mirror: mirrorRecords
        )

        return BrainStateProjection(
            checkEvents: checkEvents,
            records: resolvedRecords,
            candidates: resolvedCandidates,
            governanceSnapshot: governanceSnapshot,
            refreshedAt: now
        )
    }

    static func loadBrainState(
        mode: DecisionMode,
        prompt: String,
        context: ModelContext,
        retrievalMode: DecisionRetrievalMode = .filtered,
        now: Date = .now
    ) -> DecisionBrainState {
        loadBrainState(
            mode: mode,
            prompt: prompt,
            projection: refreshProjection(in: context, now: now),
            retrievalMode: retrievalMode,
            now: now
        )
    }

    static func loadBrainState(
        mode: DecisionMode,
        prompt: String,
        projection: BrainStateProjection,
        retrievalMode: DecisionRetrievalMode = .filtered,
        now: Date = .now
    ) -> DecisionBrainState {
        let bootstrapped = BehavioralAISubstrateBridge.bootstrapBrainState(
            mode: mode,
            prompt: prompt,
            source: .sessionPrime,
            sourceSurface: .app,
            riskLevel: .low,
            taskGraph: nil,
            projection: projection,
            retrievalMode: retrievalMode,
            activeTemplateIDs: [],
            failureGuardIDs: [],
            now: now
        )
        return bootstrapped.brainState
    }

    static func fetchMemoryRecords(
        in context: ModelContext,
        limit: Int? = nil
    ) -> [DecisionMemoryRecord] {
        var descriptor = FetchDescriptor<DecisionMemoryRecord>(
            sortBy: [
                SortDescriptor(\.priority, order: .reverse),
                SortDescriptor(\.lastConfirmedAt, order: .reverse)
            ]
        )
        if let limit {
            descriptor.fetchLimit = limit
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchCandidateRecords(
        in context: ModelContext,
        limit: Int? = nil
    ) -> [DecisionMemoryCandidateRecord] {
        let pendingRaw = DecisionMemoryCandidateStatus.pending.rawValue
        var descriptor = FetchDescriptor<DecisionMemoryCandidateRecord>(
            predicate: #Predicate<DecisionMemoryCandidateRecord> {
                $0.statusRaw == pendingRaw
            },
            sortBy: [
                SortDescriptor(\.priority, order: .reverse),
                SortDescriptor(\.lastObservedAt, order: .reverse)
            ]
        )
        if let limit {
            descriptor.fetchLimit = limit
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchCheckEvents(in context: ModelContext) -> [CheckEvent] {
        var descriptor = FetchDescriptor<CheckEvent>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = projectionCheckEventLimit
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchBalanceRecords(in context: ModelContext) -> [BalanceDecisionRecord] {
        var descriptor = FetchDescriptor<BalanceDecisionRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 36
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchMirrorRecords(in context: ModelContext) -> [MirrorDecisionRecord] {
        var descriptor = FetchDescriptor<MirrorDecisionRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 36
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchGovernanceSnapshot(
        in context: ModelContext
    ) -> BrainStateGovernanceSnapshot {
        let pendingRaw = DecisionMemoryCandidateStatus.pending.rawValue
        let promotedRaw = DecisionMemoryCandidateStatus.promoted.rawValue
        let deferredRaw = DecisionMemoryGovernanceDecision.deferred.rawValue
        let admittedRaw = DecisionMemoryGovernanceDecision.admit.rawValue

        return BrainStateGovernanceSnapshot(
            totalRecordCount: fetchCount(FetchDescriptor<DecisionMemoryRecord>(), in: context),
            totalCandidateCount: fetchCount(FetchDescriptor<DecisionMemoryCandidateRecord>(), in: context),
            pendingCandidateCount: fetchCount(
                FetchDescriptor<DecisionMemoryCandidateRecord>(
                    predicate: #Predicate<DecisionMemoryCandidateRecord> {
                        $0.statusRaw == pendingRaw
                    }
                ),
                in: context
            ),
            promotedCandidateCount: fetchCount(
                FetchDescriptor<DecisionMemoryCandidateRecord>(
                    predicate: #Predicate<DecisionMemoryCandidateRecord> {
                        $0.statusRaw == promotedRaw
                    }
                ),
                in: context
            ),
            deferredCandidateCount: fetchCount(
                FetchDescriptor<DecisionMemoryCandidateRecord>(
                    predicate: #Predicate<DecisionMemoryCandidateRecord> {
                        $0.lastGovernanceDecisionRaw == deferredRaw
                    }
                ),
                in: context
            ),
            admittedCandidateCount: fetchCount(
                FetchDescriptor<DecisionMemoryCandidateRecord>(
                    predicate: #Predicate<DecisionMemoryCandidateRecord> {
                        $0.lastGovernanceDecisionRaw == admittedRaw
                    }
                ),
                in: context
            )
        )
    }

    private static func fetchCount<Model>(
        _ descriptor: FetchDescriptor<Model>,
        in context: ModelContext
    ) -> Int where Model: PersistentModel {
        (try? context.fetchCount(descriptor)) ?? 0
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

    private static func memorySort(_ lhs: DecisionMemoryDraft, _ rhs: DecisionMemoryDraft) -> Bool {
        if lhs.priority == rhs.priority {
            return lhs.lastConfirmedAt > rhs.lastConfirmedAt
        }
        return lhs.priority > rhs.priority
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

        let languageMode = DecisionLanguageMode.detect(sampleTexts: [text])
        let latinTokens = normalized(text)
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 && !stopwords.contains($0) }

        let tags = languageMode.retrievalTags +
            Array(latinTokens.prefix(6)) +
            hanTokens(from: text)

        return orderedUnique(Array(tags.prefix(10)))
    }

    private static func hanTokens(from text: String) -> [String] {
        let characters = Array(
            normalized(text)
                .filter { character in
                    character.unicodeScalars.contains(where: { $0.properties.isIdeographic })
                }
        )

        guard !characters.isEmpty else { return [] }

        var tokens: [String] = []
        let joined = String(characters)
        if joined.count <= 8 {
            tokens.append(joined)
        }

        if characters.count >= 2 {
            for index in 0..<(characters.count - 1) {
                tokens.append(String(characters[index...index + 1]))
            }
        }

        if characters.count >= 3 {
            for index in 0..<(characters.count - 2) {
                tokens.append(String(characters[index...index + 2]))
            }
        }

        return Array(orderedUnique(tokens).prefix(6))
    }

    private static func maxDate(_ values: [Date], fallback: Date) -> Date {
        values.max() ?? fallback
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

}

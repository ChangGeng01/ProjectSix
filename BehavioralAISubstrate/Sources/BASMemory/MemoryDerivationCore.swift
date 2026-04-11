import Foundation
import BASRuntimeCore

public enum BASDraftPromotionPolicy: Codable, Equatable, Sendable {
    case immediate
    case repeated(minConfirmationCount: Int, minEvidenceCount: Int)
    case candidateOnly
}

public struct BASDerivedMemoryDraft: Codable, Equatable, Sendable {
    public var id: String
    public var typeID: String
    public var topic: String
    public var headline: String
    public var value: String
    public var confidence: Double
    public var priority: Double
    public var sourceID: String
    public var lastConfirmedAt: Date
    public var decayPolicyID: String
    public var retrievalTags: [String]
    public var evidenceCount: Int
    public var provenanceSummary: String
    public var promotionPolicy: BASDraftPromotionPolicy
    public var tierID: String

    public init(
        id: String,
        typeID: String,
        topic: String,
        headline: String,
        value: String,
        confidence: Double,
        priority: Double,
        sourceID: String,
        lastConfirmedAt: Date,
        decayPolicyID: String,
        retrievalTags: [String],
        evidenceCount: Int,
        provenanceSummary: String,
        promotionPolicy: BASDraftPromotionPolicy,
        tierID: String = "warm"
    ) {
        self.id = id
        self.typeID = typeID
        self.topic = topic
        self.headline = headline
        self.value = value
        self.confidence = confidence
        self.priority = priority
        self.sourceID = sourceID
        self.lastConfirmedAt = lastConfirmedAt
        self.decayPolicyID = decayPolicyID
        self.retrievalTags = retrievalTags
        self.evidenceCount = evidenceCount
        self.provenanceSummary = provenanceSummary
        self.promotionPolicy = promotionPolicy
        self.tierID = tierID
    }
}

public struct BASSelfReminderMemoryInput: Codable, Equatable, Sendable {
    public var content: String
    public var lastUsedAt: Date

    public init(content: String, lastUsedAt: Date) {
        self.content = content
        self.lastUsedAt = lastUsedAt
    }
}

public struct BASCheckEventMemoryInput: Codable, Equatable, Sendable {
    public var id: String
    public var scenarioID: String
    public var scenarioTitle: String
    public var actionID: String
    public var actionTitle: String
    public var note: String
    public var createdAt: Date

    public init(
        id: String,
        scenarioID: String,
        scenarioTitle: String,
        actionID: String,
        actionTitle: String,
        note: String,
        createdAt: Date
    ) {
        self.id = id
        self.scenarioID = scenarioID
        self.scenarioTitle = scenarioTitle
        self.actionID = actionID
        self.actionTitle = actionTitle
        self.note = note
        self.createdAt = createdAt
    }
}

public struct BASBalanceMemoryInput: Codable, Equatable, Sendable {
    public var prompt: String
    public var longTerm: String
    public var updatedAt: Date

    public init(prompt: String, longTerm: String, updatedAt: Date) {
        self.prompt = prompt
        self.longTerm = longTerm
        self.updatedAt = updatedAt
    }
}

public struct BASMirrorMemoryInput: Codable, Equatable, Sendable {
    public var prompt: String
    public var longTerm: String
    public var updatedAt: Date

    public init(prompt: String, longTerm: String, updatedAt: Date) {
        self.prompt = prompt
        self.longTerm = longTerm
        self.updatedAt = updatedAt
    }
}

public struct BASMemoryDerivationRequest: Codable, Equatable, Sendable {
    public var reminders: [BASSelfReminderMemoryInput]
    public var checkEvents: [BASCheckEventMemoryInput]
    public var balanceRecords: [BASBalanceMemoryInput]
    public var mirrorRecords: [BASMirrorMemoryInput]
    public var now: Date

    public init(
        reminders: [BASSelfReminderMemoryInput],
        checkEvents: [BASCheckEventMemoryInput],
        balanceRecords: [BASBalanceMemoryInput],
        mirrorRecords: [BASMirrorMemoryInput],
        now: Date
    ) {
        self.reminders = reminders
        self.checkEvents = checkEvents
        self.balanceRecords = balanceRecords
        self.mirrorRecords = mirrorRecords
        self.now = now
    }
}

public enum BASMemoryDraftCompiler {
    public static func derive(_ request: BASMemoryDerivationRequest) -> [BASDerivedMemoryDraft] {
        var drafts: [BASDerivedMemoryDraft] = []
        drafts += preferenceDrafts(
            reminders: request.reminders,
            checkEvents: request.checkEvents,
            now: request.now
        )
        drafts += goalDrafts(
            balanceRecords: request.balanceRecords,
            mirrorRecords: request.mirrorRecords
        )
        drafts += situationalDrafts(
            checkEvents: request.checkEvents,
            balanceRecords: request.balanceRecords,
            mirrorRecords: request.mirrorRecords
        )
        drafts += semanticDrafts(
            checkEvents: request.checkEvents,
            now: request.now
        )
        drafts += supportDrafts(checkEvents: request.checkEvents)

        var unique: [String: BASDerivedMemoryDraft] = [:]
        for draft in drafts {
            if let existing = unique[draft.id], memorySort(existing, draft) {
                continue
            }
            unique[draft.id] = draft
        }

        return Array(unique.values)
    }

    private static func preferenceDrafts(
        reminders: [BASSelfReminderMemoryInput],
        checkEvents: [BASCheckEventMemoryInput],
        now: Date
    ) -> [BASDerivedMemoryDraft] {
        var drafts: [BASDerivedMemoryDraft] = []
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
                    BASDerivedMemoryDraft(
                        id: "preference.communication.concise",
                        typeID: "preference",
                        topic: "communication_style",
                        headline: "Short, direct language lands better.",
                        value: "Prefer brief, concrete phrasing over long explanations.",
                        confidence: 0.78,
                        priority: 0.92,
                        sourceID: "pattern",
                        lastConfirmedAt: maxDate(
                            reminders.map(\.lastUsedAt) + checkEvents.map(\.createdAt),
                            fallback: now
                        ),
                        decayPolicyID: "slow",
                        retrievalTags: ["style", "communication", "concise", "direct"],
                        evidenceCount: allLengths.count,
                        provenanceSummary: "Derived from repeated short reminders and recent primary-loop note length.",
                        promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 3)
                    )
                )
            }
        }

        return drafts
    }

    private static func goalDrafts(
        balanceRecords: [BASBalanceMemoryInput],
        mirrorRecords: [BASMirrorMemoryInput]
    ) -> [BASDerivedMemoryDraft] {
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

                return BASDerivedMemoryDraft(
                    id: "goal.\(slug(goal))",
                    typeID: "goal",
                    topic: "active_goal_\(index + 1)",
                    headline: clipped(goal, limit: 120),
                    value: goal,
                    confidence: 0.82,
                    priority: max(0.65, 0.95 - (Double(index) * 0.08)),
                    sourceID: "history",
                    lastConfirmedAt: lastConfirmedAt,
                    decayPolicyID: "medium",
                    retrievalTags: tags(from: goal) + ["goal", "long_term"],
                    evidenceCount: items.count,
                    provenanceSummary: "Promoted from repeated long-term fields in comparative and reflective workspaces.",
                    promotionPolicy: .immediate
                )
            }
    }

    private static func situationalDrafts(
        checkEvents: [BASCheckEventMemoryInput],
        balanceRecords: [BASBalanceMemoryInput],
        mirrorRecords: [BASMirrorMemoryInput]
    ) -> [BASDerivedMemoryDraft] {
        var drafts: [BASDerivedMemoryDraft] = []

        if let event = checkEvents.first {
            let note = normalized(event.note)
            let headline = note.isEmpty
                ? "Recently revisiting \(event.scenarioTitle.lowercased()) pressure."
                : "Recently carrying: \(clipped(note, limit: 96))"

            drafts.append(
                BASDerivedMemoryDraft(
                    id: "situational.quick.latest",
                    typeID: "situational",
                    topic: "recent_quick_loop",
                    headline: headline,
                    value: note.isEmpty ? event.scenarioTitle : note,
                    confidence: 0.7,
                    priority: 0.72,
                    sourceID: "history",
                    lastConfirmedAt: event.createdAt,
                    decayPolicyID: "fast",
                    retrievalTags: [event.scenarioID, "quick", "recent"] + tags(from: note),
                    evidenceCount: 1,
                    provenanceSummary: "Candidate memory staged from the latest primary decision loop.",
                    promotionPolicy: .candidateOnly
                )
            )
        }

        if let record = balanceRecords.first {
            let prompt = normalized(record.prompt)
            if !prompt.isEmpty {
                drafts.append(
                    BASDerivedMemoryDraft(
                        id: "situational.balance.latest",
                        typeID: "situational",
                        topic: "recent_balance_board",
                        headline: "Recently weighing: \(clipped(prompt, limit: 96))",
                        value: prompt,
                        confidence: 0.74,
                        priority: 0.76,
                        sourceID: "history",
                        lastConfirmedAt: record.updatedAt,
                        decayPolicyID: "fast",
                        retrievalTags: ["balance", "recent"] + tags(from: prompt),
                        evidenceCount: 1,
                        provenanceSummary: "Candidate memory staged from the latest comparative workspace.",
                        promotionPolicy: .candidateOnly
                    )
                )
            }
        }

        if let record = mirrorRecords.first {
            let prompt = normalized(record.prompt)
            if !prompt.isEmpty {
                drafts.append(
                    BASDerivedMemoryDraft(
                        id: "situational.mirror.latest",
                        typeID: "situational",
                        topic: "recent_mirror_question",
                        headline: "Recently reflecting on: \(clipped(prompt, limit: 96))",
                        value: prompt,
                        confidence: 0.78,
                        priority: 0.82,
                        sourceID: "history",
                        lastConfirmedAt: record.updatedAt,
                        decayPolicyID: "fast",
                        retrievalTags: ["mirror", "recent"] + tags(from: prompt),
                        evidenceCount: 1,
                        provenanceSummary: "Candidate memory staged from the latest reflective workspace.",
                        promotionPolicy: .candidateOnly
                    )
                )
            }
        }

        return drafts
    }

    private static func semanticDrafts(
        checkEvents: [BASCheckEventMemoryInput],
        now: Date
    ) -> [BASDerivedMemoryDraft] {
        var drafts: [BASDerivedMemoryDraft] = []
        let scenarioGroups = Dictionary(grouping: checkEvents, by: \.scenarioID)

        if let dominantScenario = scenarioGroups
            .filter({ $0.value.count >= 2 })
            .max(by: { $0.value.count < $1.value.count }),
           let firstEvent = dominantScenario.value.first {
            drafts.append(
                BASDerivedMemoryDraft(
                    id: "semantic.scenario.\(dominantScenario.key)",
                    typeID: "semantic",
                    topic: "repeat_scenario",
                    headline: "\(firstEvent.scenarioTitle) pressure keeps recurring.",
                    value: firstEvent.scenarioTitle,
                    confidence: 0.75,
                    priority: 0.8,
                    sourceID: "pattern",
                    lastConfirmedAt: dominantScenario.value.map(\.createdAt).max() ?? now,
                    decayPolicyID: "slow",
                    retrievalTags: [dominantScenario.key, "pattern", "repeat"],
                    evidenceCount: dominantScenario.value.count,
                    provenanceSummary: "Derived from repeated primary-loop events in the same scenario.",
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
                BASDerivedMemoryDraft(
                    id: "semantic.pattern.late_night",
                    typeID: "semantic",
                    topic: "late_night_regulation",
                    headline: "Late sessions need lighter, shorter guidance.",
                    value: "late_night_support",
                    confidence: 0.73,
                    priority: 0.77,
                    sourceID: "pattern",
                    lastConfirmedAt: lateNightEvents.map(\.createdAt).max() ?? now,
                    decayPolicyID: "slow",
                    retrievalTags: ["night", "late", "fatigue", "support"],
                    evidenceCount: lateNightEvents.count,
                    provenanceSummary: "Derived from repeated late-night primary-loop history.",
                    promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 3)
                )
            )
        }

        return drafts
    }

    private static func supportDrafts(
        checkEvents: [BASCheckEventMemoryInput]
    ) -> [BASDerivedMemoryDraft] {
        let actionGroups = Dictionary(grouping: checkEvents, by: \.actionID)

        return actionGroups
            .filter { $0.value.count >= 2 }
            .sorted { $0.value.count > $1.value.count }
            .prefix(2)
            .compactMap { actionID, events in
                guard let first = events.first else { return nil }
                let (headline, tags): (String, [String])
                switch actionID {
                case "decideTomorrow":
                    headline = "Holding the decision often breaks the loop."
                    tags = ["support", "hold", "delay", "loop_break"]
                case "leaveStimulus":
                    headline = "Stepping away from the trigger usually helps faster."
                    tags = ["support", "stimulus", "step_away", "interrupt"]
                case "wait90s":
                    headline = "A short pause usually creates enough space to reset."
                    tags = ["support", "pause", "wait", "interrupt"]
                case "goAheadAnyway", "continueMindfully":
                    headline = "When it is genuinely aligned, acting cleanly beats over-processing."
                    tags = ["support", "aligned", "action", "clarity"]
                default:
                    headline = "\(first.actionTitle) tends to help in repeated loops."
                    tags = ["support", actionID]
                }

                return BASDerivedMemoryDraft(
                    id: "support.action.\(actionID)",
                    typeID: "support",
                    topic: "action_support",
                    headline: headline,
                    value: first.actionTitle,
                    confidence: 0.72,
                    priority: 0.79,
                    sourceID: "history",
                    lastConfirmedAt: events.map(\.createdAt).max() ?? .now,
                    decayPolicyID: "medium",
                    retrievalTags: tags + ["quick", actionID],
                    evidenceCount: events.count,
                    provenanceSummary: "Derived from repeated successful primary-loop final actions.",
                    promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 2)
                )
            }
    }

    private static func memorySort(_ lhs: BASDerivedMemoryDraft, _ rhs: BASDerivedMemoryDraft) -> Bool {
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

        let languageMode = BASLanguageMode.detect(sampleTexts: [text])
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

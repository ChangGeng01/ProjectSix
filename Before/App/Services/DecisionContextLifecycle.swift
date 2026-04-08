import Foundation

struct DecisionContextFieldRecord: Codable, Equatable, Sendable {
    var lastUpdatedAt: Date
    var generation: Int
}

struct DecisionContextLifecycleSnapshot: Codable, Equatable, Sendable {
    var schemaVersion: Int = 1
    var generation: Int = 0
    var refinementCountInGeneration: Int = 0
    var fieldRecords: [String: DecisionContextFieldRecord] = [:]
}

@MainActor
final class DecisionContextLifecycle {
    private enum Policy {
        static let maxRefinementsPerGeneration = 3
    }

    private struct FieldPolicy {
        let ttl: TimeInterval?
        let maxGenerationAge: Int?
        let sessionScoped: Bool
    }

    private(set) var snapshot: DecisionContextLifecycleSnapshot

    init(snapshot: DecisionContextLifecycleSnapshot = .init()) {
        self.snapshot = snapshot
    }

    func restore(_ snapshot: DecisionContextLifecycleSnapshot) {
        self.snapshot = snapshot
    }

    func touch(field: DecisionContextFieldKey, value: String, now: Date = .now) {
        let trimmed = trimmed(value)
        if trimmed.isEmpty {
            snapshot.fieldRecords.removeValue(forKey: field.rawValue)
            return
        }

        snapshot.fieldRecords[field.rawValue] = DecisionContextFieldRecord(
            lastUpdatedAt: now,
            generation: snapshot.generation
        )
    }

    func prepareQuickInput(
        _ input: QuickCheckInput,
        now: Date = .now
    ) -> (input: QuickCheckInput, state: DecisionContextPreparedState) {
        let state = beginRefinement(now: now)
        let noteIsActive = isActive(field: .quickNote, now: now, fallbackToPresence: !trimmed(input.note).isEmpty)

        return (
            QuickCheckInput(
                scenario: input.scenario,
                motivation: input.motivation,
                expectedOutcome: input.expectedOutcome,
                controlLevel: input.controlLevel,
                note: noteIsActive ? input.note : ""
            ),
            stateFor(
                rebuiltSession: state,
                fields: [.quickNote],
                active: noteIsActive ? [.quickNote] : [],
                stale: noteIsActive ? [] : (trimmed(input.note).isEmpty ? [] : [.quickNote])
            )
        )
    }

    func prepareBalanceInput(
        _ input: BalanceBoardInput,
        now: Date = .now
    ) -> (input: BalanceBoardInput, state: DecisionContextPreparedState) {
        let rebuilt = beginRefinement(now: now)
        let promptIsActive = isActive(field: .balancePrompt, now: now, fallbackToPresence: !trimmed(input.prompt).isEmpty)
        let desireIsActive = isActive(field: .balanceDesire, now: now, fallbackToPresence: !trimmed(input.desire).isEmpty)
        let concernIsActive = isActive(field: .balanceConcern, now: now, fallbackToPresence: !trimmed(input.concern).isEmpty)
        let constraintIsActive = isActive(field: .balanceConstraint, now: now, fallbackToPresence: !trimmed(input.constraint).isEmpty)
        let longTermIsActive = isActive(field: .balanceLongTerm, now: now, fallbackToPresence: !trimmed(input.longTerm).isEmpty)

        let active = [
            promptIsActive ? DecisionContextFieldKey.balancePrompt : nil,
            desireIsActive ? .balanceDesire : nil,
            concernIsActive ? .balanceConcern : nil,
            constraintIsActive ? .balanceConstraint : nil,
            longTermIsActive ? .balanceLongTerm : nil
        ].compactMap { $0 }

        let stale = [
            staleField(.balancePrompt, value: input.prompt, active: promptIsActive),
            staleField(.balanceDesire, value: input.desire, active: desireIsActive),
            staleField(.balanceConcern, value: input.concern, active: concernIsActive),
            staleField(.balanceConstraint, value: input.constraint, active: constraintIsActive),
            staleField(.balanceLongTerm, value: input.longTerm, active: longTermIsActive)
        ].compactMap { $0 }

        return (
            BalanceBoardInput(
                prompt: promptIsActive ? input.prompt : "",
                desire: desireIsActive ? input.desire : "",
                concern: concernIsActive ? input.concern : "",
                constraint: constraintIsActive ? input.constraint : "",
                longTerm: longTermIsActive ? input.longTerm : ""
            ),
            stateFor(
                rebuiltSession: rebuilt,
                fields: [.balancePrompt, .balanceDesire, .balanceConcern, .balanceConstraint, .balanceLongTerm],
                active: active,
                stale: stale
            )
        )
    }

    func prepareMirrorInput(
        _ input: MirrorInput,
        now: Date = .now
    ) -> (input: MirrorInput, state: DecisionContextPreparedState) {
        let rebuilt = beginRefinement(now: now)
        let promptIsActive = isActive(field: .mirrorPrompt, now: now, fallbackToPresence: !trimmed(input.prompt).isEmpty)
        let emotionIsActive = isActive(field: .mirrorEmotion, now: now, fallbackToPresence: !trimmed(input.emotion).isEmpty)
        let relationshipIsActive = isActive(field: .mirrorRelationship, now: now, fallbackToPresence: !trimmed(input.relationship).isEmpty)
        let realityIsActive = isActive(field: .mirrorReality, now: now, fallbackToPresence: !trimmed(input.reality).isEmpty)
        let longTermIsActive = isActive(field: .mirrorLongTerm, now: now, fallbackToPresence: !trimmed(input.longTerm).isEmpty)
        let selfLensIsActive = isActive(field: .mirrorSelfLens, now: now, fallbackToPresence: !trimmed(input.selfLens).isEmpty)

        let active = [
            promptIsActive ? DecisionContextFieldKey.mirrorPrompt : nil,
            emotionIsActive ? .mirrorEmotion : nil,
            relationshipIsActive ? .mirrorRelationship : nil,
            realityIsActive ? .mirrorReality : nil,
            longTermIsActive ? .mirrorLongTerm : nil,
            selfLensIsActive ? .mirrorSelfLens : nil
        ].compactMap { $0 }

        let stale = [
            staleField(.mirrorPrompt, value: input.prompt, active: promptIsActive),
            staleField(.mirrorEmotion, value: input.emotion, active: emotionIsActive),
            staleField(.mirrorRelationship, value: input.relationship, active: relationshipIsActive),
            staleField(.mirrorReality, value: input.reality, active: realityIsActive),
            staleField(.mirrorLongTerm, value: input.longTerm, active: longTermIsActive),
            staleField(.mirrorSelfLens, value: input.selfLens, active: selfLensIsActive)
        ].compactMap { $0 }

        return (
            MirrorInput(
                prompt: promptIsActive ? input.prompt : "",
                emotion: emotionIsActive ? input.emotion : "",
                relationship: relationshipIsActive ? input.relationship : "",
                reality: realityIsActive ? input.reality : "",
                longTerm: longTermIsActive ? input.longTerm : "",
                selfLens: selfLensIsActive ? input.selfLens : ""
            ),
            stateFor(
                rebuiltSession: rebuilt,
                fields: [.mirrorPrompt, .mirrorEmotion, .mirrorRelationship, .mirrorReality, .mirrorLongTerm, .mirrorSelfLens],
                active: active,
                stale: stale
            )
        )
    }

    private func beginRefinement(now: Date) -> Bool {
        let rebuilt = snapshot.refinementCountInGeneration >= Policy.maxRefinementsPerGeneration
        if rebuilt {
            snapshot.generation += 1
            snapshot.refinementCountInGeneration = 0
        }

        snapshot.refinementCountInGeneration += 1
        pruneExpiredRecords(now: now)
        return rebuilt
    }

    private func pruneExpiredRecords(now: Date) {
        let validRecords = snapshot.fieldRecords.filter { key, record in
            guard let field = DecisionContextFieldKey(rawValue: key) else { return false }
            return isActive(field: field, record: record, now: now)
        }
        snapshot.fieldRecords = validRecords
    }

    private func isActive(
        field: DecisionContextFieldKey,
        now: Date,
        fallbackToPresence: Bool
    ) -> Bool {
        guard let record = snapshot.fieldRecords[field.rawValue] else {
            return fallbackToPresence && policy(for: field).sessionScoped
        }
        return isActive(field: field, record: record, now: now)
    }

    private func isActive(
        field: DecisionContextFieldKey,
        record: DecisionContextFieldRecord,
        now: Date
    ) -> Bool {
        let policy = policy(for: field)
        if policy.sessionScoped {
            return true
        }

        if let ttl = policy.ttl, now.timeIntervalSince(record.lastUpdatedAt) > ttl {
            return false
        }

        if let maxGenerationAge = policy.maxGenerationAge,
           snapshot.generation - record.generation > maxGenerationAge {
            return false
        }

        return true
    }

    private func stateFor(
        rebuiltSession: Bool,
        fields: [DecisionContextFieldKey],
        active: [DecisionContextFieldKey],
        stale: [DecisionContextFieldKey]
    ) -> DecisionContextPreparedState {
        let anchorFields = fields.filter { isAnchor(field: $0) && active.contains($0) }

        return DecisionContextPreparedState(
            rebuiltSession: rebuiltSession,
            generation: snapshot.generation,
            anchorFields: anchorFields,
            activeFields: fields.filter { active.contains($0) },
            staleFields: fields.filter { stale.contains($0) }
        )
    }

    private func staleField(
        _ field: DecisionContextFieldKey,
        value: String,
        active: Bool
    ) -> DecisionContextFieldKey? {
        active || trimmed(value).isEmpty ? nil : field
    }

    private func policy(for field: DecisionContextFieldKey) -> FieldPolicy {
        switch field {
        case .balancePrompt, .mirrorPrompt:
            return FieldPolicy(ttl: nil, maxGenerationAge: nil, sessionScoped: true)
        case .quickNote, .mirrorEmotion:
            return FieldPolicy(ttl: 60 * 20, maxGenerationAge: 1, sessionScoped: false)
        case .balanceDesire, .balanceConcern, .balanceConstraint, .balanceLongTerm:
            return FieldPolicy(ttl: 60 * 30, maxGenerationAge: 1, sessionScoped: false)
        case .mirrorRelationship, .mirrorReality, .mirrorLongTerm, .mirrorSelfLens:
            return FieldPolicy(ttl: 60 * 45, maxGenerationAge: 2, sessionScoped: false)
        }
    }

    private func isAnchor(field: DecisionContextFieldKey) -> Bool {
        policy(for: field).sessionScoped
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

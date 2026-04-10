import Foundation
import SwiftData
import BASMemory

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
        struct Diagnostics {
            let recordCount: Int
            let candidateCount: Int
            let allCandidatesPending: Bool
        }

        let baseProjection: BASBrainProjection
        let governanceSnapshot: BrainStateGovernanceSnapshot
        let diagnostics: Diagnostics
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
            baseProjection: compileBaseProjection(
                records: resolvedRecords,
                candidates: resolvedCandidates,
                checkEvents: checkEvents,
                governanceSnapshot: governanceSnapshot
            ),
            governanceSnapshot: governanceSnapshot,
            diagnostics: BrainStateProjection.Diagnostics(
                recordCount: resolvedRecords.count,
                candidateCount: resolvedCandidates.count,
                allCandidatesPending: resolvedCandidates.allSatisfy { $0.status == .pending }
            ),
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

    private static func compileBaseProjection(
        records: [DecisionMemoryRecord],
        candidates: [DecisionMemoryCandidateRecord],
        checkEvents: [CheckEvent],
        governanceSnapshot: BrainStateGovernanceSnapshot
    ) -> BASBrainProjection {
        BASBrainProjectionCompiler.compile(
            BASBrainProjectionCompileRequest(
                records: records.map { record in
                    BASProjectionGovernedMemoryInput(
                        id: record.id,
                        typeID: record.type.rawValue,
                        headline: record.headline,
                        confidence: record.confidence,
                        sourceID: record.source.rawValue,
                        lastConfirmedAt: record.lastConfirmedAt,
                        lifecycleStateID: record.lifecycleState.rawValue,
                        tierID: record.tier.rawValue,
                        provenanceSummary: record.provenanceSummary
                    )
                },
                candidates: candidates.map { candidate in
                    BASProjectionCandidateInput(
                        id: candidate.id,
                        typeID: candidate.type.rawValue,
                        headline: candidate.headline,
                        confidence: candidate.confidence,
                        priority: candidate.priority,
                        sourceID: candidate.source.rawValue,
                        retrievalTags: candidate.retrievalTags,
                        lastObservedAt: candidate.lastObservedAt,
                        decayPolicyID: candidate.decayPolicy.rawValue,
                        statusID: candidate.status.rawValue,
                        governanceDecisionID: candidate.lastGovernanceDecision.rawValue,
                        evidenceCount: candidate.evidenceCount,
                        provenanceSummary: candidate.provenanceSummary
                    )
                },
                events: checkEvents.map { event in
                    BASProjectionEventInput(
                        id: event.id.uuidString,
                        note: event.note,
                        fallbackContent: event.scenario.title,
                        createdAt: event.createdAt,
                        scenarioID: event.scenario.rawValue,
                        actionID: event.finalAction.rawValue,
                        reflectionOutcomeID: event.reflectionOutcome?.rawValue,
                        entrySourceID: event.entrySource.rawValue
                    )
                },
                governanceSnapshot: BASProjectionGovernanceInput(
                    totalRecordCount: governanceSnapshot.totalRecordCount,
                    totalCandidateCount: governanceSnapshot.totalCandidateCount,
                    pendingCandidateCount: governanceSnapshot.pendingCandidateCount,
                    promotedCandidateCount: governanceSnapshot.promotedCandidateCount,
                    deferredCandidateCount: governanceSnapshot.deferredCandidateCount,
                    admittedCandidateCount: governanceSnapshot.admittedCandidateCount
                )
            )
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

        return BASMemoryDraftCompiler.derive(
            BASMemoryDerivationRequest(
                reminders: reminders.map {
                    BASSelfReminderMemoryInput(
                        content: $0.content,
                        lastUsedAt: $0.lastUsedAt
                    )
                },
                checkEvents: checkEvents.map { event in
                    BASCheckEventMemoryInput(
                        id: event.id.uuidString,
                        scenarioID: event.scenario.rawValue,
                        scenarioTitle: event.scenario.title,
                        actionID: event.finalAction.rawValue,
                        actionTitle: event.finalAction.title,
                        note: event.note,
                        createdAt: event.createdAt
                    )
                },
                balanceRecords: balanceRecords.map {
                    BASBalanceMemoryInput(
                        prompt: $0.prompt,
                        longTerm: $0.longTerm,
                        updatedAt: $0.updatedAt
                    )
                },
                mirrorRecords: mirrorRecords.map {
                    BASMirrorMemoryInput(
                        prompt: $0.prompt,
                        longTerm: $0.longTerm,
                        updatedAt: $0.updatedAt
                    )
                },
                now: now
            )
        )
        .map(makeDraft(from:))
    }

    private static func makeDraft(from derived: BASDerivedMemoryDraft) -> DecisionMemoryDraft {
        DecisionMemoryDraft(
            id: derived.id,
            type: DecisionMemoryType(rawValue: derived.typeID) ?? .semantic,
            topic: derived.topic,
            headline: derived.headline,
            value: derived.value,
            confidence: derived.confidence,
            priority: derived.priority,
            source: DecisionMemorySource(rawValue: derived.sourceID) ?? .history,
            lastConfirmedAt: derived.lastConfirmedAt,
            decayPolicy: DecisionMemoryDecayPolicy(rawValue: derived.decayPolicyID) ?? .medium,
            retrievalTags: derived.retrievalTags,
            evidenceCount: derived.evidenceCount,
            provenanceSummary: derived.provenanceSummary,
            promotionPolicy: promotionPolicy(from: derived.promotionPolicy)
        )
    }

    private static func promotionPolicy(
        from policy: BASDraftPromotionPolicy
    ) -> DecisionMemoryDraft.PromotionPolicy {
        switch policy {
        case .immediate:
            .immediate
        case let .repeated(minConfirmationCount, minEvidenceCount):
            .repeated(
                minConfirmationCount: minConfirmationCount,
                minEvidenceCount: minEvidenceCount
            )
        case .candidateOnly:
            .candidateOnly
        }
    }

}

import Foundation
import SwiftData
import Testing
@testable import BASAppleLifecycleKit
@testable import BASAppleAdapters
@testable import BASHostKit
@testable import BASMemory

@Suite("BASApple Governed Persistence", .serialized)
struct BASAppleGovernedPersistenceTests {
    typealias Governed = BASAppleMemoryProjectionRefreshAdapterTests.RefreshGovernedFixture
    typealias Candidate = BASAppleMemoryProjectionRefreshAdapterTests.RefreshCandidateFixture
    typealias Cue = BASAppleMemoryProjectionRefreshAdapterTests.RefreshCueFixture
    typealias CheckEvent = BASAppleMemoryProjectionRefreshAdapterTests.RefreshCheckEventFixture
    typealias Comparative = BASAppleMemoryProjectionRefreshAdapterTests.RefreshComparativeFixture
    typealias Reflective = BASAppleMemoryProjectionRefreshAdapterTests.RefreshReflectiveFixture

    enum FixtureError: Error, Equatable {
        case embedding
    }

    final class ScramblingTemporalIO: BASApplePersistenceIO {
        var fetchedTypes: [Any.Type] = []

        func fetch<Model: PersistentModel>(
            _ type: Model.Type,
            in context: ModelContext
        ) throws -> [Model] {
            fetchedTypes.append(type)
            let models = try context.fetch(FetchDescriptor<Model>())
            guard ObjectIdentifier(type) == ObjectIdentifier(Comparative.self)
                    || ObjectIdentifier(type) == ObjectIdentifier(Reflective.self) else {
                return models
            }
            return models.sorted {
                String(describing: $0.persistentModelID) > String(describing: $1.persistentModelID)
            }
        }

        func save(_ context: ModelContext) throws {
            try context.save()
        }
    }

    @Test("each of the six authoritative fetch failures escapes before save or publication")
    func eachAuthoritativeFetchFailureEscapesBeforeSaveOrPublication() throws {
        let types: [Any.Type] = [
            Governed.self,
            Candidate.self,
            Cue.self,
            CheckEvent.self,
            Comparative.self,
            Reflective.self
        ]

        for failedType in types {
            let container = try makeContainer()
            let io = ApplePersistenceFaultIO()
            io.failFetch = { ObjectIdentifier($0) == ObjectIdentifier(failedType) }
            var rebuildCallCount = 0
            var caught: Error?
            do {
                _ = try refresh(
                    in: ModelContext(container),
                    using: io,
                    rebuildEmbeddings: { _, _, _, _, _ in rebuildCallCount += 1 }
                )
            } catch {
                caught = error
            }

            #expect(caught as? ApplePersistenceFixtureFault == .fetch)
            #expect(io.saveCallCount == 0)
            #expect(rebuildCallCount == 0)
        }
    }

    @Test("a later authoritative fetch failure cannot publish an earlier nonempty prefix")
    func laterFetchFailureCannotPublishEarlierPrefix() throws {
        let container = try makeContainer()
        let seed = ModelContext(container)
        seed.insert(Governed.basMake(from: governedFields(id: "stored", label: "stored")))
        seed.insert(Candidate.basMake(from: candidateFields(id: "stored", label: "stored")))
        seed.insert(Cue(content: "earlier cue", lastUsedAt: now))
        seed.insert(CheckEvent(
            id: "earlier-event",
            scenarioID: "scenario",
            scenarioTitle: "Scenario",
            actionID: "action",
            actionTitle: "Action",
            note: "Earlier event",
            createdAt: now
        ))
        seed.insert(Comparative(prompt: "earlier comparative", longTerm: "earlier", updatedAt: now))
        try seed.save()

        let io = ApplePersistenceFaultIO()
        io.failFetch = { ObjectIdentifier($0) == ObjectIdentifier(Reflective.self) }
        var rebuildCallCount = 0
        #expect(throws: ApplePersistenceFixtureFault.fetch) {
            _ = try refresh(
                in: ModelContext(container),
                using: io,
                rebuildEmbeddings: { _, _, _, _, _ in rebuildCallCount += 1 }
            )
        }
        #expect(io.saveCallCount == 0)
        #expect(rebuildCallCount == 0)
        #expect(io.fetchedTypes.count == 6)
    }

    @Test("failed and successful owned writes leave caller pending insert update and delete isolated")
    func ownedWritesLeaveCallerPendingChangesIsolated() throws {
        for failSave in [true, false] {
            let container = try makeContainer()
            let seed = ModelContext(container)
            seed.insert(Governed.basMake(from: governedFields(id: "update", label: "committed-update")))
            seed.insert(Governed.basMake(from: governedFields(id: "delete", label: "committed-delete")))
            try seed.save()

            let caller = ModelContext(container)
            let callerRows = try caller.fetch(FetchDescriptor<Governed>())
            callerRows.first { $0.basID == "update" }?.basHeadline = "caller-pending-update"
            if let pendingDelete = callerRows.first(where: { $0.basID == "delete" }) {
                caller.delete(pendingDelete)
            }
            caller.insert(Governed.basMake(from: governedFields(id: "caller-only", label: "caller-only")))

            let io = ApplePersistenceFaultIO()
            io.failSave = failSave
            var receipt: BASAppleMemoryReconciliationWriteResult?
            var caught: Error?
            do {
                receipt = try BASAppleMemoryReconciliationWriter.reconcile(
                    BASAppleMemoryPersistenceRequest(
                        drafts: [],
                        existingRecords: [],
                        existingCandidates: [],
                        reviewNow: now.addingTimeInterval(60)
                    ),
                    recordType: Governed.self,
                    candidateType: Candidate.self,
                    in: caller,
                    using: io
                )
            } catch {
                caught = error
            }

            #expect(caller.hasChanges)
            let pendingCallerRows = try caller.fetch(FetchDescriptor<Governed>())
            #expect(pendingCallerRows.contains { $0.basID == "caller-only" })
            #expect(pendingCallerRows.first { $0.basID == "update" }?.basHeadline == "caller-pending-update")
            #expect(pendingCallerRows.contains { $0.basID == "delete" } == false)
            if failSave {
                #expect(caught as? ApplePersistenceFixtureFault == .save)
                #expect(receipt == nil)
            } else {
                #expect(caught == nil)
                #expect(receipt?.orderedRecords.contains { $0.id == "caller-only" } == false)
            }

            let durable = try ModelContext(container).fetch(FetchDescriptor<Governed>())
            #expect(durable.contains { $0.basID == "caller-only" } == false)
            #expect(durable.first { $0.basID == "update" }?.basHeadline == "committed-update-headline")
            #expect(durable.contains { $0.basID == "delete" })
        }
    }

    @Test("a returned reconciliation receipt stays immutable after a same-ID replacement")
    func reconciliationReceiptStaysImmutableAfterReplacement() throws {
        let container = try makeContainer()
        let caller = ModelContext(container)
        let first = try BASAppleMemoryReconciliationWriter.reconcile(
            request(drafts: [draft(id: "same", label: "original")]),
            recordType: Governed.self,
            candidateType: Candidate.self,
            in: caller
        )
        let second = try BASAppleMemoryReconciliationWriter.reconcile(
            request(drafts: [draft(id: "same", label: "replacement", at: now.addingTimeInterval(60))]),
            recordType: Governed.self,
            candidateType: Candidate.self,
            in: caller
        )

        #expect(first.orderedRecords.first?.headline == "original-headline")
        #expect(second.orderedRecords.first?.headline == "replacement-headline")
    }

    @Test("empty governance saves once while populated read-only projection saves zero times")
    func optionalSaveCountsMatchGovernancePath() throws {
        do {
            let container = try makeContainer()
            try seedDerivationHistory(in: container)
            let io = ApplePersistenceFaultIO()
            var rebuildCallCount = 0
            let result = try refresh(
                in: ModelContext(container),
                using: io,
                rebuildEmbeddings: { _, _, _, _, _ in rebuildCallCount += 1 }
            )
            #expect(io.saveCallCount == 1)
            #expect(rebuildCallCount == 1)
            #expect(result.diagnostics.recordCount > 0)
        }

        do {
            let container = try makeContainer()
            let seed = ModelContext(container)
            seed.insert(Governed.basMake(from: governedFields(id: "existing", label: "existing")))
            try seed.save()
            let io = ApplePersistenceFaultIO()
            let result = try refresh(in: ModelContext(container), using: io)
            #expect(io.saveCallCount == 0)
            #expect(result.diagnostics.recordCount == 1)
        }
    }

    @Test("populated-store embedding inputs preserve raw retrieval tags")
    func populatedStoreEmbeddingInputsPreserveRawRetrievalTags() throws {
        let container = try makeContainer()
        let seed = ModelContext(container)
        var governed = governedFields(id: "raw-governed", label: "raw-governed")
        governed.retrievalTags = ["Z", "a", "Z"]
        var candidate = candidateFields(id: "raw-candidate", label: "raw-candidate")
        candidate.retrievalTags = ["Z", "a", "Z"]
        seed.insert(Governed.basMake(from: governed))
        seed.insert(Candidate.basMake(from: candidate))
        try seed.save()

        let io = ApplePersistenceFaultIO()
        var publishedGovernedTags: [String]?
        var publishedCandidateTags: [String]?
        _ = try refresh(
            in: ModelContext(container),
            using: io,
            rebuildEmbeddings: { records, candidates, _, _, _ in
                publishedGovernedTags = records.first?.retrievalTags
                publishedCandidateTags = candidates.first?.retrievalTags
            }
        )

        #expect(publishedGovernedTags == ["Z", "a", "Z"])
        #expect(publishedCandidateTags == ["Z", "a", "Z"])
        #expect(io.saveCallCount == 0)
    }

    @Test("post-mutation receipt conversion preserves raw retrieval tags")
    func postMutationReceiptConversionPreservesRawRetrievalTags() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        var governed = governedFields(id: "raw-governed", label: "raw-governed")
        governed.retrievalTags = ["Z", "a", "Z"]
        var candidate = candidateFields(id: "raw-candidate", label: "raw-candidate")
        candidate.retrievalTags = ["Z", "a", "Z"]
        context.insert(Governed.basMake(from: governed))
        context.insert(Candidate.basMake(from: candidate))
        try context.save()

        let outcome = BASAppleMemoryPersistenceOutcome(
            recordMutations: [],
            candidateMutations: [],
            orderedRecordIDs: ["raw-governed"],
            orderedCandidateIDs: ["raw-candidate"]
        )
        let receipt = BASAppleMemoryReconciliationWriter.makeReceipt(
            outcome: outcome,
            records: try context.fetch(FetchDescriptor<Governed>()),
            candidates: try context.fetch(FetchDescriptor<Candidate>())
        )

        #expect(receipt.orderedRecords.map(\.retrievalTags) == [["Z", "a", "Z"]])
        #expect(receipt.candidates.map(\.retrievalTags) == [["Z", "a", "Z"]])
    }

    @Test("tied temporal projection limits retain persistent-ID ordering")
    func tiedTemporalProjectionLimitsRetainPersistentIDOrdering() throws {
        let container = try makeContainer()
        let seed = ModelContext(container)
        seed.insert(Governed.basMake(from: governedFields(id: "existing", label: "existing")))
        let comparative = [
            Comparative(prompt: "comparative-one", longTerm: "one", updatedAt: now),
            Comparative(prompt: "comparative-two", longTerm: "two", updatedAt: now)
        ]
        let reflective = [
            Reflective(prompt: "reflective-one", longTerm: "one", updatedAt: now),
            Reflective(prompt: "reflective-two", longTerm: "two", updatedAt: now)
        ]
        comparative.forEach(seed.insert)
        reflective.forEach(seed.insert)
        try seed.save()

        let expectedComparativePrompt = comparative.sorted {
            String(describing: $0.persistentModelID) < String(describing: $1.persistentModelID)
        }.first?.prompt
        let expectedReflectivePrompt = reflective.sorted {
            String(describing: $0.persistentModelID) < String(describing: $1.persistentModelID)
        }.first?.prompt
        let io = ScramblingTemporalIO()
        var publishedComparativePrompts: [String] = []
        var publishedReflectivePrompts: [String] = []
        _ = try refresh(
            in: ModelContext(container),
            limits: BASAppleMemoryProjectionRefreshLimits(
                recordLimit: 64,
                candidateLimit: 24,
                checkEventLimit: 96,
                comparativeRecordLimit: 1,
                reflectiveRecordLimit: 1
            ),
            using: io,
            rebuildEmbeddings: { _, _, _, comparativeRecords, reflectiveRecords in
                publishedComparativePrompts = comparativeRecords.map(\.prompt)
                publishedReflectivePrompts = reflectiveRecords.map(\.prompt)
            }
        )

        #expect(publishedComparativePrompts == [expectedComparativePrompt].compactMap { $0 })
        #expect(publishedReflectivePrompts == [expectedReflectivePrompt].compactMap { $0 })
        #expect(io.fetchedTypes.count == 6)
    }

    @Test("stored-field conversion pins every governed and candidate field to independent literals")
    func storedFieldConversionPinsEveryField() {
        let governed = governedFields(id: "governed-literal", label: "governed")
        let governedActual = BASMemoryPersistenceApplier.governedFields(
            from: Governed.basMake(from: governed).basSnapshot
        )
        #expect(governedActual.id == "governed-literal")
        #expect(governedActual.typeID == "governed-type")
        #expect(governedActual.topic == "governed-topic")
        #expect(governedActual.headline == "governed-headline")
        #expect(governedActual.value == "governed-value")
        #expect(governedActual.confidence == 0.73)
        #expect(governedActual.priority == 0.81)
        #expect(governedActual.source == .pattern)
        #expect(governedActual.lastConfirmedAt == now)
        #expect(governedActual.decayPolicy == .slow)
        #expect(governedActual.retrievalTags == ["governed", "tag"])
        #expect(governedActual.evidenceCount == 4)
        #expect(governedActual.observationCount == 5)
        #expect(governedActual.provenanceSummary == "governed-provenance")
        #expect(governedActual.lifecycleState == .active)
        #expect(governedActual.lastReviewedAt == now.addingTimeInterval(1))
        #expect(governedActual.tierID == "governed-tier")

        let candidate = candidateFields(id: "candidate-literal", label: "candidate")
        let candidateActual = BASMemoryPersistenceApplier.candidateFields(
            from: Candidate.basMake(from: candidate).basSnapshot
        )
        #expect(candidateActual.id == "candidate-literal")
        #expect(candidateActual.typeID == "candidate-type")
        #expect(candidateActual.topic == "candidate-topic")
        #expect(candidateActual.headline == "candidate-headline")
        #expect(candidateActual.value == "candidate-value")
        #expect(candidateActual.confidence == 0.67)
        #expect(candidateActual.priority == 0.79)
        #expect(candidateActual.source == .pattern)
        #expect(candidateActual.firstObservedAt == now.addingTimeInterval(-10))
        #expect(candidateActual.lastObservedAt == now)
        #expect(candidateActual.decayPolicy == .medium)
        #expect(candidateActual.retrievalTags == ["candidate", "tag"])
        #expect(candidateActual.evidenceCount == 3)
        #expect(candidateActual.confirmationCount == 2)
        #expect(candidateActual.lastObservationFingerprint == "candidate-fingerprint")
        #expect(candidateActual.status == .pending)
        #expect(candidateActual.provenanceSummary == "candidate-provenance")
        #expect(candidateActual.lastWriteOperation == .update)
        #expect(candidateActual.lastGovernanceDecision == .admit)
        #expect(candidateActual.governanceReason == "candidate-reason")
        #expect(candidateActual.tierID == "candidate-tier")
    }

    @Test("embedding failure reports read-only no-write and committed dispositions without publication")
    func embeddingFailureReportsAllPersistenceDispositions() throws {
        do {
            let container = try makeContainer()
            let seed = ModelContext(container)
            seed.insert(Governed.basMake(from: governedFields(id: "existing", label: "existing")))
            try seed.save()
            let io = ApplePersistenceFaultIO()
            let error = try captureEmbeddingFailure(in: container, using: io)
            guard case .publicationFailed(let disposition, .embeddingRebuild, let underlying) = error,
                  case .readOnlyProjection = disposition else {
                Issue.record("Expected read-only publication disposition")
                return
            }
            #expect(underlying as? FixtureError == .embedding)
            #expect(io.saveCallCount == 0)
        }

        do {
            let container = try makeContainer()
            let io = ApplePersistenceFaultIO()
            let error = try captureEmbeddingFailure(in: container, using: io)
            guard case .publicationFailed(let disposition, .embeddingRebuild, _) = error,
                  case .reconciliationEvaluatedNoWrite(let receipt) = disposition else {
                Issue.record("Expected reconciliation-evaluated-no-write disposition")
                return
            }
            #expect(receipt.orderedRecords.isEmpty)
            #expect(io.saveCallCount == 0)
        }

        do {
            let container = try makeContainer()
            try seedDerivationHistory(in: container)
            let io = ApplePersistenceFaultIO()
            let error = try captureEmbeddingFailure(in: container, using: io)
            guard case .publicationFailed(let disposition, .embeddingRebuild, _) = error,
                  case .committedReconciliation(let receipt) = disposition else {
                Issue.record("Expected committed-reconciliation disposition")
                return
            }
            #expect(receipt.orderedRecords.isEmpty == false)
            #expect(io.saveCallCount == 1)
            #expect((try ModelContext(container).fetch(FetchDescriptor<Governed>())).isEmpty == false)
        }
    }

    @Test("multiple configurations are refused before fetch save or embedding publication")
    func multipleConfigurationsAreRefusedBeforeOperations() throws {
        let schema = allSchema
        let container = try ModelContainer(
            for: schema,
            configurations: [
                ModelConfiguration("governance", schema: Schema([Governed.self, Candidate.self]), isStoredInMemoryOnly: true),
                ModelConfiguration("history", schema: Schema([Cue.self, CheckEvent.self, Comparative.self, Reflective.self]), isStoredInMemoryOnly: true)
            ]
        )
        let io = ApplePersistenceFaultIO()
        var rebuildCallCount = 0
        do {
            _ = try refresh(
                in: ModelContext(container),
                using: io,
                rebuildEmbeddings: { _, _, _, _, _ in rebuildCallCount += 1 }
            )
            Issue.record("Expected multiple configurations to be refused")
        } catch {
            #expect(error as? BASApplePersistenceTransactionError == .requiresSingleConfiguration(actual: 2))
        }
        #expect(io.fetchedTypes.isEmpty)
        #expect(io.saveCallCount == 0)
        #expect(rebuildCallCount == 0)
    }

    @Test("runtime bridge executors stop bootstrap and publication after projection failure")
    func runtimeBridgeExecutorsStopAfterProjectionFailure() {
        var calls: [String] = []
        #expect(throws: FixtureError.embedding) {
            _ = try BASAppleCurrentBrainRuntimeBridgeExecutor.primeSession(
                input: BASAppleCurrentBrainSessionBridgeInput(
                    modeID: "primary",
                    promptFragments: ["wait"],
                    projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
                    retrievalMode: "filtered",
                    bootstrapBehavior: .generic,
                    cognitionBehavior: .generic
                ),
                refreshMemoryProjection: {
                    calls.append("projection")
                    throw FixtureError.embedding
                },
                bootstrapCurrentBrain: { _ in
                    calls.append("brain")
                    return "brain"
                },
                afterBootstrap: { _ in calls.append("after") }
            )
        }
        #expect(calls == ["projection"])

        calls.removeAll()
        #expect(throws: FixtureError.embedding) {
            _ = try BASAppleCurrentBrainRuntimeBridgeExecutor.primeSession(
                input: BASAppleCurrentBrainSessionBridgeInput(
                    modeID: "primary",
                    promptFragments: ["wait"],
                    projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
                    retrievalMode: "filtered",
                    bootstrapBehavior: .generic,
                    cognitionBehavior: .generic
                ),
                refreshMemoryProjection: { calls.append("projection") },
                bootstrapCurrentBrain: { _ in
                    calls.append("brain")
                    throw FixtureError.embedding
                },
                afterBootstrap: { _ in calls.append("after") }
            )
        }
        #expect(calls == ["projection", "brain"])

        var activeBootstrapCallCount = 0
        #expect(throws: FixtureError.embedding) {
            _ = try BASAppleCurrentBrainRuntimeBridgeExecutor.refreshActiveBrain(
                input: BASAppleCurrentBrainActiveRefreshBridgeInput(
                    projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
                    retrievalModesByModeID: [:],
                    lifecycleBehavior: .generic,
                    bootstrapBehavior: .generic,
                    cognitionBehavior: .generic
                ),
                refreshMemoryProjection: { throw FixtureError.embedding },
                bootstrapCurrentBrain: { _ in
                    activeBootstrapCallCount += 1
                    return "brain"
                }
            )
        }
        #expect(activeBootstrapCallCount == 0)
    }

    @Test("successful file-store reconciliation reopens with complete values and canonical order")
    func successfulFileStoreReopensWithCompleteValuesAndOrder() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-governed-reopen-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("memory.store")
        let schema = Schema([Governed.self, Candidate.self])
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let seed = ModelContext(container)
            for id in ["update", "delete"] {
                seed.insert(Governed.basMake(from: governedFields(id: id, label: "seed-\(id)")))
                seed.insert(Candidate.basMake(from: candidateFields(id: id, label: "seed-\(id)")))
            }
            try seed.save()
        }

        let receipt: BASAppleMemoryReconciliationWriteResult
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            receipt = try BASAppleMemoryReconciliationWriter.reconcile(
                BASAppleMemoryPersistenceRequest(
                    drafts: [
                        draft(id: "update", label: "updated", at: now.addingTimeInterval(20)),
                        draft(id: "add", label: "added", at: now.addingTimeInterval(30)),
                        draft(
                            id: "delete",
                            label: "rejected",
                            tags: ["tool_observation"],
                            confidence: 0.2,
                            evidenceCount: 1
                        )
                    ],
                    existingRecords: [],
                    existingCandidates: [],
                    reviewNow: now.addingTimeInterval(40),
                    persistencePolicy: BASMemoryHorizonPersistencePolicy(contaminatedWriteMode: .reject)
                ),
                recordType: Governed.self,
                candidateType: Candidate.self,
                in: ModelContext(container)
            )
        }

        #expect(receipt.outcome.recordMutations.contains { $0.id == "add" && $0.operation == .add })
        #expect(receipt.outcome.recordMutations.contains { $0.id == "update" && $0.operation == .update })
        #expect(receipt.outcome.recordMutations.contains { $0.id == "delete" && $0.operation == .delete })
        #expect(receipt.outcome.candidateMutations.contains { $0.id == "add" && $0.operation == .add })
        #expect(receipt.outcome.candidateMutations.contains { $0.id == "update" && $0.operation == .update })
        #expect(receipt.outcome.candidateMutations.contains { $0.id == "delete" && $0.operation == .delete })

        let reopened = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(reopened)
        let recordsByID = Dictionary(
            try context.fetch(FetchDescriptor<Governed>()).map {
                let fields = BASGovernedMemoryStoredFields(snapshot: $0.basSnapshot)
                return (fields.id, fields)
            },
            uniquingKeysWith: { _, last in last }
        )
        let candidatesByID = Dictionary(
            try context.fetch(FetchDescriptor<Candidate>()).map {
                let fields = BASCandidateMemoryStoredFields(snapshot: $0.basSnapshot)
                return (fields.id, fields)
            },
            uniquingKeysWith: { _, last in last }
        )
        #expect(recordsByID.count == 2)
        #expect(Set(recordsByID.keys) == Set(["add", "update"]))
        #expect(recordsByID["delete"] == nil)
        #expect(candidatesByID.count == 2)
        #expect(Set(candidatesByID.keys) == Set(["add", "update"]))
        #expect(candidatesByID["delete"] == nil)
        #expect(receipt.orderedRecords.map(\.id) == ["add", "update"])
        #expect(receipt.candidates.map(\.id) == ["add", "update"])
        #expect(["add", "update"].compactMap { recordsByID[$0] } == receipt.orderedRecords)
        #expect(["add", "update"].compactMap { candidatesByID[$0] } == receipt.candidates)
    }

    @Test("committed reconciliation survives embedding failure and file reopen without host publication")
    func committedReconciliationSurvivesEmbeddingFailureAndFileReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-governed-embedding-failure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("memory.store")
        let configuration = ModelConfiguration(schema: allSchema, url: storeURL, cloudKitDatabase: .none)

        do {
            let container = try ModelContainer(for: allSchema, configurations: [configuration])
            try seedDerivationHistory(in: container)
        }

        var committedReceipt: BASAppleMemoryReconciliationWriteResult?
        let io = ApplePersistenceFaultIO()
        var resolverCallCount = 0
        var embeddingCallCount = 0
        var committedProjection: BASAppleMemoryProjectionRefreshResult?
        var projectionDirty = true
        var publishedNotice: String?
        do {
            let container = try ModelContainer(for: allSchema, configurations: [configuration])
            let runtime = BASHostRuntime(configuration: .fixtureGeneric)
            do {
                try runtime.resolveProjectionRefresh(
                    using: { () throws -> BASAppleProjectionRefreshResult<BASAppleMemoryProjectionRefreshResult> in
                        resolverCallCount += 1
                        let projection = try refresh(
                            in: ModelContext(container),
                            using: io,
                            rebuildEmbeddings: { _, _, _, _, _ in
                                embeddingCallCount += 1
                                throw FixtureError.embedding
                            }
                        )
                        return BASAppleProjectionRefreshResult(
                            projection: projection,
                            refreshed: true,
                            notice: "must not publish"
                        )
                    },
                    commitProjection: { committedProjection = $0 },
                    setProjectionDirty: { projectionDirty = $0 },
                    publishNotice: { publishedNotice = $0 }
                )
                Issue.record("Expected embedding publication to fail")
            } catch let error as BASAppleMemoryProjectionRefreshError {
                guard case .publicationFailed(let disposition, .embeddingRebuild, let underlying) = error,
                      case .committedReconciliation(let receipt) = disposition else {
                    Issue.record("Expected committed reconciliation publication failure")
                    return
                }
                #expect(underlying as? FixtureError == .embedding)
                committedReceipt = receipt
            }
        }

        #expect(resolverCallCount == 1)
        #expect(embeddingCallCount == 1)
        #expect(io.saveCallCount == 1)
        #expect(committedProjection == nil)
        #expect(projectionDirty)
        #expect(publishedNotice == nil)

        let receipt = try #require(committedReceipt)
        let reopened = try ModelContainer(for: allSchema, configurations: [configuration])
        let context = ModelContext(reopened)
        let reopenedRecords = try context.fetch(FetchDescriptor<Governed>())
            .map { BASGovernedMemoryStoredFields(snapshot: $0.basSnapshot) }
        let reopenedCandidates = try context.fetch(FetchDescriptor<Candidate>())
            .map { BASCandidateMemoryStoredFields(snapshot: $0.basSnapshot) }
        #expect(Set(reopenedRecords.map(\.id)) == Set(receipt.orderedRecords.map(\.id)))
        #expect(Set(reopenedCandidates.map(\.id)) == Set(receipt.candidates.map(\.id)))
        #expect(
            Dictionary(uniqueKeysWithValues: reopenedRecords.map { ($0.id, $0) })
                == Dictionary(uniqueKeysWithValues: receipt.orderedRecords.map { ($0.id, $0) })
        )
        #expect(
            Dictionary(uniqueKeysWithValues: reopenedCandidates.map { ($0.id, $0) })
                == Dictionary(uniqueKeysWithValues: receipt.candidates.map { ($0.id, $0) })
        )
    }

    private var now: Date { Date(timeIntervalSince1970: 1_744_200_000) }

    private var allSchema: Schema {
        Schema([Governed.self, Candidate.self, Cue.self, CheckEvent.self, Comparative.self, Reflective.self])
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: allSchema,
            configurations: [ModelConfiguration(schema: allSchema, isStoredInMemoryOnly: true)]
        )
    }

    private func seedDerivationHistory(in container: ModelContainer) throws {
        let context = ModelContext(container)
        context.insert(Cue(content: "Wait before acting.", lastUsedAt: now.addingTimeInterval(-30)))
        context.insert(CheckEvent(
            id: "event",
            scenarioID: "scenario",
            scenarioTitle: "Scenario",
            actionID: "action",
            actionTitle: "Action",
            note: "Waiting helped.",
            createdAt: now.addingTimeInterval(-20)
        ))
        context.insert(Comparative(prompt: "Compare", longTerm: "Waiting helped.", updatedAt: now.addingTimeInterval(-10)))
        context.insert(Reflective(prompt: "Reflect", longTerm: "Waiting helped.", updatedAt: now))
        try context.save()
    }

    private func refresh<IO: BASApplePersistenceIO>(
        in context: ModelContext,
        limits: BASAppleMemoryProjectionRefreshLimits = .default,
        using io: IO,
        rebuildEmbeddings: (
            [BASGovernedMemoryStoredFields],
            [BASCandidateMemoryStoredFields],
            [BASCheckEventMemoryInput],
            [BASComparativeMemoryInput],
            [BASReflectiveMemoryInput]
        ) throws -> Void = { _, _, _, _, _ in }
    ) throws -> BASAppleMemoryProjectionRefreshResult {
        try BASAppleMemoryProjectionRefreshAdapter.refreshProjection(
            in: context,
            now: now,
            limits: limits,
            recordType: Governed.self,
            candidateType: Candidate.self,
            cueType: Cue.self,
            checkEventType: CheckEvent.self,
            comparativeRecordType: Comparative.self,
            reflectiveRecordType: Reflective.self,
            using: io,
            rebuildEmbeddings: rebuildEmbeddings
        )
    }

    private func captureEmbeddingFailure(
        in container: ModelContainer,
        using io: ApplePersistenceFaultIO
    ) throws -> BASAppleMemoryProjectionRefreshError {
        do {
            _ = try refresh(
                in: ModelContext(container),
                using: io,
                rebuildEmbeddings: { _, _, _, _, _ in throw FixtureError.embedding }
            )
            Issue.record("Expected embedding rebuild to fail")
            throw FixtureError.embedding
        } catch let error as BASAppleMemoryProjectionRefreshError {
            return error
        }
    }

    private func request(drafts: [BASDerivedMemoryDraft]) -> BASAppleMemoryPersistenceRequest {
        BASAppleMemoryPersistenceRequest(
            drafts: drafts,
            existingRecords: [],
            existingCandidates: [],
            reviewNow: now
        )
    }

    private func draft(
        id: String,
        label: String,
        at date: Date? = nil,
        tags: [String] = ["tag"],
        confidence: Double = 0.91,
        evidenceCount: Int = 4
    ) -> BASDerivedMemoryDraft {
        BASDerivedMemoryDraft(
            id: id,
            typeID: "\(label)-type",
            topic: "\(label)-topic",
            headline: "\(label)-headline",
            value: "\(label)-value",
            confidence: confidence,
            priority: 0.82,
            sourceID: BASMemorySource.pattern.rawValue,
            lastConfirmedAt: date ?? now,
            decayPolicyID: BASMemoryDecayPolicy.slow.rawValue,
            retrievalTags: tags,
            evidenceCount: evidenceCount,
            provenanceSummary: "\(label)-provenance",
            promotionPolicy: .immediate,
            tierID: "\(label)-tier"
        )
    }

    private func governedFields(id: String, label: String) -> BASGovernedMemoryStoredFields {
        BASGovernedMemoryStoredFields(
            id: id,
            typeID: "\(label)-type",
            topic: "\(label)-topic",
            headline: "\(label)-headline",
            value: "\(label)-value",
            confidence: 0.73,
            priority: 0.81,
            source: .pattern,
            lastConfirmedAt: now,
            decayPolicy: .slow,
            retrievalTags: [label, "tag"].sorted(),
            evidenceCount: 4,
            observationCount: 5,
            provenanceSummary: "\(label)-provenance",
            lifecycleState: .active,
            lastReviewedAt: now.addingTimeInterval(1),
            tierID: "\(label)-tier"
        )
    }

    private func candidateFields(id: String, label: String) -> BASCandidateMemoryStoredFields {
        BASCandidateMemoryStoredFields(
            id: id,
            typeID: "\(label)-type",
            topic: "\(label)-topic",
            headline: "\(label)-headline",
            value: "\(label)-value",
            confidence: 0.67,
            priority: 0.79,
            source: .pattern,
            firstObservedAt: now.addingTimeInterval(-10),
            lastObservedAt: now,
            decayPolicy: .medium,
            retrievalTags: [label, "tag"].sorted(),
            evidenceCount: 3,
            confirmationCount: 2,
            lastObservationFingerprint: "\(label)-fingerprint",
            status: .pending,
            provenanceSummary: "\(label)-provenance",
            lastWriteOperation: .update,
            lastGovernanceDecision: .admit,
            governanceReason: "\(label)-reason",
            tierID: "\(label)-tier"
        )
    }
}

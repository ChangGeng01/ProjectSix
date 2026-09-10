import Foundation
import SwiftData
import Testing
@testable import BASAppleAdapters
@testable import BASAppleLifecycleKit
@testable import BASMemory

@Suite("BASApple Current Brain Update Writer")
struct BASAppleCurrentBrainUpdateWriterTests {
    @Model
    final class UpdateWriterFixture: BASAppleCurrentBrainUpdateEntity {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var source: String
        var mode: String
        var dominantGoal: String?
        var dominantReactionWeight: String
        var fingerprint: String
        var activeConstraints: [String]
        var activeTemplateIDs: [String]
        var failureGuardIDs: [String]

        init(fields: BASCurrentBrainUpdateStoredFields) {
            self.id = fields.id
            self.createdAt = fields.createdAt
            self.source = fields.source
            self.mode = fields.mode
            self.dominantGoal = fields.dominantGoal
            self.dominantReactionWeight = fields.dominantReactionWeight
            self.fingerprint = fields.fingerprint
            self.activeConstraints = fields.activeConstraints
            self.activeTemplateIDs = fields.activeTemplateIDs
            self.failureGuardIDs = fields.failureGuardIDs
        }

        static func basMake(from fields: BASCurrentBrainUpdateStoredFields) -> UpdateWriterFixture {
            UpdateWriterFixture(fields: fields)
        }

        var basSnapshot: BASCurrentBrainUpdateStoredFields {
            BASCurrentBrainUpdateStoredFields(
                id: id,
                createdAt: createdAt,
                source: source,
                mode: mode,
                dominantGoal: dominantGoal,
                dominantReactionWeight: dominantReactionWeight,
                fingerprint: fingerprint,
                activeConstraints: activeConstraints,
                activeTemplateIDs: activeTemplateIDs,
                failureGuardIDs: failureGuardIDs
            )
        }
    }

    @Test("writer does not commit an unrelated caller insert")
    func writerDoesNotCommitCallerInsert() throws {
        func fields(_ label: String) -> BASCurrentBrainUpdateStoredFields {
            BASCurrentBrainUpdateStoredFields(
                id: UUID(),
                createdAt: Date(timeIntervalSince1970: 1_744_000_000),
                source: label,
                mode: "primary",
                dominantGoal: label,
                dominantReactionWeight: "brief_language",
                fingerprint: label,
                activeConstraints: [],
                activeTemplateIDs: [],
                failureGuardIDs: []
            )
        }

        let container = try ModelContainer(
            for: UpdateWriterFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let caller = ModelContext(container)
        caller.autosaveEnabled = false
        let pending = UpdateWriterFixture(fields: fields("pending"))
        let committedFields = fields("committed")
        caller.insert(pending)

        let _: BASAppleCurrentBrainUpdateWriteResult<UpdateWriterFixture> =
            try BASAppleCurrentBrainUpdateWriter.persist(committedFields, in: caller)

        let independent = ModelContext(container)
        let stored = try independent.fetch(FetchDescriptor<UpdateWriterFixture>())
        #expect(stored.map(\.id) == [committedFields.id])
        #expect(caller.insertedModelsArray.contains { $0 === pending })
    }

    @Test("writer inserts updates and trims to the retention cap")
    func writerInsertsUpdatesAndTrimsToCap() throws {
        let container = try ModelContainer(
            for: UpdateWriterFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let baseDate = Date(timeIntervalSince1970: 1_744_000_000)

        for index in 0..<5 {
            let fields = BASCurrentBrainUpdateStoredFields(
                id: UUID(),
                createdAt: baseDate.addingTimeInterval(Double(index) * 86_401),
                source: "launch",
                mode: "primary",
                dominantGoal: "goal-\(index)",
                dominantReactionWeight: "brief_language",
                fingerprint: "fingerprint-\(index)",
                activeConstraints: [],
                activeTemplateIDs: [],
                failureGuardIDs: []
            )
            _ = try BASAppleCurrentBrainUpdateWriter.persist(
                fields,
                in: context,
                maxEntries: 3,
                retentionInterval: BASCurrentBrainPersistenceApplier.defaultRetentionInterval
            ) as BASAppleCurrentBrainUpdateWriteResult<UpdateWriterFixture>
        }

        let updates = try context.fetch(FetchDescriptor<UpdateWriterFixture>())
        let ordered = updates.map(\.basSnapshot)
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.createdAt > rhs.createdAt
            }

        #expect(updates.count == 3)
        #expect(ordered.map(\.dominantGoal) == ["goal-4", "goal-3", "goal-2"])
    }

    @Test("writer keeps fresh updates when they exceed the count target")
    func writerKeepsFreshUpdatesOverCountTarget() throws {
        let container = try ModelContainer(
            for: UpdateWriterFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let baseDate = Date(timeIntervalSince1970: 1_744_000_000)

        for index in 0..<5 {
            let fields = BASCurrentBrainUpdateStoredFields(
                id: UUID(),
                createdAt: baseDate.addingTimeInterval(Double(index) * 60),
                source: "launch",
                mode: "primary",
                dominantGoal: "fresh-goal-\(index)",
                dominantReactionWeight: "brief_language",
                fingerprint: "fresh-fingerprint-\(index)",
                activeConstraints: [],
                activeTemplateIDs: [],
                failureGuardIDs: []
            )
            _ = try BASAppleCurrentBrainUpdateWriter.persist(
                fields,
                in: context,
                maxEntries: 3,
                retentionInterval: 60 * 60
            ) as BASAppleCurrentBrainUpdateWriteResult<UpdateWriterFixture>
        }

        let updates = try context.fetch(FetchDescriptor<UpdateWriterFixture>())
        #expect(updates.count == 5)
        #expect(Set(updates.compactMap(\.dominantGoal)) == Set((0..<5).map { "fresh-goal-\($0)" }))
    }

    @Test("writer persists sixty-one fresh updates across a disk reopen")
    func writerPersistsSixtyOneFreshUpdatesAcrossDiskReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-update-writer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record("Failed to remove update-writer fixture directory: \(error)")
            }
        }

        let storeURL = directory.appendingPathComponent("updates.store")
        let schema = Schema([UpdateWriterFixture.self])
        let now = Date(timeIntervalSince1970: 1_744_000_000)
        let staleID = UUID(uuidString: "00000000-0000-0000-0000-000000999999")!
        let expectedFreshIDs = Set((1...61).map { index in
            UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
        })

        do {
            let configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            for index in 1...60 {
                let fields = BASCurrentBrainUpdateStoredFields(
                    id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!,
                    createdAt: now.addingTimeInterval(-Double(index) * 60),
                    source: "seed",
                    mode: "primary",
                    dominantGoal: "goal-\(index)",
                    dominantReactionWeight: "brief_language",
                    fingerprint: "fingerprint-\(index)",
                    activeConstraints: ["constraint-\(index)"],
                    activeTemplateIDs: [],
                    failureGuardIDs: []
                )
                context.insert(UpdateWriterFixture(fields: fields))
            }
            context.insert(UpdateWriterFixture(fields: BASCurrentBrainUpdateStoredFields(
                id: staleID,
                createdAt: now.addingTimeInterval(
                    -BASCurrentBrainPersistenceApplier.defaultRetentionInterval - 1
                ),
                source: "expired",
                mode: "primary",
                dominantGoal: "expired",
                dominantReactionWeight: "brief_language",
                fingerprint: "expired",
                activeConstraints: [],
                activeTemplateIDs: [],
                failureGuardIDs: []
            )))
            try context.save()

            let newestFields = BASCurrentBrainUpdateStoredFields(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000061")!,
                createdAt: now,
                source: "task-7-disk",
                mode: "reflective",
                dominantGoal: "persist all fresh updates",
                dominantReactionWeight: "warm_direct_tone",
                fingerprint: "fingerprint-61",
                activeConstraints: ["minimum-recovery-age"],
                activeTemplateIDs: ["template-61"],
                failureGuardIDs: ["guard-61"]
            )
            let result: BASAppleCurrentBrainUpdateWriteResult<UpdateWriterFixture> =
                try BASAppleCurrentBrainUpdateWriter.persist(
                    newestFields,
                    in: context
                )

            #expect(result.orderedUpdates.count == 61)
            #expect(Set(result.orderedUpdates.map(\.id)) == expectedFreshIDs)
            #expect(!result.orderedUpdates.contains { $0.id == staleID })
        }

        let reopenedConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let reopenedContainer = try ModelContainer(
            for: schema,
            configurations: [reopenedConfiguration]
        )
        let reopenedContext = ModelContext(reopenedContainer)
        let reopened = try reopenedContext.fetch(FetchDescriptor<UpdateWriterFixture>())
        let newest = try #require(reopened.first { $0.id.uuidString.hasSuffix("000000000061") })

        #expect(reopened.count == 61)
        #expect(Set(reopened.map(\.id)) == expectedFreshIDs)
        #expect(!reopened.contains { $0.id == staleID })
        #expect(newest.source == "task-7-disk")
        #expect(newest.mode == "reflective")
        #expect(newest.dominantGoal == "persist all fresh updates")
        #expect(newest.fingerprint == "fingerprint-61")
        #expect(newest.activeConstraints == ["minimum-recovery-age"])
        #expect(newest.activeTemplateIDs == ["template-61"])
        #expect(newest.failureGuardIDs == ["guard-61"])
    }

    @Test("writer propagates authoritative read failure without saving")
    func writerPropagatesReadFailureWithoutSaving() throws {
        let container = try ModelContainer(
            for: UpdateWriterFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let caller = ModelContext(container)
        let io = ApplePersistenceFaultIO()
        io.failFetch = { _ in true }

        #expect(throws: ApplePersistenceFixtureFault.fetch) {
            let _: BASAppleCurrentBrainUpdateWriteResult<UpdateWriterFixture> =
                try BASAppleCurrentBrainUpdateWriter.persist(
                    updateFields("read-failure"),
                    in: caller,
                    using: io
                )
        }

        #expect(io.saveCallCount == 0)
        #expect(io.contexts.count == 1)
        #expect(io.contexts.first !== caller)
        let independent = ModelContext(container)
        #expect(try independent.fetch(FetchDescriptor<UpdateWriterFixture>()).isEmpty)
    }

    @Test("writer save failure rolls back only its private context")
    func writerSaveFailureLeavesCallerPendingChangesUntouched() throws {
        let container = try ModelContainer(
            for: UpdateWriterFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let seed = ModelContext(container)
        let changed = UpdateWriterFixture(fields: updateFields("stored-change"))
        let deleted = UpdateWriterFixture(fields: updateFields("stored-delete"))
        seed.insert(changed)
        seed.insert(deleted)
        try seed.save()

        let caller = ModelContext(container)
        caller.autosaveEnabled = false
        let callerRows = try caller.fetch(FetchDescriptor<UpdateWriterFixture>())
        let pendingChange = try #require(callerRows.first { $0.id == changed.id })
        let pendingDelete = try #require(callerRows.first { $0.id == deleted.id })
        pendingChange.source = "caller-only-change"
        caller.delete(pendingDelete)
        let pendingInsert = UpdateWriterFixture(fields: updateFields("caller-only-insert"))
        caller.insert(pendingInsert)

        let io = ApplePersistenceFaultIO()
        io.failSave = true
        #expect(throws: ApplePersistenceFixtureFault.save) {
            let _: BASAppleCurrentBrainUpdateWriteResult<UpdateWriterFixture> =
                try BASAppleCurrentBrainUpdateWriter.persist(
                    updateFields("private-write"),
                    in: caller,
                    using: io
                )
        }

        #expect(io.saveCallCount == 1)
        #expect(caller.insertedModelsArray.contains { $0 === pendingInsert })
        #expect(caller.changedModelsArray.contains { $0 === pendingChange })
        #expect(caller.deletedModelsArray.contains { $0 === pendingDelete })
        let independent = ModelContext(container)
        let stored = try independent.fetch(FetchDescriptor<UpdateWriterFixture>())
        #expect(stored.count == 2)
        #expect(stored.first { $0.id == changed.id }?.source == "stored-change")
        #expect(stored.contains { $0.id == deleted.id })
    }

    @Test("writer success leaves caller pending update and delete untouched")
    func writerSuccessLeavesCallerPendingUpdateAndDeleteUntouched() throws {
        let container = try ModelContainer(
            for: UpdateWriterFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let seed = ModelContext(container)
        let changed = UpdateWriterFixture(fields: updateFields("stored-success-change"))
        let deleted = UpdateWriterFixture(fields: updateFields("stored-success-delete"))
        seed.insert(changed)
        seed.insert(deleted)
        try seed.save()

        let caller = ModelContext(container)
        caller.autosaveEnabled = false
        let callerRows = try caller.fetch(FetchDescriptor<UpdateWriterFixture>())
        let pendingChange = try #require(callerRows.first { $0.id == changed.id })
        let pendingDelete = try #require(callerRows.first { $0.id == deleted.id })
        pendingChange.source = "caller-only-success-change"
        caller.delete(pendingDelete)

        let _: BASAppleCurrentBrainUpdateWriteResult<UpdateWriterFixture> =
            try BASAppleCurrentBrainUpdateWriter.persist(
                updateFields("private-success-write"),
                in: caller
            )

        #expect(caller.changedModelsArray.contains { $0 === pendingChange })
        #expect(caller.deletedModelsArray.contains { $0 === pendingDelete })
        let independent = ModelContext(container)
        let stored = try independent.fetch(FetchDescriptor<UpdateWriterFixture>())
        #expect(stored.count == 3)
        #expect(stored.first { $0.id == changed.id }?.source == "stored-success-change")
        #expect(stored.contains { $0.id == deleted.id })
    }

    @Test("writer receipt remains immutable after same-ID replacement")
    func writerReceiptRemainsImmutableAfterReplacement() throws {
        let container = try ModelContainer(
            for: UpdateWriterFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let caller = ModelContext(container)
        let id = UUID()
        var original = updateFields("original")
        original.id = id
        var replacement = updateFields("replacement")
        replacement.id = id

        let first: BASAppleCurrentBrainUpdateWriteResult<UpdateWriterFixture> =
            try BASAppleCurrentBrainUpdateWriter.persist(original, in: caller)
        let second: BASAppleCurrentBrainUpdateWriteResult<UpdateWriterFixture> =
            try BASAppleCurrentBrainUpdateWriter.persist(replacement, in: caller)

        #expect(first.orderedUpdates.first?.source == "original")
        #expect(second.orderedUpdates.first?.source == "replacement")
    }

    @Test("read-only SwiftData store returns a catchable save error")
    func readOnlyStoreReturnsCatchableSaveError() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-update-read-only-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record("Failed to remove read-only writer fixture directory: \(error)")
            }
        }

        let storeURL = directory.appendingPathComponent("updates.store")
        let schema = Schema([UpdateWriterFixture.self])
        let seedFields = updateFields("seed")
        do {
            let writable = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [writable])
            let context = ModelContext(container)
            context.insert(UpdateWriterFixture(fields: seedFields))
            try context.save()
        }

        var caughtError: Error?
        do {
            let readOnly = ModelConfiguration(
                schema: schema,
                url: storeURL,
                allowsSave: false,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [readOnly])
            let caller = ModelContext(container)
            do {
                let _: BASAppleCurrentBrainUpdateWriteResult<UpdateWriterFixture> =
                    try BASAppleCurrentBrainUpdateWriter.persist(
                        updateFields("must-not-persist"),
                        in: caller
                    )
            } catch {
                caughtError = error
            }
        }

        #expect(caughtError != nil)
        let writable = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let reopened = try ModelContainer(for: schema, configurations: [writable])
        let stored = try ModelContext(reopened).fetch(FetchDescriptor<UpdateWriterFixture>())
        #expect(stored.map(\.id) == [seedFields.id])
    }

    private func updateFields(_ label: String) -> BASCurrentBrainUpdateStoredFields {
        BASCurrentBrainUpdateStoredFields(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_744_000_000),
            source: label,
            mode: "primary",
            dominantGoal: label,
            dominantReactionWeight: "brief_language",
            fingerprint: label,
            activeConstraints: [],
            activeTemplateIDs: [],
            failureGuardIDs: []
        )
    }
}

import Foundation
import SwiftData
import Testing
@testable import BASAppleAdapters
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
            _ = BASAppleCurrentBrainUpdateWriter.persist(
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
            _ = BASAppleCurrentBrainUpdateWriter.persist(
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
            var saveError: Error?
            let result: BASAppleCurrentBrainUpdateWriteResult<UpdateWriterFixture> =
                BASAppleCurrentBrainUpdateWriter.persist(
                    newestFields,
                    in: context,
                    onSaveError: { saveError = $0 }
                )

            if let saveError {
                Issue.record("Update writer save failed: \(saveError)")
            }
            #expect(result.orderedUpdates.count == 61)
            #expect(Set(result.orderedUpdates.map { $0.basSnapshot.id }) == expectedFreshIDs)
            #expect(!result.orderedUpdates.contains { $0.basSnapshot.id == staleID })
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
}

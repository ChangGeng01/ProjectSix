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
                createdAt: baseDate.addingTimeInterval(Double(index) * 60),
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
                retentionInterval: 60 * 60
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
}

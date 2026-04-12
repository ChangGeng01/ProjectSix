import Foundation
import SwiftData
import Testing
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASPolicy

@Suite("BASApple Evolution Checkpoint Writer")
struct BASAppleEvolutionCheckpointWriterTests {
    @Model
    final class CheckpointFixture: BASAppleEvolutionCheckpointEntity {
        @Attribute(.unique) var id: String
        var createdAt: Date
        var fingerprint: String
        var previousCheckpointID: String?
        var modeName: String
        var sourceID: String
        var identityRoleRaw: String
        var boundaryModeRaw: String
        var calibrationStatusRaw: String
        var diffSummary: [String]
        var approvalStateRaw: String
        var rollbackReady: Bool

        init(fields: BASEvolutionCheckpointStoredFields) {
            self.id = fields.id
            self.createdAt = fields.createdAt
            self.fingerprint = fields.fingerprint
            self.previousCheckpointID = fields.previousCheckpointID
            self.modeName = fields.modeName
            self.sourceID = fields.sourceID
            self.identityRoleRaw = fields.identityRole.rawValue
            self.boundaryModeRaw = fields.boundaryMode.rawValue
            self.calibrationStatusRaw = fields.calibrationStatus.rawValue
            self.diffSummary = fields.diffSummary
            self.approvalStateRaw = fields.approvalState.rawValue
            self.rollbackReady = fields.rollbackReady
        }

        static func basMake(from fields: BASEvolutionCheckpointStoredFields) -> CheckpointFixture {
            CheckpointFixture(fields: fields)
        }

        var basSnapshot: BASEvolutionCheckpointStoredFields {
            BASEvolutionCheckpointStoredFields(
                id: id,
                createdAt: createdAt,
                fingerprint: fingerprint,
                previousCheckpointID: previousCheckpointID,
                modeName: modeName,
                sourceID: sourceID,
                identityRole: BASIdentityRole(rawValue: identityRoleRaw) ?? .pauseCompanion,
                boundaryMode: BASBoundaryPolicyMode(rawValue: boundaryModeRaw) ?? .localOnlyAdvisory,
                calibrationStatus: BASCalibrationStatus(rawValue: calibrationStatusRaw) ?? .stable,
                diffSummary: diffSummary,
                approvalState: BASEvolutionApprovalState(rawValue: approvalStateRaw) ?? .automatic,
                rollbackReady: rollbackReady
            )
        }
    }

    @Test("writer deduplicates identical checkpoints and trims old ones")
    func writerDeduplicatesAndTrims() throws {
        let container = try ModelContainer(
            for: CheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let baseDate = Date(timeIntervalSince1970: 1_744_100_000)
        let stableInput = BASEvolutionCheckpointInput(
            modeName: "primary",
            sourceID: "launch",
            fingerprint: "fingerprint-a",
            identityRole: .pauseCompanion,
            boundaryMode: .localOnlyAdvisory,
            calibrationStatus: .stable
        )

        let first: BASAppleEvolutionCheckpointWriteResult<CheckpointFixture> =
            BASAppleEvolutionCheckpointWriter.record(
                input: stableInput,
                in: context,
                createdAt: baseDate,
                maxEntries: 2,
                retentionInterval: 60 * 60
            )
        let deduplicated: BASAppleEvolutionCheckpointWriteResult<CheckpointFixture> =
            BASAppleEvolutionCheckpointWriter.record(
                input: stableInput,
                in: context,
                createdAt: baseDate.addingTimeInterval(60),
                maxEntries: 2,
                retentionInterval: 60 * 60
            )
        let drifting: BASAppleEvolutionCheckpointWriteResult<CheckpointFixture> =
            BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointInput(
                    modeName: "reflective",
                    sourceID: "scene_active",
                    fingerprint: "fingerprint-b",
                    identityRole: .reflectiveWitness,
                    boundaryMode: .localOnlyProtective,
                    calibrationStatus: .drifting
                ),
                in: context,
                createdAt: baseDate.addingTimeInterval(120),
                maxEntries: 2,
                retentionInterval: 60 * 60
            )
        let later: BASAppleEvolutionCheckpointWriteResult<CheckpointFixture> =
            BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointInput(
                    modeName: "primary",
                    sourceID: "session_prime",
                    fingerprint: "fingerprint-c",
                    identityRole: .pauseCompanion,
                    boundaryMode: .localOnlyAdvisory,
                    calibrationStatus: .stable
                ),
                in: context,
                createdAt: baseDate.addingTimeInterval(180),
                maxEntries: 2,
                retentionInterval: 60 * 60
            )

        let checkpoints = try context.fetch(FetchDescriptor<CheckpointFixture>())

        #expect(first.wroteCheckpoint)
        #expect(!deduplicated.wroteCheckpoint)
        #expect(drifting.currentState.pendingReviewCount == 1)
        #expect(later.currentState.checkpointCount == 2)
        #expect(checkpoints.count == 2)
        #expect(checkpoints.contains(where: { $0.fingerprint == "fingerprint-c" }))
        #expect(!checkpoints.contains(where: { $0.fingerprint == "fingerprint-a" }))
    }
}

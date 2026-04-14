import Foundation
import SwiftData
import Testing
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASPolicy

@Suite("BASApple Evolution Checkpoint Writer")
struct BASAppleEvolutionCheckpointWriterTests {
    @Model
    final class EvolutionCheckpointFixture: BASAppleEvolutionCheckpointEntity {
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
        var brainStateSnapshotBlob: String?
        var lineageSummaryBlob: String?

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
            self.brainStateSnapshotBlob = Self.encode(fields.brainStateSnapshot)
            self.lineageSummaryBlob = Self.encode(fields.lineageSummary)
        }

        static func basMake(from fields: BASEvolutionCheckpointStoredFields) -> EvolutionCheckpointFixture {
            EvolutionCheckpointFixture(fields: fields)
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
                rollbackReady: rollbackReady,
                brainStateSnapshot: Self.decode(brainStateSnapshotBlob, as: BASDecisionBrainState.self),
                lineageSummary: Self.decode(lineageSummaryBlob)
            )
        }

        private static func encode<Value: Encodable>(_ value: Value?) -> String? {
            guard let value,
                  let data = try? JSONEncoder().encode(value) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        }

        private static func decode<Value: Decodable>(_ blob: String?, as type: Value.Type = Value.self) -> Value? {
            guard let blob,
                  let data = blob.data(using: .utf8) else {
                return nil
            }
            return try? JSONDecoder().decode(Value.self, from: data)
        }
    }

    @Test("writer deduplicates identical checkpoints and trims old ones")
    func writerDeduplicatesAndTrims() throws {
        let container = try ModelContainer(
            for: EvolutionCheckpointFixture.self,
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

        let first: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            BASAppleEvolutionCheckpointWriter.record(
                input: stableInput,
                in: context,
                createdAt: baseDate,
                maxEntries: 2,
                retentionInterval: 60 * 60
            )
        let deduplicated: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            BASAppleEvolutionCheckpointWriter.record(
                input: stableInput,
                in: context,
                createdAt: baseDate.addingTimeInterval(60),
                maxEntries: 2,
                retentionInterval: 60 * 60
            )
        let drifting: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
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
        let later: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
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

        let checkpoints = try context.fetch(FetchDescriptor<EvolutionCheckpointFixture>())

        #expect(first.wroteCheckpoint)
        #expect(!deduplicated.wroteCheckpoint)
        #expect(drifting.currentState.pendingReviewCount == 1)
        #expect(later.currentState.checkpointCount == 2)
        #expect(checkpoints.count == 2)
        #expect(checkpoints.contains(where: { $0.fingerprint == "fingerprint-c" }))
        #expect(!checkpoints.contains(where: { $0.fingerprint == "fingerprint-a" }))
    }

    @Test("writer updates checkpoint approval state without adding a checkpoint")
    func writerUpdatesApprovalState() throws {
        let container = try ModelContainer(
            for: EvolutionCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let baseDate = Date(timeIntervalSince1970: 1_744_100_000)

        let initial: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointInput(
                    modeName: "reflective",
                    sourceID: "scene_active",
                    fingerprint: "fingerprint-review",
                    identityRole: .reflectiveWitness,
                    boundaryMode: .localOnlyProtective,
                    calibrationStatus: .drifting
                ),
                in: context,
                createdAt: baseDate
            )

        let updated: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            BASAppleEvolutionCheckpointWriter.setApprovalState(
                .automatic,
                for: initial.currentState.latestCheckpoint?.id ?? "",
                in: context
            )

        let checkpoints = try context.fetch(FetchDescriptor<EvolutionCheckpointFixture>())

        #expect(checkpoints.count == 1)
        #expect(checkpoints.first?.basSnapshot.approvalState == .automatic)
        #expect(updated.currentState.pendingReviewCount == 0)
        #expect(updated.currentState.latestCheckpoint?.approvalState == .automatic)
    }

    @Test("writer can set and clear lineage summary for an existing checkpoint")
    func writerSetsAndClearsLineageSummary() throws {
        let container = try ModelContainer(
            for: EvolutionCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let baseDate = Date(timeIntervalSince1970: 1_744_100_000)

        let initial: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointInput(
                    modeName: "primary",
                    sourceID: "launch",
                    fingerprint: "fingerprint-lineage",
                    identityRole: .pauseCompanion,
                    boundaryMode: .localOnlyAdvisory,
                    calibrationStatus: .stable
                ),
                in: context,
                createdAt: baseDate
            )
        let checkpointID = try #require(initial.currentState.latestCheckpoint?.id)
        let lineage = BASEvolutionLineageSummary(
            recordedAt: baseDate,
            sessionID: "fixture.lineage",
            taskType: "decision",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 74,
            thoughtFoldChecksum: "fixture-fold",
            updateTicketSummaries: ["wait for evidence"],
            activeKillSwitches: ["force_guard_mode"],
            guardrailFindings: ["downgraded quick path"],
            recommendedKillSwitches: ["disableHighRiskAutoAction"]
        )

        let attached: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            BASAppleEvolutionCheckpointWriter.setLineageSummary(
                lineage,
                for: checkpointID,
                in: context
            )
        let cleared: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            BASAppleEvolutionCheckpointWriter.setLineageSummary(
                nil,
                for: checkpointID,
                in: context
            )

        let checkpoints = try context.fetch(FetchDescriptor<EvolutionCheckpointFixture>())

        #expect(checkpoints.count == 1)
        #expect(attached.currentState.latestCheckpoint?.lineageSummary == lineage)
        #expect(cleared.currentState.latestCheckpoint?.lineageSummary == nil)
        #expect(checkpoints.first?.basSnapshot.lineageSummary == nil)
    }

    @Test("writer can attach lineage summary to an explicit checkpoint without touching the newest checkpoint")
    func writerAttachesLineageSummaryToExplicitCheckpoint() throws {
        let container = try ModelContainer(
            for: EvolutionCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let baseDate = Date(timeIntervalSince1970: 1_744_100_000)

        let older: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointInput(
                    modeName: "primary",
                    sourceID: "launch",
                    fingerprint: "fingerprint-older",
                    identityRole: .pauseCompanion,
                    boundaryMode: .localOnlyAdvisory,
                    calibrationStatus: .stable,
                    brainStateSnapshot: BASDecisionBrainState(
                        profileCore: ["Older checkpoint."],
                        activeGoals: ["Keep older active."],
                        relevantMemories: [],
                        sessionBiases: [],
                        retrievalTags: ["older"],
                        reactionWeights: .defaults(for: "primary"),
                        boundaryPolicy: .default(riskLevel: .low),
                        loadedAt: baseDate
                    )
                ),
                in: context,
                createdAt: baseDate
            )
        let newer: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointInput(
                    modeName: "primary",
                    sourceID: "scene_active",
                    fingerprint: "fingerprint-newer",
                    identityRole: .pauseCompanion,
                    boundaryMode: .localOnlyAdvisory,
                    calibrationStatus: .stable
                ),
                in: context,
                createdAt: baseDate.addingTimeInterval(60)
            )

        let olderID = try #require(
            older.orderedCheckpoints.first(where: { $0.fingerprint == "fingerprint-older" })?.id
        )
        let newerID = try #require(
            newer.orderedCheckpoints.first(where: { $0.fingerprint == "fingerprint-newer" })?.id
        )

        let lineage = BASEvolutionLineageSummary(
            recordedAt: baseDate.addingTimeInterval(120),
            sessionID: "fixture.explicit-target",
            taskType: "decision",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 81,
            thoughtFoldChecksum: "explicit-target-fold",
            updateTicketSummaries: ["preserve explicit target"],
            activeKillSwitches: ["force_guard_mode"],
            guardrailFindings: ["attached to older checkpoint"],
            recommendedKillSwitches: ["disableHighRiskAutoAction"]
        )

        let attached: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            BASAppleEvolutionCheckpointWriter.attachLineageSummary(
                lineage,
                for: olderID,
                in: context
            )

        let checkpoints = try context.fetch(FetchDescriptor<EvolutionCheckpointFixture>())
        let olderCheckpoint = try #require(checkpoints.first(where: { $0.id == olderID }))
        let newerCheckpoint = try #require(checkpoints.first(where: { $0.id == newerID }))

        #expect(olderCheckpoint.basSnapshot.lineageSummary == lineage)
        #expect(newerCheckpoint.basSnapshot.lineageSummary == nil)
        #expect(attached.currentState.latestCheckpoint?.id == newerID)
    }

    @Test("checkpoint input carries a restorable brain snapshot")
    func writerPersistsBrainSnapshot() throws {
        let container = try ModelContainer(
            for: EvolutionCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let baseDate = Date(timeIntervalSince1970: 1_744_100_000)
        let brainState = BASDecisionBrainState(
            profileCore: ["Protect sleep."],
            activeGoals: ["Delay the send."],
            relevantMemories: ["High-risk conflicts need pacing."],
            sessionBiases: ["Stay local."],
            retrievalTags: ["mirror", "high-risk"],
            reactionWeights: .defaults(for: BASDecisionMode.reflective.identifier),
            boundaryPolicy: .default(riskLevel: .high),
            loadedAt: baseDate
        )

        let result: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointPlanner.checkpointInput(
                    modeName: "reflective",
                    sourceID: "scene_active",
                    brainState: brainState
                ),
                in: context,
                createdAt: baseDate
            )

        let checkpoint = try #require(result.orderedCheckpoints.first)
        #expect(checkpoint.basSnapshot.brainStateSnapshot == brainState)
        #expect(checkpoint.basSnapshot.brainStateSnapshot?.boundaryPolicy.riskLevel == .high)
    }
}

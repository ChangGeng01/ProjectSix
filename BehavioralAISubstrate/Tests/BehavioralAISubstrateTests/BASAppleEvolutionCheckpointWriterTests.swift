import Foundation
import SwiftData
import Testing
@testable import BASAppleAdapters
@testable import BASAppleLifecycleKit
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
            try BASAppleEvolutionCheckpointWriter.record(
                input: stableInput,
                in: context,
                createdAt: baseDate,
                maxEntries: 2,
                retentionInterval: 60 * 60
            )
        let deduplicated: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            try BASAppleEvolutionCheckpointWriter.record(
                input: stableInput,
                in: context,
                createdAt: baseDate.addingTimeInterval(60),
                maxEntries: 2,
                retentionInterval: 60 * 60
            )
        let drifting: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            try BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointInput(
                    modeName: "reflective",
                    sourceID: "scene_active",
                    fingerprint: "fingerprint-b",
                    identityRole: .reflectiveWitness,
                    boundaryMode: .localOnlyProtective,
                    calibrationStatus: .drifting
                ),
                in: context,
                createdAt: baseDate.addingTimeInterval(4 * 86_400),
                maxEntries: 2,
                retentionInterval: BASEvolutionCheckpointPlanner.defaultRetentionInterval
            )
        let later: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            try BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointInput(
                    modeName: "primary",
                    sourceID: "session_prime",
                    fingerprint: "fingerprint-c",
                    identityRole: .pauseCompanion,
                    boundaryMode: .localOnlyAdvisory,
                    calibrationStatus: .stable
                ),
                in: context,
                createdAt: baseDate.addingTimeInterval(8 * 86_400),
                maxEntries: 2,
                retentionInterval: BASEvolutionCheckpointPlanner.defaultRetentionInterval
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

    @Test("writer keeps distinct fresh checkpoints when they exceed the count target")
    func writerKeepsDistinctFreshCheckpointsOverCountTarget() throws {
        let container = try ModelContainer(
            for: EvolutionCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let baseDate = Date(timeIntervalSince1970: 1_744_100_000)

        for index in 0..<3 {
            let result: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
                try BASAppleEvolutionCheckpointWriter.record(
                    input: BASEvolutionCheckpointInput(
                        modeName: "primary",
                        sourceID: "fresh-\(index)",
                        fingerprint: "fresh-fingerprint-\(index)",
                        identityRole: .pauseCompanion,
                        boundaryMode: .localOnlyAdvisory,
                        calibrationStatus: .stable
                    ),
                    in: context,
                    createdAt: baseDate.addingTimeInterval(Double(index) * 60),
                    maxEntries: 2,
                    retentionInterval: 60 * 60
                )
            #expect(result.wroteCheckpoint)
        }

        let checkpoints = try context.fetch(FetchDescriptor<EvolutionCheckpointFixture>())
        #expect(checkpoints.count == 3)
        #expect(Set(checkpoints.map(\.fingerprint)) == Set((0..<3).map { "fresh-fingerprint-\($0)" }))
    }

    @Test("writer persists forty-one fresh checkpoints across a disk reopen")
    func writerPersistsFortyOneFreshCheckpointsAcrossDiskReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-checkpoint-writer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record("Failed to remove checkpoint-writer fixture directory: \(error)")
            }
        }

        let storeURL = directory.appendingPathComponent("checkpoints.store")
        let schema = Schema([EvolutionCheckpointFixture.self])
        let now = Date(timeIntervalSince1970: 1_744_100_000)
        let staleID = "checkpoint-expired"
        let seededFreshIDs = Set((1...40).map { String(format: "checkpoint-%02d", $0) })
        var expectedFreshIDs = seededFreshIDs
        var newCheckpointID: String?

        do {
            let configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            for index in 1...40 {
                context.insert(EvolutionCheckpointFixture(fields: BASEvolutionCheckpointStoredFields(
                    id: String(format: "checkpoint-%02d", index),
                    createdAt: now.addingTimeInterval(-Double(index) * 60),
                    fingerprint: "fingerprint-\(index)",
                    previousCheckpointID: index == 40
                        ? nil
                        : String(format: "checkpoint-%02d", index + 1),
                    modeName: "primary",
                    sourceID: "seed-\(index)",
                    identityRole: .pauseCompanion,
                    boundaryMode: .localOnlyAdvisory,
                    calibrationStatus: .stable,
                    diffSummary: ["seed-\(index)"],
                    approvalState: .automatic,
                    rollbackReady: true
                )))
            }
            context.insert(EvolutionCheckpointFixture(fields: BASEvolutionCheckpointStoredFields(
                id: staleID,
                createdAt: now.addingTimeInterval(
                    -BASEvolutionCheckpointPlanner.defaultRetentionInterval - 1
                ),
                fingerprint: "expired",
                previousCheckpointID: nil,
                modeName: "primary",
                sourceID: "expired",
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                calibrationStatus: .stable,
                diffSummary: ["expired"],
                approvalState: .automatic,
                rollbackReady: true
            )))
            try context.save()

            let result: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
                try BASAppleEvolutionCheckpointWriter.record(
                    input: BASEvolutionCheckpointInput(
                        modeName: "reflective",
                        sourceID: "task-7-disk",
                        fingerprint: "fingerprint-41",
                        identityRole: .reflectiveWitness,
                        boundaryMode: .localOnlyProtective,
                        calibrationStatus: .drifting
                    ),
                    in: context,
                    createdAt: now
                )

            #expect(result.wroteCheckpoint)
            #expect(result.orderedCheckpoints.count == 41)
            let written = try #require(result.orderedCheckpoints.first)
            newCheckpointID = written.id
            expectedFreshIDs.insert(written.id)
            #expect(written.fingerprint == "fingerprint-41")
            #expect(written.previousCheckpointID == "checkpoint-01")
            #expect(Set(result.orderedCheckpoints.map(\.id)) == expectedFreshIDs)
            #expect(!result.orderedCheckpoints.contains { $0.id == staleID })
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
        let reopened = try reopenedContext.fetch(FetchDescriptor<EvolutionCheckpointFixture>())
        let requiredNewCheckpointID = try #require(newCheckpointID)
        let newest = try #require(reopened.first { $0.id == requiredNewCheckpointID })

        #expect(reopened.count == 41)
        #expect(Set(reopened.map(\.id)) == expectedFreshIDs)
        #expect(!reopened.contains { $0.id == staleID })
        #expect(newest.fingerprint == "fingerprint-41")
        #expect(newest.previousCheckpointID == "checkpoint-01")
        #expect(newest.modeName == "reflective")
        #expect(newest.sourceID == "task-7-disk")
        #expect(newest.identityRoleRaw == BASIdentityRole.reflectiveWitness.rawValue)
        #expect(newest.boundaryModeRaw == BASBoundaryPolicyMode.localOnlyProtective.rawValue)
        #expect(newest.calibrationStatusRaw == BASCalibrationStatus.drifting.rawValue)
        #expect(newest.rollbackReady)
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
            try BASAppleEvolutionCheckpointWriter.record(
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
            try BASAppleEvolutionCheckpointWriter.setApprovalState(
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
            try BASAppleEvolutionCheckpointWriter.record(
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
            try BASAppleEvolutionCheckpointWriter.setLineageSummary(
                lineage,
                for: checkpointID,
                in: context
            )
        let cleared: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            try BASAppleEvolutionCheckpointWriter.setLineageSummary(
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
            try BASAppleEvolutionCheckpointWriter.record(
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
            try BASAppleEvolutionCheckpointWriter.record(
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
            try BASAppleEvolutionCheckpointWriter.attachLineageSummary(
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

    @Test("writer revokes checkpoints when a forget gate targets dream-loop lineage refs")
    func writerRevokesCheckpointRecoveryEntriesForDreamLoopRefs() throws {
        let container = try ModelContainer(
            for: EvolutionCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let baseDate = Date(timeIntervalSince1970: 1_744_100_090)

        let targetedLineage = BASEvolutionLineageSummary(
            recordedAt: baseDate,
            sessionID: "session.dream-loop",
            taskType: "decision",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 86,
            thoughtFoldChecksum: "fold.dream-loop",
            updateTicketSummaries: ["dream loop checkpoint"],
            activeKillSwitches: ["force_guard_mode"],
            guardrailFindings: ["checkpoint carries dream-loop refs"],
            recommendedKillSwitches: ["disableHighRiskAutoAction"],
            governanceSummary: BASEvolutionLineageSummary.GovernanceSummary(
                experienceCandidateCount: 1,
                shadowTrialCount: 0,
                pendingShadowTrialCount: 0,
                sealCount: 0,
                pendingSealCount: 0,
                versionDeltaCount: 0,
                retractionOrderCount: 0,
                pendingRetractionCount: 0,
                dreamLoopStoppingMode: "sovereignCut",
                dreamLoopSignalRefs: ["dream_loop:sovereignCut", "dream_loop:breakpoint"],
                dreamLoopRemandTargets: ["L14"],
                dreamLoopReservationMode: "noAutoMerge",
                dreamLoopMaxEvidenceDebtPercent: 81
            )
        )

        let targeted: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            try BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointInput(
                    modeName: "reflective",
                    sourceID: "scene_active",
                    fingerprint: "fingerprint-dream-loop",
                    identityRole: .reflectiveWitness,
                    boundaryMode: .localOnlyProtective,
                    calibrationStatus: .stable,
                    lineageSummary: targetedLineage
                ),
                in: context,
                createdAt: baseDate
            )

        let stable: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            try BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointInput(
                    modeName: "primary",
                    sourceID: "launch",
                    fingerprint: "fingerprint-stable-dream-loop",
                    identityRole: .pauseCompanion,
                    boundaryMode: .localOnlyAdvisory,
                    calibrationStatus: .stable
                ),
                in: context,
                createdAt: baseDate.addingTimeInterval(60)
            )

        let forgetRequest = BASForgetRequest(
            requestID: "forget.dream-loop.refs",
            targetRefs: [
                "dream_loop_stop:sovereignCut",
                "dream_loop:breakpoint"
            ],
            cascadeScope: ["checkpoints", "projection_cache"],
            executedSteps: ["checkpoint_exports_revoked"],
            verified: false
        )

        let revoked: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            try BASAppleEvolutionCheckpointWriter.revokeCheckpoints(
                for: forgetRequest,
                in: context
            )

        let checkpoints = try context.fetch(FetchDescriptor<EvolutionCheckpointFixture>())
        let stableID = try #require(
            stable.orderedCheckpoints.first(where: { $0.fingerprint == "fingerprint-stable-dream-loop" })?.id
        )
        let targetedID = try #require(
            targeted.orderedCheckpoints.first(where: { $0.fingerprint == "fingerprint-dream-loop" })?.id
        )

        #expect(checkpoints.count == 1)
        #expect(checkpoints.first?.id == stableID)
        #expect(!checkpoints.contains(where: { $0.id == targetedID }))
        #expect(revoked.currentState.checkpointCount == 1)
        #expect(revoked.currentState.latestCheckpoint?.id == stableID)
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
            try BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointPlanner.checkpointInput(
                    modeName: "reflective",
                    sourceID: "scene_active",
                    brainState: brainState
                ),
                in: context,
                createdAt: baseDate
            )

        let checkpoint = try #require(result.orderedCheckpoints.first)
        #expect(checkpoint.brainStateSnapshot == brainState)
        #expect(checkpoint.brainStateSnapshot?.boundaryPolicy.riskLevel == .high)
    }

    @Test("writer revokes checkpoint recovery entries when a forget gate targets recovery anchors")
    func writerRevokesCheckpointRecoveryEntriesForForgetGate() throws {
        let container = try ModelContainer(
            for: EvolutionCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let baseDate = Date(timeIntervalSince1970: 1_744_100_000)

        let targetedLineage = BASEvolutionLineageSummary(
            recordedAt: baseDate,
            sessionID: "session.targeted",
            taskType: "decision",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 82,
            thoughtFoldChecksum: "fold.targeted",
            updateTicketSummaries: ["targeted checkpoint"],
            activeKillSwitches: ["force_guard_mode"],
            guardrailFindings: ["checkpoint carries revocable refs"],
            recommendedKillSwitches: ["disableHighRiskAutoAction"],
            foldedLungSummary: BASEvolutionFoldedLungSummary(
                breathMode: "guard",
                breathPhase: "exchange",
                thermalPressure: 54,
                cachePressure: 40,
                restoreReadinessPercent: 76,
                resumeID: "resume.guard",
                sourceFoldID: "fold.guard",
                resumeDepth: 2,
                fallbackMode: "rollbackAnchor",
                rollbackAnchorID: "anchor.guard",
                safeSnapshotRef: "snapshot.guard",
                foldRefs: ["fold.guard"],
                cacheStateRef: "cache.guard",
                integrityHash: "hash.guard"
            )
        )

        let targeted: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            try BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointInput(
                    modeName: "reflective",
                    sourceID: "scene_active",
                    fingerprint: "fingerprint-targeted",
                    identityRole: .reflectiveWitness,
                    boundaryMode: .localOnlyProtective,
                    calibrationStatus: .stable,
                    lineageSummary: targetedLineage
                ),
                in: context,
                createdAt: baseDate
            )

        let stable: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            try BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointInput(
                    modeName: "primary",
                    sourceID: "launch",
                    fingerprint: "fingerprint-stable",
                    identityRole: .pauseCompanion,
                    boundaryMode: .localOnlyAdvisory,
                    calibrationStatus: .stable
                ),
                in: context,
                createdAt: baseDate.addingTimeInterval(60)
            )

        let forgetRequest = BASForgetRequest(
            requestID: "forget.guard.anchor",
            targetRefs: ["anchor.guard", "resume.guard"],
            cascadeScope: ["checkpoints", "projection_cache"],
            executedSteps: ["checkpoint_exports_revoked"],
            verified: false
        )

        let revoked: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            try BASAppleEvolutionCheckpointWriter.revokeCheckpoints(
                for: forgetRequest,
                in: context
            )

        let checkpoints = try context.fetch(FetchDescriptor<EvolutionCheckpointFixture>())
        let stableID = try #require(
            stable.orderedCheckpoints.first(where: { $0.fingerprint == "fingerprint-stable" })?.id
        )
        let targetedID = try #require(
            targeted.orderedCheckpoints.first(where: { $0.fingerprint == "fingerprint-targeted" })?.id
        )

        #expect(checkpoints.count == 1)
        #expect(checkpoints.first?.id == stableID)
        #expect(!checkpoints.contains(where: { $0.id == targetedID }))
        #expect(revoked.currentState.checkpointCount == 1)
        #expect(revoked.currentState.latestCheckpoint?.id == stableID)
    }

    @Test("writer revokes checkpoints when a forget gate targets organ-delta folded-lung refs")
    func writerRevokesCheckpointRecoveryEntriesForOrganDeltaRefs() throws {
        let container = try ModelContainer(
            for: EvolutionCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let baseDate = Date(timeIntervalSince1970: 1_744_100_120)

        let targetedLineage = BASEvolutionLineageSummary(
            recordedAt: baseDate,
            sessionID: "session.organ-delta",
            taskType: "decision",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 88,
            thoughtFoldChecksum: "fold.organ-delta",
            updateTicketSummaries: ["organ delta refs"],
            activeKillSwitches: ["force_guard_mode"],
            guardrailFindings: ["checkpoint carries organ-delta refs"],
            recommendedKillSwitches: ["disableHighRiskAutoAction"],
            foldedLungSummary: BASEvolutionFoldedLungSummary(
                organDeltaPlanID: "organ-plan.guard",
                breathMode: "guard",
                breathPhase: "exchange",
                thermalPressure: 61,
                cachePressure: 43,
                restoreReadinessPercent: 72,
                resumeID: "resume.organ-delta",
                sourceFoldID: "fold.organ-delta",
                resumeDepth: 2,
                fallbackMode: "rollbackAnchor",
                rollbackAnchorID: "anchor.organ-delta",
                safeSnapshotRef: "snapshot.organ-delta",
                foldRefs: ["fold.organ-delta"],
                cacheStateRef: "cache.organ-delta",
                integrityHash: "hash.organ-delta",
                organPackageRecords: [
                    BASEvolutionFoldedLungSummary.OrganPackageRecord(
                        packageID: "package.guard.stub",
                        organID: "stubCore",
                        sizeMB: 12,
                        loadTimeMs: 18,
                        thermalCost: 4,
                        sovereignClass: "guard"
                    )
                ],
                organDeltaActivatePackageIDs: ["package.guard.stub"],
                organDeltaPreloadPackageIDs: ["package.guard.preload"],
                organDeltaEvictPackageIDs: ["package.guard.evict"],
                organDeltaRetainPackageIDs: ["package.guard.retain"],
                organDeltaRollbackSafePackageIDs: ["package.guard.rollback-safe"]
            )
        )

        let targeted: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            try BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointInput(
                    modeName: "reflective",
                    sourceID: "scene_active",
                    fingerprint: "fingerprint-organ-delta",
                    identityRole: .reflectiveWitness,
                    boundaryMode: .localOnlyProtective,
                    calibrationStatus: .stable,
                    lineageSummary: targetedLineage
                ),
                in: context,
                createdAt: baseDate
            )

        let stable: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            try BASAppleEvolutionCheckpointWriter.record(
                input: BASEvolutionCheckpointInput(
                    modeName: "primary",
                    sourceID: "launch",
                    fingerprint: "fingerprint-stable-organ-delta",
                    identityRole: .pauseCompanion,
                    boundaryMode: .localOnlyAdvisory,
                    calibrationStatus: .stable
                ),
                in: context,
                createdAt: baseDate.addingTimeInterval(60)
            )

        let forgetRequest = BASForgetRequest(
            requestID: "forget.organ-delta.refs",
            targetRefs: [
                "organ-plan.guard",
                "package.guard.preload",
                "package.guard.rollback-safe"
            ],
            cascadeScope: ["checkpoints", "projection_cache"],
            executedSteps: ["checkpoint_exports_revoked"],
            verified: false
        )

        let revoked: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            try BASAppleEvolutionCheckpointWriter.revokeCheckpoints(
                for: forgetRequest,
                in: context
            )

        let checkpoints = try context.fetch(FetchDescriptor<EvolutionCheckpointFixture>())
        let stableID = try #require(
            stable.orderedCheckpoints.first(where: { $0.fingerprint == "fingerprint-stable-organ-delta" })?.id
        )
        let targetedID = try #require(
            targeted.orderedCheckpoints.first(where: { $0.fingerprint == "fingerprint-organ-delta" })?.id
        )

        #expect(checkpoints.count == 1)
        #expect(checkpoints.first?.id == stableID)
        #expect(!checkpoints.contains(where: { $0.id == targetedID }))
        #expect(revoked.currentState.checkpointCount == 1)
        #expect(revoked.currentState.latestCheckpoint?.id == stableID)
    }

    @Test("checkpoint writer propagates read failure on a would-be no-target mutation")
    func writerPropagatesReadFailureBeforeNoTargetResult() throws {
        let container = try ModelContainer(
            for: EvolutionCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let caller = ModelContext(container)
        let io = ApplePersistenceFaultIO()
        io.failFetch = { _ in true }

        #expect(throws: ApplePersistenceFixtureFault.fetch) {
            let _: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
                try BASAppleEvolutionCheckpointWriter.setApprovalState(
                    .automatic,
                    for: "missing-checkpoint",
                    in: caller,
                    using: io
                )
        }

        #expect(io.saveCallCount == 0)
        #expect(io.contexts.count == 1)
        #expect(io.contexts.first !== caller)
    }

    @Test("checkpoint writer propagates read failure before a would-be deduplication")
    func writerPropagatesReadFailureBeforeDeduplication() throws {
        let container = try ModelContainer(
            for: EvolutionCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let input = checkpointInput("dedup-read-failure")
        let seed = ModelContext(container)
        seed.insert(EvolutionCheckpointFixture(fields:
            BASEvolutionCheckpointPlanner.checkpointFields(
                createdAt: Date(timeIntervalSince1970: 1_744_100_000),
                latest: nil,
                input: input
            )
        ))
        try seed.save()
        let caller = ModelContext(container)
        let io = ApplePersistenceFaultIO()
        io.failFetch = { _ in true }

        #expect(throws: ApplePersistenceFixtureFault.fetch) {
            let _: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
                try BASAppleEvolutionCheckpointWriter.record(
                    input: input,
                    in: caller,
                    using: io
                )
        }

        #expect(io.saveCallCount == 0)
        #expect(io.contexts.count == 1)
        #expect(io.contexts.first !== caller)
    }

    @Test("checkpoint deduplication does not save caller pending insert")
    func writerDeduplicationDoesNotSaveCallerPendingInsert() throws {
        let container = try ModelContainer(
            for: EvolutionCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let input = checkpointInput("dedup-no-save")
        let seed = ModelContext(container)
        seed.insert(EvolutionCheckpointFixture(fields:
            BASEvolutionCheckpointPlanner.checkpointFields(
                createdAt: Date(timeIntervalSince1970: 1_744_100_000),
                latest: nil,
                input: input
            )
        ))
        try seed.save()
        let caller = ModelContext(container)
        caller.autosaveEnabled = false
        let pending = EvolutionCheckpointFixture(fields: checkpointFields(
            id: "caller-pending",
            sourceID: "caller-pending"
        ))
        caller.insert(pending)
        let io = ApplePersistenceFaultIO()

        let result: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
            try BASAppleEvolutionCheckpointWriter.record(
                input: input,
                in: caller,
                using: io
            )

        #expect(!result.wroteCheckpoint)
        #expect(io.saveCallCount == 0)
        #expect(caller.insertedModelsArray.contains { $0 === pending })
        let independent = ModelContext(container)
        #expect(try independent.fetch(FetchDescriptor<EvolutionCheckpointFixture>()).count == 1)
    }

    @Test("checkpoint record save failure publishes no receipt or record")
    func writerPropagatesRecordSaveFailure() throws {
        let container = try ModelContainer(
            for: EvolutionCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let caller = ModelContext(container)
        let io = ApplePersistenceFaultIO()
        io.failSave = true

        #expect(throws: ApplePersistenceFixtureFault.save) {
            let _: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
                try BASAppleEvolutionCheckpointWriter.record(
                    input: checkpointInput("record-save-failure"),
                    in: caller,
                    using: io
                )
        }

        #expect(io.saveCallCount == 1)
        #expect(io.contexts.allSatisfy { $0 !== caller })
        let independent = ModelContext(container)
        #expect(try independent.fetch(FetchDescriptor<EvolutionCheckpointFixture>()).isEmpty)
    }

    @Test("checkpoint mutation save failure preserves committed state")
    func writerPropagatesMutationSaveFailure() throws {
        let container = try ModelContainer(
            for: EvolutionCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let seed = ModelContext(container)
        seed.insert(EvolutionCheckpointFixture(fields: checkpointFields(
            id: "checkpoint-mutation",
            sourceID: "mutation-source",
            approvalState: .reviewSuggested
        )))
        try seed.save()
        let caller = ModelContext(container)
        let io = ApplePersistenceFaultIO()
        io.failSave = true

        #expect(throws: ApplePersistenceFixtureFault.save) {
            let _: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
                try BASAppleEvolutionCheckpointWriter.setApprovalState(
                    .automatic,
                    for: "checkpoint-mutation",
                    in: caller,
                    using: io
                )
        }

        #expect(io.saveCallCount == 1)
        #expect(io.contexts.allSatisfy { $0 !== caller })
        let independent = ModelContext(container)
        let stored = try #require(
            try independent.fetch(FetchDescriptor<EvolutionCheckpointFixture>()).first
        )
        #expect(stored.basSnapshot.approvalState == .reviewSuggested)
    }

    @Test("checkpoint revocation save failure preserves committed chain")
    func writerPropagatesRevocationSaveFailure() throws {
        let container = try ModelContainer(
            for: EvolutionCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let seed = ModelContext(container)
        seed.insert(EvolutionCheckpointFixture(fields: checkpointFields(
            id: "checkpoint-revoke",
            sourceID: "revocation-target"
        )))
        try seed.save()
        let caller = ModelContext(container)
        let io = ApplePersistenceFaultIO()
        io.failSave = true
        let request = BASForgetRequest(
            requestID: "forget.revocation-target",
            targetRefs: ["revocation-target"],
            cascadeScope: ["checkpoints"],
            executedSteps: ["checkpoint_exports_revoked"],
            verified: false
        )

        #expect(throws: ApplePersistenceFixtureFault.save) {
            let _: BASAppleEvolutionCheckpointWriteResult<EvolutionCheckpointFixture> =
                try BASAppleEvolutionCheckpointWriter.revokeCheckpoints(
                    for: request,
                    in: caller,
                    using: io
                )
        }

        #expect(io.saveCallCount == 1)
        #expect(io.contexts.allSatisfy { $0 !== caller })
        let independent = ModelContext(container)
        let stored = try independent.fetch(FetchDescriptor<EvolutionCheckpointFixture>())
        #expect(stored.map(\.id) == ["checkpoint-revoke"])
    }

    private func checkpointInput(_ label: String) -> BASEvolutionCheckpointInput {
        BASEvolutionCheckpointInput(
            modeName: "primary",
            sourceID: label,
            fingerprint: label,
            identityRole: .pauseCompanion,
            boundaryMode: .localOnlyAdvisory,
            calibrationStatus: .stable
        )
    }

    private func checkpointFields(
        id: String,
        sourceID: String,
        approvalState: BASEvolutionApprovalState = .automatic
    ) -> BASEvolutionCheckpointStoredFields {
        BASEvolutionCheckpointStoredFields(
            id: id,
            createdAt: Date(timeIntervalSince1970: 1_744_100_000),
            fingerprint: "fingerprint-\(id)",
            previousCheckpointID: nil,
            modeName: "primary",
            sourceID: sourceID,
            identityRole: .pauseCompanion,
            boundaryMode: .localOnlyAdvisory,
            calibrationStatus: .stable,
            diffSummary: [],
            approvalState: approvalState,
            rollbackReady: true
        )
    }
}

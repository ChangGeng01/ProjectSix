import Foundation
import Testing
@testable import BASMemory

@Suite("L8 temporal memory field schemas")
struct BASTemporalMemoryFieldSchemaTests {
    @Test("temporal memory field stage 1 objects round trip core memory ecology metadata")
    func temporalMemoryFieldRoundTrips() throws {
        let seal = BASMemoryProvenanceSeal(
            sealID: "seal.buy.1",
            sourceClass: "pattern",
            consentRef: "host.memory.default",
            riskStateRef: "risk.standard",
            sovereignStateRef: "sovereign.clear",
            creationTurnRef: "turn.buy.1",
            verificationState: .verified
        )
        let temperatureProfile = BASMemoryTemperatureProfile(
            profileID: "temp.buy.1",
            currentBand: .warm,
            halfLifeHours: 72,
            promotionRules: ["repeat:2", "reviewed_cold_only"],
            decayRules: ["stale_decay"],
            accessRules: ["default_recall"],
            lastShiftAt: Date(timeIntervalSince1970: 1_776_200_000)
        )
        let record = BASTemporalMemoryRecord(
            memoryID: "memory.buy.1",
            summary: "Buy pressure keeps recurring when tired.",
            memoryType: .episode,
            sourceClass: "pattern",
            sourceRefs: ["semantic.scenario.buy"],
            timestamp: Date(timeIntervalSince1970: 1_776_200_100),
            certainty: 0.82,
            evidenceStrength: 0.74,
            emotionalWeight: 0.68,
            hostScope: "host.active",
            sovereignScope: "standard",
            sanctumFlag: false,
            quarantineFlag: false,
            lineageRefs: ["semantic.scenario.buy"],
            temperatureProfileRef: temperatureProfile.profileID,
            provenanceSealRef: seal.sealID
        )
        let arc = BASMemoryEpisodeArc(
            arcID: "arc.buy",
            title: "Recurring buy-pressure arc",
            linkedMemoryRefs: [record.memoryID],
            startTime: Date(timeIntervalSince1970: 1_776_200_100),
            currentState: "emerging",
            escalationPattern: "night-pressure",
            unresolvedThreads: ["sleep debt"],
            stability: 0.61
        )
        let conflict = BASMemoryConflictCluster(
            clusterID: "conflict.buy",
            memoryRefs: [record.memoryID, "memory.buy.2"],
            conflictType: .factual,
            severity: 0.58,
            preferredRef: record.memoryID,
            unresolved: true
        )
        let anchor = BASMemoryContinuityAnchor(
            anchorID: "anchor.host.active",
            hostVersionRef: "host.v1",
            activeGoalRefs: ["goal.sleep"],
            activeRelationRefs: [],
            activeArcRefs: [arc.arcID],
            samenessWeight: 0.79
        )
        let replay = BASMemoryReplayFrame(
            replayID: "replay.buy",
            targetRefs: [record.memoryID, arc.arcID],
            replayScope: .arc,
            timeline: [
                "Observed recurring buy pressure.",
                "Escalates after late-night fatigue."
            ],
            integrityHash: "replay-hash.buy"
        )
        let quarantine = BASMemoryQuarantineRecord(
            quarantineID: "quarantine.buy",
            memoryRef: "memory.buy.2",
            reasonCodes: ["tool_observation", "provenance_contamination"],
            lineageCutRef: "cut.buy.2",
            releaseConditions: ["manual_review"]
        )
        let sanctumEntry = BASMemorySanctumEntry(
            entryID: "sanctum.buy.1",
            memoryRef: record.memoryID,
            accessPolicy: "revealed_only_by_policy",
            revealConditions: ["host_authorized_recall", "l14_policy_override"]
        )
        let forgetCascade = BASMemoryForgetCascade(
            cascadeID: "forget.buy.1",
            rootTargets: [record.memoryID],
            dependentRefs: [temperatureProfile.profileID, seal.sealID, sanctumEntry.entryID],
            cacheRefs: ["projection.records"],
            foldRefs: ["fold.buy"],
            syncRefs: ["swiftdata.memory", "host.active"],
            executionState: "delete_pending"
        )
        let field = BASTemporalMemoryField(
            records: [record],
            temperatureProfiles: [temperatureProfile],
            provenanceSeals: [seal],
            episodeArcs: [arc],
            conflictClusters: [conflict],
            continuityAnchors: [anchor],
            replayFrames: [replay],
            quarantineRecords: [quarantine],
            sanctumEntries: [sanctumEntry],
            forgetCascades: [forgetCascade]
        )

        let data = try JSONEncoder().encode(field)
        let decoded = try JSONDecoder().decode(BASTemporalMemoryField.self, from: data)

        #expect(decoded.records == [record])
        #expect(decoded.temperatureProfiles == [temperatureProfile])
        #expect(decoded.provenanceSeals == [seal])
        #expect(decoded.episodeArcs == [arc])
        #expect(decoded.conflictClusters == [conflict])
        #expect(decoded.continuityAnchors == [anchor])
        #expect(decoded.replayFrames == [replay])
        #expect(decoded.quarantineRecords == [quarantine])
        #expect(decoded.sanctumEntries == [sanctumEntry])
        #expect(decoded.forgetCascades == [forgetCascade])
    }

    @Test("memory bundle carries optional temporal field without breaking legacy decoding")
    func memoryBundleSupportsTemporalFieldCompatibly() throws {
        let field = BASTemporalMemoryField(
            records: [
                BASTemporalMemoryRecord(
                    memoryID: "memory.boundary.1",
                    summary: "Protect the boundary first.",
                    memoryType: .warning,
                    sourceClass: "session",
                    sourceRefs: ["mem-1"],
                    timestamp: Date(timeIntervalSince1970: 1_776_200_200),
                    certainty: 0.84,
                    evidenceStrength: 0.60,
                    emotionalWeight: 0.31,
                    hostScope: "host.active",
                    sovereignScope: "standard",
                    lineageRefs: ["mem-1"],
                    temperatureProfileRef: nil,
                    provenanceSealRef: nil
                )
            ]
        )
        let bundle = BASMemoryBundle(
            atoms: [
                BASMemoryAtom(
                    memoryID: "mem-1",
                    summary: "Protect the boundary first.",
                    contentType: .warm,
                    source: "session",
                    confidence: 0.84,
                    conflictFingerprint: "fp-1"
                )
            ],
            retrievalTags: ["boundary"],
            conflictRefs: [],
            activeHostVersion: "host.v1",
            temporalField: field
        )

        let bundleData = try JSONEncoder().encode(bundle)
        let decodedBundle = try JSONDecoder().decode(BASMemoryBundle.self, from: bundleData)

        #expect(decodedBundle.temporalField == field)

        let legacyPayload = """
        {
          "schemaVersion": "1.0.0",
          "atoms": [
            {
              "schemaVersion": "1.0.0",
              "memoryID": "legacy-1",
              "summary": "Legacy bundle still decodes.",
              "contentType": "warm",
              "source": "archive",
              "timestamp": 0,
              "confidence": 0.77,
              "emotionalWeight": 0,
              "riskRelevance": 0,
              "hostRelevance": 0,
              "conflictFingerprint": "legacy-1",
              "promotionState": "candidate",
              "frozen": false
            }
          ],
          "retrievalTags": ["legacy"],
          "conflictRefs": [],
          "retrievedAt": 0,
          "activeHostVersion": "host.v1"
        }
        """.data(using: .utf8)!

        let legacyDecoded = try JSONDecoder().decode(BASMemoryBundle.self, from: legacyPayload)
        #expect(legacyDecoded.temporalField == nil)

        let legacyFieldPayload = """
        {
          "schemaVersion": "1.0.0",
          "records": [
            {
              "schemaVersion": "1.0.0",
              "memoryID": "legacy.memory.1",
              "summary": "Legacy field still decodes.",
              "memoryType": "warning",
              "sourceClass": "archive",
              "sourceRefs": ["legacy.memory.1"],
              "timestamp": 0,
              "certainty": 0.8,
              "evidenceStrength": 0.6,
              "emotionalWeight": 0.2,
              "hostScope": "host.active",
              "sovereignScope": "standard",
              "sanctumFlag": false,
              "quarantineFlag": false,
              "lineageRefs": ["legacy.memory.1"]
            }
          ],
          "temperatureProfiles": [],
          "provenanceSeals": [],
          "episodeArcs": [],
          "conflictClusters": [],
          "continuityAnchors": [],
          "replayFrames": [],
          "quarantineRecords": []
        }
        """.data(using: .utf8)!

        let legacyField = try JSONDecoder().decode(BASTemporalMemoryField.self, from: legacyFieldPayload)
        #expect(legacyField.records.count == 1)
        #expect(legacyField.sanctumEntries.isEmpty)
        #expect(legacyField.forgetCascades.isEmpty)
    }
}

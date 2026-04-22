import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M72 split — BASHostRuntimeEBrainMemoryService extracted from the 5039-line
// EBrainHostRuntimeSynthesis.swift.  Previously file-scope `private`, now
// default-internal so sibling files in BASHostKit (the reduced main
// `makeEBrainTurn` orchestrator and any cross-struct helpers) can reference
// it.  None of these members surface through the Qinao public API.

struct BASHostRuntimeEBrainMemoryService: BASMemoryServicing {
    let projection: BASBrainProjection
    let currentBrain: BASHostCurrentBrain
    let hostConstitution: BASHostConstitution?

    func retrieve(
        decomposeFrame: BASDecomposeFrame,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASMemoryBundle {
        let recordAtoms = projection.records.prefix(budget.retrievalDepth).map(memoryAtom(from:))
        let eventAtoms = projection.recentEvents.prefix(max(0, budget.retrievalDepth - recordAtoms.count)).map(memoryAtom(from:))
        let atoms = Array(recordAtoms) + Array(eventAtoms)

        return BASMemoryBundle(
            atoms: atoms,
            retrievalTags: orderedUnique(
                projection.records.prefix(budget.retrievalDepth).flatMap { [$0.kind.rawValue, $0.sourceType] }
                    + projection.recentEvents.flatMap(\.tags)
                    + currentBrain.retrievalTags
                    + [currentBrain.boundaryMode.rawValue]
                    + currentBrain.riskFlags.map(\.rawValue)
                    + constitutionRetrievalTags()
            ),
            conflictRefs: atoms.filter(\.frozen).map(\.memoryID),
            activeHostVersion: hostContext.activeVersion,
            temporalField: temporalField(from: atoms, hostVersion: hostContext.activeVersion)
        )
    }

    func promote(
        atom: BASMemoryAtom,
        hostContext: BASHostProfile
    ) -> BASPromotionState {
        atom.frozen ? .frozen : atom.promotionState
    }

    func freeze(memoryID: String) -> Bool {
        projection.records.contains { $0.id.uuidString == memoryID && $0.sensitivity == .high }
    }

    private func memoryAtom(from record: BASGovernedMemory) -> BASMemoryAtom {
        BASMemoryAtom(
            memoryID: record.id.uuidString,
            summary: record.content,
            contentType: contentType(for: record.tier),
            source: record.sourceType,
            timestamp: record.lastConfirmedAt ?? .now,
            confidence: record.confidence,
            emotionalWeight: record.kind == .semantic ? 0.55 : 0.22,
            riskRelevance: record.sensitivity == .high ? 0.82 : 0.38,
            hostRelevance: record.kind == .profile ? 0.88 : 0.54,
            conflictFingerprint: record.id.uuidString,
            promotionState: promotionState(for: record.governanceStatus),
            frozen: record.governanceStatus == .archived
        )
    }

    private func memoryAtom(from event: BASEventRecord) -> BASMemoryAtom {
        BASMemoryAtom(
            memoryID: event.id.uuidString,
            summary: event.content,
            contentType: .hot,
            source: event.entrySourceID ?? "event",
            timestamp: event.timestamp,
            confidence: 0.72,
            emotionalWeight: event.kind == .semantic ? 0.55 : 0.20,
            riskRelevance: event.kind == .situational ? 0.48 : 0.28,
            hostRelevance: 0.52,
            conflictFingerprint: event.id.uuidString,
            promotionState: .candidate,
            frozen: false
        )
    }

    private func contentType(for tier: BASMemoryTier) -> BASMemoryAtomContentType {
        switch tier {
        case .hot:
            .hot
        case .warm:
            .warm
        case .cold:
            .cold
        }
    }

    private func promotionState(for status: BASMemoryGovernanceStatus) -> BASPromotionState {
        switch status {
        case .candidate:
            .candidate
        case .governed:
            .admitted
        case .archived:
            .frozen
        case .quarantined, .rejected:
            .retired
        }
    }

    private func temporalField(
        from atoms: [BASMemoryAtom],
        hostVersion: String?
    ) -> BASTemporalMemoryField? {
        guard !atoms.isEmpty else {
            return nil
        }

        let profiles = atoms.map { atom in
            let band = runtimeTemperatureBand(for: atom)
            return BASMemoryTemperatureProfile(
                profileID: "temp.\(atom.memoryID)",
                currentBand: band,
                halfLifeHours: runtimeHalfLifeHours(for: band, contentType: atom.contentType),
                promotionRules: runtimePromotionRules(for: atom, band: band),
                decayRules: runtimeDecayRules(for: atom, band: band),
                accessRules: runtimeAccessRules(for: atom, band: band),
                lastShiftAt: atom.timestamp
            )
        }

        let seals = atoms.map { atom in
            BASMemoryProvenanceSeal(
                sealID: "seal.\(atom.memoryID)",
                sourceClass: atom.source,
                consentRef: "host.memory.default",
                riskStateRef: runtimeRiskStateRef(for: atom),
                sovereignStateRef: runtimeSovereignStateRef(for: atom),
                creationTurnRef: "turn.\(atom.memoryID)",
                verificationState: atom.confidence >= 0.75 ? .verified : .pending
            )
        }

        let records = atoms.enumerated().map { index, atom in
            BASTemporalMemoryRecord(
                memoryID: atom.memoryID,
                summary: atom.summary,
                memoryType: temporalMemoryType(for: atom.contentType),
                sourceClass: atom.source,
                sourceRefs: [atom.memoryID],
                timestamp: atom.timestamp,
                certainty: atom.confidence,
                evidenceStrength: min(1, atom.hostRelevance + 0.25),
                emotionalWeight: atom.emotionalWeight,
                hostScope: "host.runtime",
                sovereignScope: runtimeSovereignStateRef(for: atom),
                sanctumFlag: atom.frozen,
                quarantineFlag: atom.promotionState == .retired,
                lineageRefs: ["runtime.\(index)"],
                temperatureProfileRef: profiles[index].profileID,
                provenanceSealRef: seals[index].sealID
            )
        }

        let arc = BASMemoryEpisodeArc(
            arcID: "arc.runtime.current",
            title: "Runtime retrieval arc",
            linkedMemoryRefs: atoms.map(\.memoryID),
            startTime: atoms.map(\.timestamp).min() ?? .now,
            currentState: atoms.count > 1 ? "active" : "observed",
            escalationPattern: "runtime-retrieval",
            unresolvedThreads: atoms.filter { $0.promotionState == .candidate }.map(\.memoryID),
            stability: min(0.95, 0.45 + (Double(atoms.count) * 0.08))
        )

        let conflicts = atoms
            .filter { $0.frozen || $0.promotionState == .retired }
            .map {
                BASMemoryConflictCluster(
                    clusterID: "conflict.\($0.memoryID)",
                    memoryRefs: [$0.memoryID],
                    conflictType: .authorization,
                    severity: $0.promotionState == .retired ? 0.72 : 0.65,
                    preferredRef: $0.memoryID,
                    unresolved: true
                )
            }

        let continuity = BASMemoryContinuityAnchor(
            anchorID: "anchor.runtime.current",
            hostVersionRef: hostVersion ?? "host.runtime",
            activeGoalRefs: [],
            activeRelationRefs: [],
            activeArcRefs: [arc.arcID],
            samenessWeight: min(0.95, 0.5 + (Double(atoms.count) * 0.05))
        )

        var replayFrames = [
            BASMemoryReplayFrame(
            replayID: "replay.runtime.current",
            targetRefs: atoms.map(\.memoryID),
            replayScope: .arc,
            timeline: atoms.map { "retrieved:\($0.memoryID)" },
            integrityHash: "replay.runtime.current"
        )
        ]

        let sanctumEntries = atoms
            .filter(\.frozen)
            .map { atom in
                BASMemorySanctumEntry(
                    entryID: "sanctum.\(atom.memoryID)",
                    memoryRef: atom.memoryID,
                    accessPolicy: "revealed_only_by_policy",
                    revealConditions: [
                        "host_authorized_recall",
                        "l12_gentle_hand",
                        "l14_policy_override"
                    ]
                )
            }

        let quarantineRecords = atoms
            .filter { $0.promotionState == .retired }
            .map { atom in
                BASMemoryQuarantineRecord(
                    quarantineID: "quarantine.\(atom.memoryID)",
                    memoryRef: atom.memoryID,
                    reasonCodes: ["runtime_retired_projection"],
                    lineageCutRef: "cut.\(atom.memoryID)",
                    releaseConditions: ["manual_review", "host_reauthorize"]
                )
            }

        let forgetCascades = atoms.compactMap { atom -> BASMemoryForgetCascade? in
            let executionState: String?
            if atom.frozen {
                executionState = "freeze_active"
            } else if atom.promotionState == .retired {
                executionState = "retired_runtime"
            } else {
                executionState = nil
            }

            guard let executionState else {
                return nil
            }

            let replayID: String?
            if atom.promotionState == .retired {
                let generatedReplayID = "replay.forget.\(atom.memoryID)"
                replayFrames.append(
                    BASMemoryReplayFrame(
                        replayID: generatedReplayID,
                        targetRefs: [atom.memoryID],
                        replayScope: .deletion,
                        timeline: [
                            "runtime-retired:\(atom.memoryID)",
                            "execution:\(executionState)"
                        ],
                        integrityHash: generatedReplayID
                    )
                )
                replayID = generatedReplayID
            } else {
                replayID = nil
            }

            return BASMemoryForgetCascade(
                cascadeID: "forget.\(atom.memoryID)",
                rootTargets: [atom.memoryID],
                dependentRefs: orderedUnique(
                    [
                        "temp.\(atom.memoryID)",
                        "seal.\(atom.memoryID)",
                        atom.frozen ? "sanctum.\(atom.memoryID)" : nil,
                        atom.promotionState == .retired ? "quarantine.\(atom.memoryID)" : nil,
                        replayID
                    ].compactMap { $0 }
                ),
                cacheRefs: ["runtime.memory_bundle"],
                foldRefs: ["fold.runtime.current"],
                syncRefs: ["host.runtime", hostVersion ?? "host.runtime"],
                executionState: executionState
            )
        }

        return BASTemporalMemoryField(
            records: records,
            temperatureProfiles: profiles,
            provenanceSeals: seals,
            episodeArcs: [arc],
            conflictClusters: conflicts,
            continuityAnchors: [continuity],
            replayFrames: replayFrames,
            quarantineRecords: quarantineRecords,
            sanctumEntries: sanctumEntries,
            forgetCascades: forgetCascades
        )
    }

    private func runtimeTemperatureBand(
        for atom: BASMemoryAtom
    ) -> BASMemoryTemperatureBand {
        if atom.promotionState == .retired {
            return .quarantine
        }
        if atom.frozen {
            return .sealed
        }
        return temperatureBand(for: atom.contentType)
    }

    private func temperatureBand(
        for contentType: BASMemoryAtomContentType
    ) -> BASMemoryTemperatureBand {
        switch contentType {
        case .hot:
            .hot
        case .warm, .relation, .routine, .rule:
            .warm
        case .cold:
            .cold
        }
    }

    private func runtimeHalfLifeHours(
        for band: BASMemoryTemperatureBand,
        contentType: BASMemoryAtomContentType
    ) -> Double {
        switch band {
        case .sealed:
            1_440
        case .quarantine:
            240
        case .hot, .warm, .cold:
            halfLifeHours(for: contentType)
        }
    }

    private func halfLifeHours(
        for contentType: BASMemoryAtomContentType
    ) -> Double {
        switch contentType {
        case .hot:
            24
        case .warm, .relation, .routine:
            96
        case .cold, .rule:
            720
        }
    }

    private func runtimePromotionRules(
        for atom: BASMemoryAtom,
        band: BASMemoryTemperatureBand
    ) -> [String] {
        var rules = [atom.contentType == .cold ? "review_gated_cold_only" : "default_projection"]
        if atom.frozen {
            rules.append("sealed_runtime_projection")
        }
        if atom.promotionState == .retired {
            rules.append("retired_projection_blocked")
        }
        if band == .cold {
            rules.append("require_provenance_seal")
        }
        return orderedUnique(rules)
    }

    private func runtimeDecayRules(
        for atom: BASMemoryAtom,
        band: BASMemoryTemperatureBand
    ) -> [String] {
        switch band {
        case .sealed:
            ["frozen_until_revealed"]
        case .quarantine:
            ["blocked_until_review"]
        case .hot:
            ["rapid_decay"]
        case .warm, .cold:
            atom.contentType == .hot ? ["rapid_decay"] : ["stage_decay"]
        }
    }

    private func runtimeAccessRules(
        for atom: BASMemoryAtom,
        band: BASMemoryTemperatureBand
    ) -> [String] {
        switch band {
        case .sealed:
            ["revealed_only_by_policy"]
        case .quarantine:
            ["blocked_from_normal_retrieval"]
        case .hot, .warm, .cold:
            atom.frozen ? ["revealed_only_by_policy"] : ["default_recall"]
        }
    }

    private func runtimeRiskStateRef(
        for atom: BASMemoryAtom
    ) -> String {
        if atom.promotionState == .retired {
            return "risk.quarantine"
        }
        if atom.frozen {
            return "risk.protective"
        }
        return "risk.standard"
    }

    private func runtimeSovereignStateRef(
        for atom: BASMemoryAtom
    ) -> String {
        if atom.promotionState == .retired {
            return "quarantined"
        }
        if atom.frozen {
            return "guarded"
        }
        return "standard"
    }

    private func temporalMemoryType(
        for contentType: BASMemoryAtomContentType
    ) -> BASTemporalMemoryType {
        switch contentType {
        case .hot, .warm:
            .episode
        case .cold:
            .warning
        case .relation:
            .relation
        case .routine:
            .routine
        case .rule:
            .boundary
        }
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func constitutionRetrievalTags() -> [String] {
        guard let hostConstitution else { return [] }

        var tags: [String] = []
        if hostConstitution.goalSpine.stageState.isEmpty == false {
            tags.append("constitution_goal_stage:\(hostConstitution.goalSpine.stageState)")
        }
        tags += hostConstitution.relationGravity.highConsequenceLinks.map {
            "constitution_relation_high_consequence:\($0)"
        }
        if hostConstitution.consentLattice.memoryPromotionScope.isEmpty == false {
            tags.append("constitution_memory_promotion:\(hostConstitution.consentLattice.memoryPromotionScope)")
        }
        return tags
    }
}

import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
// M320 — `BASUnknownReserve` is defined in BASWorldPrior and is
// referenced by the optional audit-entry parameter introduced in
// chapter 七十五.
import BASWorldPrior

// MARK: - M71 split — BASEBrainRuntimeCoordinator — sovereign commit tokens / warrants / lock / quarantine /
// audit / execution receipt builders.
// buildSovereignCommitTokens / buildSovereignWarrants / makeCommitToken / makeSovereignWarrant /
// sovereignWarrantWitnessRefs / buildSovereignLock / buildQuarantineRecords /
// buildSovereignAuditEntry / sovereignRuleIDs / sovereignPolicyHash / sovereignSnapshotRef /
// sovereignDigestHex / buildSovereignExecutionReceipts.
// Extracted from the 6099-line monolith during the M71 cohesion split.

extension BASEBrainRuntimeCoordinator {
    func buildSovereignCommitTokens(
        sovereignVerdict: BASSovereignVerdict,
        runtimeTrace: BASRuntimeTrace,
        thoughtFold: BASThoughtFold,
        actionPermit: BASActionPermit,
        updateTickets: [BASUpdateTicket],
        renderedOutput: BASRenderedOutput
    ) -> [BASSovereignCommitToken] {
        guard sovereignVerdict.verdictLevel < .quarantine else {
            return []
        }

        let snapshotRef = sovereignSnapshotRef(for: thoughtFold, sessionID: runtimeTrace.sessionID)
        let turnID = "\(runtimeTrace.sessionID)#\(runtimeTrace.recordedAt.timeIntervalSinceReferenceDate)"
        var tokens: [BASSovereignCommitToken] = []

        if sovereignVerdict.revokedPermissions.contains(.checkpointCommit) == false {
            tokens.append(
                makeCommitToken(
                    sessionID: runtimeTrace.sessionID,
                    turnID: turnID,
                    scope: .checkpointCommit,
                    allowedTargets: [thoughtFold.foldID],
                    actionDigestParts: [
                        "checkpoint",
                        thoughtFold.foldID,
                        renderedOutput.mode.rawValue,
                        String(updateTickets.count)
                    ],
                    snapshotRef: snapshotRef,
                    policyHash: sovereignVerdict.policyHash,
                    issuedAt: runtimeTrace.recordedAt,
                    ttlMs: 60_000
                )
            )
        }

        if sovereignVerdict.revokedPermissions.contains(.memoryWriteHot) == false,
           updateTickets.isEmpty == false {
            tokens.append(
                makeCommitToken(
                    sessionID: runtimeTrace.sessionID,
                    turnID: turnID,
                    scope: .memoryWrite,
                    allowedTargets: updateTickets.map(\.ticketID),
                    actionDigestParts: updateTickets.flatMap(\.actionDigestParts),
                    snapshotRef: snapshotRef,
                    policyHash: sovereignVerdict.policyHash,
                    issuedAt: runtimeTrace.recordedAt,
                    ttlMs: 30_000
                )
            )
        }

        if actionPermit.requireSecondCheck,
           sovereignVerdict.revokedPermissions.contains(.renderHighRisk) == false {
            tokens.append(
                makeCommitToken(
                    sessionID: runtimeTrace.sessionID,
                    turnID: turnID,
                    scope: .renderHighRisk,
                    allowedTargets: [renderedOutput.mode.rawValue],
                    actionDigestParts: [
                        renderedOutput.mode.rawValue,
                        renderedOutput.headline,
                        renderedOutput.body
                    ],
                    snapshotRef: snapshotRef,
                    policyHash: sovereignVerdict.policyHash,
                    issuedAt: runtimeTrace.recordedAt,
                    ttlMs: 15_000
                )
            )
        }

        return tokens
    }

    func buildSovereignWarrants(
        sovereignCommitTokens: [BASSovereignCommitToken],
        sovereignVerdict: BASSovereignVerdict,
        runtimeTrace: BASRuntimeTrace
    ) -> [BASSovereignWarrant] {
        sovereignCommitTokens.map { token in
            makeSovereignWarrant(
                from: token,
                sovereignVerdict: sovereignVerdict,
                runtimeTrace: runtimeTrace
            )
        }
    }

    func makeCommitToken(
        sessionID: String,
        turnID: String,
        scope: BASSovereignCommitScope,
        allowedTargets: [String],
        actionDigestParts: [String],
        snapshotRef: String,
        policyHash: String,
        issuedAt: Date,
        ttlMs: Int
    ) -> BASSovereignCommitToken {
        let nonce = "nonce.\(UUID().uuidString.lowercased())"
        let actionDigest = sovereignDigestHex(
            actionDigestParts + [sessionID, turnID, scope.rawValue, snapshotRef, policyHash]
        )
        // M336 deep review fix: previously
        // `abs(actionDigest.hashValue)` — Swift's `String.hashValue`
        // is randomly seeded per process, so token IDs varied
        // across runs (breaking cross-session ID stability the
        // M306 multi-session demo claims). Use a deterministic
        // prefix of the SHA256 digest instead. `actionDigest` is
        // already a hex string from `sovereignDigestHex(...)`.
        let tokenID = "token.\(scope.rawValue).\(sessionID).\(actionDigest.prefix(16))"
        let signature = sovereignDigestHex(
            [
                tokenID,
                sessionID,
                turnID,
                scope.rawValue,
                actionDigest,
                snapshotRef,
                policyHash,
                String(ttlMs),
                nonce,
                String(issuedAt.timeIntervalSinceReferenceDate)
            ] + allowedTargets
        )

        return BASSovereignCommitToken(
            tokenID: tokenID,
            sessionID: sessionID,
            turnID: turnID,
            scope: scope,
            allowedTargets: allowedTargets,
            actionDigest: actionDigest,
            snapshotRef: snapshotRef,
            policyHash: policyHash,
            ttlMs: ttlMs,
            nonce: nonce,
            singleUse: true,
            signature: signature
        )
    }

    func makeSovereignWarrant(
        from token: BASSovereignCommitToken,
        sovereignVerdict: BASSovereignVerdict,
        runtimeTrace: BASRuntimeTrace
    ) -> BASSovereignWarrant {
        let jurisdictionRef = "jurisdiction.\(token.scope.rawValue)"
        let timeLockRef = "timelock.\(token.turnID).\(token.scope.rawValue).ttl_\(token.ttlMs)"
        // M336 deep review fix: same `hashValue` non-determinism
        // issue as `tokenID` above. Use deterministic SHA256 hex
        // prefix.
        let warrantID = "warrant.\(token.scope.rawValue).\(runtimeTrace.sessionID).\(token.actionDigest.prefix(16))"
        let issuedAt = runtimeTrace.recordedAt
        let expiresAt = issuedAt.addingTimeInterval(Double(token.ttlMs) / 1_000)
        let witnessRefs = sovereignWarrantWitnessRefs(
            token: token,
            sovereignVerdict: sovereignVerdict
        )
        let signature = sovereignDigestHex(
            [
                warrantID,
                token.scope.rawValue,
                token.actionDigest,
                token.tokenID,
                jurisdictionRef,
                token.snapshotRef,
                timeLockRef,
                token.policyHash,
                String(issuedAt.timeIntervalSinceReferenceDate),
                String(expiresAt.timeIntervalSinceReferenceDate),
                String(token.singleUse),
                token.signature
            ] + witnessRefs
        )

        return BASSovereignWarrant(
            warrantID: warrantID,
            scope: token.scope,
            actionDigest: token.actionDigest,
            commitTokenRef: token.tokenID,
            jurisdictionRef: jurisdictionRef,
            snapshotRef: token.snapshotRef,
            timeLockRef: timeLockRef,
            policyHash: token.policyHash,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            witnessRefs: witnessRefs,
            singleUse: token.singleUse,
            signature: signature
        )
    }

    func sovereignWarrantWitnessRefs(
        token: BASSovereignCommitToken,
        sovereignVerdict: BASSovereignVerdict
    ) -> [String] {
        let baseWitnesses = [
            "permit.\(token.turnID).\(token.scope.rawValue)",
            "integrity.\(token.snapshotRef)",
            "continuity.\(token.turnID)",
            "policy.\(token.policyHash)"
        ]

        let scopeWitnesses: [String] = switch token.scope {
        case .checkpointCommit:
            [
                "checkpoint.\(token.snapshotRef)",
                "render_mode.\(token.allowedTargets.first ?? "unknown")"
            ]
        case .memoryWrite:
            ["mutation.memory.\(token.turnID)"] + token.allowedTargets.prefix(2).map { "memory_target.\($0)" }
        case .renderHighRisk:
            [
                "render.second_check.\(token.turnID)",
                "render_target.\(token.allowedTargets.first ?? "unknown")"
            ]
        case .toolRead:
            ["tool.read.\(token.allowedTargets.first ?? "local")"]
        case .toolWrite:
            ["tool.write.\(token.allowedTargets.first ?? "local")"]
        case .hostMutate:
            ["mutation.host.\(token.turnID)"]
        }

        let verdictWitnesses = sovereignVerdict.reasonCodes.prefix(2).map { "verdict.\($0)" }
        return orderedReasonCodes(baseWitnesses + scopeWitnesses + verdictWitnesses)
    }

    func buildSovereignLock(
        sovereignVerdict: BASSovereignVerdict,
        runtimeTrace: BASRuntimeTrace
    ) -> BASSovereignLock? {
        guard sovereignVerdict.verdictLevel != .pass else {
            return nil
        }

        let scope: BASSovereignLockScope = sovereignVerdict.latched ? .session : .turn
        let releaseCondition = sovereignVerdict.latched
            ? "governance_review_required"
            : "turn_end_or_retry"

        return BASSovereignLock(
            lockID: "lock.\(runtimeTrace.sessionID).\(sovereignVerdict.verdictLevel.rawValue)",
            scope: scope,
            lockLevel: sovereignVerdict.verdictLevel,
            createdAt: runtimeTrace.recordedAt,
            releaseCondition: releaseCondition
        )
    }

    func buildQuarantineRecords(
        sovereignVerdict: BASSovereignVerdict,
        runtimeTrace: BASRuntimeTrace,
        thoughtFold: BASThoughtFold
    ) -> [BASQuarantineRecord] {
        guard sovereignVerdict.verdictLevel >= .quarantine else {
            return []
        }

        let sessionRecord = BASQuarantineRecord(
            quarantineID: "quarantine.session.\(runtimeTrace.sessionID)",
            zone: .session,
            sourceRef: runtimeTrace.sessionID,
            reasonCodes: sovereignVerdict.reasonCodes,
            isolatedAt: runtimeTrace.recordedAt,
            releasePolicy: "manual_review_or_clean_recovery",
            reviewState: .held
        )
        let cacheRecord = BASQuarantineRecord(
            quarantineID: "quarantine.cache.\(thoughtFold.foldID)",
            zone: .cache,
            sourceRef: thoughtFold.foldID,
            reasonCodes: sovereignVerdict.reasonCodes,
            isolatedAt: runtimeTrace.recordedAt,
            releasePolicy: "invalidate_after_verified_resume",
            reviewState: .held
        )
        return [sessionRecord, cacheRecord]
    }

    func buildSovereignAuditEntry(
        sovereignVerdict: BASSovereignVerdict,
        sovereignCommitTokens: [BASSovereignCommitToken],
        sovereignWarrants: [BASSovereignWarrant],
        quarantineRecords: [BASQuarantineRecord],
        runtimeTrace: BASRuntimeTrace,
        thoughtFold: BASThoughtFold,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        // M299 — optional candidate-frontier observation bundle.
        // When supplied (post-materialization), the L9 frontier
        // status code lands in `signalRefs` as additive metadata
        // — purely advisory, never escalates the verdict, never
        // changes hash chain semantics (signature simply digests
        // the longer signalRefs list deterministically).
        candidateObservationBundle: BASCandidateObservationBundle? = nil,
        // M300 — optional tribunal observation bundle. Same
        // additive-metadata contract as M299 but for L10 tribunal
        // coverage. Defaults to `thoughtFold`-only behaviour for
        // legacy / test callers that don't yet plumb the bundle.
        tribunalObservationBundle: BASTribunalObservationBundle? = nil,
        // M303 — optional Cthulhu/Abyssal pressure reading.
        // White-paper §5.1 cross-cutting projection of unknown
        // load + consequence radius + evidence debt. Producer is
        // `BASAbyssalPressureBudget.derive(...)` from existing
        // turn state; consumer (here) emits `abyssal.magnitude`
        // / `abyssal.modes` / `abyssal.escalation` codes into
        // `signalRefs`. Same additive-metadata contract — no
        // verdict escalation, no permit mutation. `nil` for
        // legacy / test callers that don't yet plumb the
        // projection.
        abyssalPressure: BASAbyssalPressure? = nil,
        // M304 — optional human-anchor signal (white paper
        // §5.3). Producer is `BASHumanAnchorProtocol.derive(...)`
        // from existing risk + permit + candidate state.
        // Consumer emits `humanAnchor.tone` + `humanAnchor.maxRisk`
        // into `signalRefs`. Doctrine red line 7 preserved
        // (watcher hint, not verdict).
        humanAnchorSignal: BASHumanAnchorSignal? = nil,
        // M304 — optional seal-envelope aggregate (white paper
        // §5.2). Producer is
        // `BASOldSealSealingProtocol.aggregate(...)` over a
        // turn's synthesized seals (one per quarantine record
        // by default). Consumer emits `seal.count` +
        // `seal.strictest` into `signalRefs` only when there's
        // at least one seal (nil → both codes elided).
        sealAggregate: BASOldSealSealingProtocol.Aggregate? = nil,
        // M305 — optional L13 evolution-lifecycle aggregate.
        // Producer is
        // `BASEvolutionLifecycleSession.aggregate(...)` over
        // freshly-synthesized sessions (one per UpdateTicket).
        // Consumer emits `lifecycle.tickets` /
        // `lifecycle.terminal` / `lifecycle.promoted` /
        // `lifecycle.stages` into `signalRefs` when non-nil.
        lifecycleAggregate: BASEvolutionLifecycleSession.Aggregate? = nil,
        // M316 — optional narrative-distortion projection (white
        // paper §7). Producer is
        // `BASNarrativeDistortion.derive(...)` from final risk +
        // permit. Consumer emits `narrative.maxAxis` +
        // `narrative.forcedClosure` + `narrative.urgencyMask`
        // into `signalRefs` only when at least one axis is
        // non-trivial. Doctrine red line 7 preserved (watcher
        // hint, not verdict).
        narrativeDistortion: BASNarrativeDistortion? = nil,
        // M317 — optional anomaly-trace projection (white paper
        // §7). Producer is `BASAnomalyTrace.deriveOrNil(...)`
        // (nil when distortion has no axis above the emit
        // threshold). Consumer emits `anomaly.types:N` +
        // `anomaly.confidence` + a sorted concatenation of
        // anomaly type raw-values when present.
        anomalyTrace: BASAnomalyTrace? = nil,
        // M318 — optional list of L9 abyssal-branch annotations
        // (white paper §7). Producer is
        // `BASAbyssalBranch.deriveAll(...)` from candidate IDs +
        // an `BASAbyssalPressure` reading; empty when below
        // abyssal threshold. Consumer emits
        // `abyssalBranch.count` + `abyssalBranch.maxLoad` +
        // optional closure-condition flag when non-empty.
        abyssalBranches: [BASAbyssalBranch] = [],
        // M320 — optional `BASUnknownReserve` projection (white
        // paper §5.4). Producer is `BASUnknownReserve.derive(...)`
        // from the L9 uncertainty ledger's confidence floor.
        // Consumer emits `unknownReserve.assertionCeiling` +
        // `unknownReserve.refs:N` when ceiling is below
        // `.unrestricted` (i.e. unknowns matter on this turn).
        unknownReserve: BASUnknownReserve? = nil,
        // M321 — optional aggregate of L13 forbidden-knowledge
        // candidates (white paper §5.5). Producer is
        // `BASForbiddenKnowledgeCandidate.aggregate(...)` over
        // candidates derived from the turn's quarantine records.
        // Consumer emits `forbidden.count` + `forbidden.policy` +
        // `forbidden.allHeld` when at least one candidate exists.
        forbiddenAggregate: BASForbiddenKnowledgeCandidate.Aggregate? = nil
    ) -> BASSovereignAuditEntry {
        let turnID = "\(runtimeTrace.sessionID)#\(runtimeTrace.recordedAt.timeIntervalSinceReferenceDate)"
        let snapshotRef = sovereignSnapshotRef(for: thoughtFold, sessionID: runtimeTrace.sessionID)
        let auditID = "audit.\(runtimeTrace.sessionID).\(sovereignVerdict.verdictLevel.rawValue)"
        let actionRefs =
            sovereignCommitTokens.map(\.tokenID)
            + sovereignWarrants.map(\.warrantID)
            + quarantineRecords.map(\.quarantineID)
        // M299 — derive frontier summary from the candidate
        // observation bundle. `summarize()` is a pure value-type
        // transform; emits at most three status codes per turn
        // (status, candidates count, diversity flag).
        var observationStatusCodes: [String] = []
        if let bundle = candidateObservationBundle {
            let summary = bundle.summarize()
            observationStatusCodes.append(
                "frontier.status:\(summary.statusCode)")
            observationStatusCodes.append(
                "frontier.candidates:\(summary.candidateCount)")
            if summary.emittedDiversitySignal {
                observationStatusCodes.append(
                    "frontier.diversity:emitted")
            }
        }
        // M300 — tribunal coverage status. Same additive code
        // shape; load-bearing for "did all three voices speak"
        // audits.
        if let tribunal = tribunalObservationBundle {
            let report = BASTribunalCoverageCheck.report(
                for: tribunal)
            observationStatusCodes.append(
                "tribunal.status:\(report.statusCode)")
            observationStatusCodes.append(
                "tribunal.voices:\(report.voicesPresent.count)")
        }
        // M303 — Cthulhu/Abyssal pressure projection. Aggregate
        // magnitude is the mean of the six dimensions; modes
        // count + sovereign-escalation hint are pure derived
        // products via `BASAbyssalPressureBudget`. All three
        // codes appear together so audit consumers can grep a
        // single `abyssal.` prefix.
        if let pressure = abyssalPressure {
            // Format magnitude with 3 decimal places for stable
            // cross-build digests; %.3f rounds half-to-even per
            // POSIX, matching the existing `risk:`/`permit:`
            // numeric-stable conventions.
            let magnitude = String(
                format: "%.3f", pressure.aggregateMagnitude)
            observationStatusCodes.append(
                "abyssal.magnitude:\(magnitude)")
            observationStatusCodes.append(
                "abyssal.modes:\(pressure.recommendedModes.count)")
            if let hint = pressure.sovereignEscalationHint {
                observationStatusCodes.append(
                    "abyssal.escalation:\(hint)")
            }
        }
        // M304 — Human-anchor signal. Tone + max-risk give L14
        // audit walkers a one-line readout of "did the surface
        // need to slow down for the host this turn?" without
        // re-running the protocol logic.
        if let anchor = humanAnchorSignal {
            let maxRisk = max(
                anchor.agencyRisk,
                max(anchor.alienationRisk,
                    max(anchor.dignityRisk,
                        anchor.overwhelmRisk)))
            observationStatusCodes.append(
                "humanAnchor.tone:" +
                "\(anchor.recommendedSurfaceTone.rawValue)")
            observationStatusCodes.append(
                "humanAnchor.maxRisk:" +
                "\(String(format: "%.3f", maxRisk))")
        }
        // M304 — Old-seal aggregate. Only emit when at least
        // one seal is present this turn (`nil` aggregate means
        // no seals → both codes elided).
        // M387 — per-policy histogram codes. Doctrine red line
        // 9 (旧印封缄不是伪删除): every seal carries typed
        // access scope into the audit trail. We emit one
        // `seal.scope:<policy>:<count>` code per non-zero entry
        // in the histogram; consumers walking the audit ledger
        // can filter sealed entries by policy without touching
        // the seal collection itself. Output is sorted by the
        // canonical strictness order so the audit trail is
        // deterministic across runs.
        if let seal = sealAggregate {
            observationStatusCodes.append(
                "seal.count:\(seal.count)")
            observationStatusCodes.append(
                "seal.strictest:" +
                "\(seal.strictestPolicy.rawValue)")
            let canonicalOrder: [BASSealAccessPolicy] = [
                .forbidden,
                .sovereignOnly,
                .hostExplicit,
                .auditedAccess,
                .passive,
            ]
            for policy in canonicalOrder {
                if let n = seal.policyHistogram[policy], n > 0 {
                    observationStatusCodes.append(
                        "seal.scope:\(policy.rawValue):\(n)")
                }
            }
        }
        // M305 — L13 evolution lifecycle aggregate. Always emit
        // `lifecycle.tickets:N` (with N=0 elided since the
        // aggregate is nil for empty collections). When N > 0,
        // also emit terminal / promoted counts and the stable
        // distinct active-stages list.
        if let lifecycle = lifecycleAggregate {
            observationStatusCodes.append(
                "lifecycle.tickets:\(lifecycle.count)")
            observationStatusCodes.append(
                "lifecycle.terminal:\(lifecycle.terminalCount)")
            observationStatusCodes.append(
                "lifecycle.promoted:\(lifecycle.promotedCount)")
            // Active stages joined with `+` so the audit string
            // grep-pattern stays single-token.
            let stages = lifecycle.activeStages
                .map(\.rawValue)
                .joined(separator: "+")
            observationStatusCodes.append(
                "lifecycle.stages:\(stages)")
        }
        // M316 — Narrative-distortion projection. Only emit when
        // at least one of the 5 distortion axes is non-trivial;
        // otherwise the audit signal would flood with zero-axis
        // hints. `narrative.forcedClosure` + `.urgencyMask` are
        // the two axes M316.derive populates; `.maxAxis` gives
        // audit walkers a one-line readout of "did this turn
        // show any distortion shape at all?".
        if let distortion = narrativeDistortion,
           distortion.isNonTrivial
        {
            observationStatusCodes.append(
                "narrative.maxAxis:" +
                "\(String(format: "%.3f", distortion.maxAxis))")
            observationStatusCodes.append(
                "narrative.forcedClosure:" +
                "\(String(format: "%.3f", distortion.forcedClosure))")
            observationStatusCodes.append(
                "narrative.urgencyMask:" +
                "\(String(format: "%.3f", distortion.urgencyMask))")
        }
        // M317 — Anomaly-trace projection. Always elide when
        // `nil` (no anomaly types crossed the emit threshold).
        // When present, emit a deterministic types-list so audit
        // walkers can grep for specific anomaly classes (e.g.
        // `anomaly.types:false-urgency` for urgency-mask audits).
        if let trace = anomalyTrace {
            let typesJoined = trace.anomalyTypes
                .map(\.rawValue)
                .sorted()
                .joined(separator: "+")
            observationStatusCodes.append(
                "anomaly.types:\(typesJoined)")
            observationStatusCodes.append(
                "anomaly.confidence:" +
                "\(String(format: "%.3f", trace.confidence))")
        }
        // M320 — `BASUnknownReserve` projection (white paper
        // §5.4). Only emit when the assertion ceiling is below
        // `unrestricted` — unrestricted means no unknown signal
        // worth reporting and would flood the audit ledger with
        // useless zero-information codes.
        if let reserve = unknownReserve,
           reserve.assertionCeiling != .unrestricted
        {
            observationStatusCodes.append(
                "unknownReserve.assertionCeiling:" +
                "\(reserve.assertionCeiling.rawValue)")
            observationStatusCodes.append(
                "unknownReserve.refs:\(reserve.unknownRefs.count)")
        }
        // M321 — `BASForbiddenKnowledgeCandidate` aggregate
        // (white paper §5.5). nil aggregate (no quarantines this
        // turn) elides all forbidden codes. When non-nil, emit
        // count + strictest shadow-trial policy + a single
        // `allHeld` flag so audit walkers can grep "did this
        // turn block any high-risk candidate from progression".
        if let forbidden = forbiddenAggregate {
            observationStatusCodes.append(
                "forbidden.count:\(forbidden.count)")
            observationStatusCodes.append(
                "forbidden.policy:" +
                "\(forbidden.strictestPolicy.rawValue)")
            if forbidden.allHeld {
                observationStatusCodes.append(
                    "forbidden.allHeld:true")
            }
        }
        // M318 — L9 abyssal-branch annotations. Empty array
        // elides all branch codes; non-empty emits count + max
        // unknown-load + escalation-flag if any branch carries a
        // sovereign-review-passed closure condition.
        if !abyssalBranches.isEmpty {
            observationStatusCodes.append(
                "abyssalBranch.count:\(abyssalBranches.count)")
            let maxLoad = abyssalBranches
                .map(\.unknownLoad)
                .max() ?? 0
            observationStatusCodes.append(
                "abyssalBranch.maxLoad:" +
                "\(String(format: "%.3f", maxLoad))")
            let escalating = abyssalBranches.contains {
                $0.requiredClosureConditions
                    .contains("sovereign-review-passed")
            }
            if escalating {
                observationStatusCodes.append(
                    "abyssalBranch.escalation:sovereign-review")
            }
        }
        let signalRefs = orderedReasonCodes(
            [
                "risk:\(riskCard.riskLevel.rawValue)",
                "permit:\(actionPermit.mode.rawValue)",
                "fold:\(thoughtFold.foldID)",
                thoughtFold.checksum.isEmpty ? nil : "fold_checksum:\(thoughtFold.checksum)",
                sovereignVerdict.forcedMode.map { "forced_mode:\($0.rawValue)" }
            ].compactMap { $0 }
                + sovereignVerdict.reasonCodes
                + sovereignWarrants.flatMap(\.witnessRefs)
                + observationStatusCodes
        )
        let ruleIDs = sovereignRuleIDs(for: sovereignVerdict)
        let signature = sovereignDigestHex(
            [
                auditID,
                runtimeTrace.sessionID,
                turnID,
                sovereignVerdict.verdictID,
                snapshotRef,
                sovereignVerdict.policyHash
            ] + ruleIDs + signalRefs + actionRefs
        )

        return BASSovereignAuditEntry(
            auditID: auditID,
            sessionID: runtimeTrace.sessionID,
            turnID: turnID,
            verdictRef: sovereignVerdict.verdictID,
            ruleIDs: ruleIDs,
            signalRefs: signalRefs,
            actionRefs: actionRefs,
            snapshotRef: snapshotRef,
            actor: .system,
            signature: signature,
            appendedAt: runtimeTrace.recordedAt
        )
    }

    func sovereignRuleIDs(
        for verdict: BASSovereignVerdict
    ) -> [String] {
        var rules: [String] = []
        if verdict.reasonCodes.contains("runtime.policy_lineage_missing") {
            rules.append("BR-SOV-001")
        }
        if verdict.reasonCodes.contains("risk_permit_conflict") {
            rules.append("BR-SOV-002")
        }
        if verdict.reasonCodes.contains("writes.review_required") {
            rules.append("BR-SOV-003")
        }
        if verdict.reasonCodes.contains("runtime.quarantine") {
            rules.append("BR-SOV-004")
        }
        if verdict.reasonCodes.contains("runtime.lockdown") {
            rules.append("BR-SOV-005")
        }
        if verdict.reasonCodes.contains(where: { $0 == "risk.high" || $0 == "risk.extreme" }) {
            rules.append("BR-SOV-006")
        }
        return unique(rules)
    }

    func sovereignPolicyHash(
        for budgetFrame: BASBudgetFrame
    ) -> String {
        let components = [
            policyLineage?.bundleVersion ?? budgetFrame.policyBundleVersion ?? "policy.none",
            policyLineage?.providerRoutingPolicyID ?? budgetFrame.policyDecisionIDs.first ?? "routing.none",
            policyLineage?.runtimeTuningPolicyID ?? budgetFrame.policyDecisionIDs.dropFirst().first ?? "tuning.none",
            policyLineage?.resolutionSourceID ?? "resolution.none"
        ]
        return sovereignDigestHex(components)
    }

    func sovereignSnapshotRef(
        for thoughtFold: BASThoughtFold,
        sessionID: String
    ) -> String {
        thoughtFold.snapshotRef?.trimmedNonEmpty
            ?? thoughtFold.rollbackAnchorRef?.trimmedNonEmpty
            ?? "snapshot.\(sessionID).\(thoughtFold.foldID)"
    }

    func sovereignDigestHex(
        _ components: [String]
    ) -> String {
        let payload = components.joined(separator: "|")
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func buildSovereignExecutionReceipts(
        sovereignActuationCommands: [BASSovereignActuationCommand],
        runtimeTrace: BASRuntimeTrace
    ) -> [BASSovereignExecutionReceipt] {
        sovereignActuationCommands.enumerated().map { index, command in
            BASSovereignExecutionReceipt(
                commandID: command.commandID,
                kind: command.kind,
                status: .executed,
                executedAt: runtimeTrace.recordedAt.addingTimeInterval(Double(index + 1) * 0.012),
                latencyMs: (index + 1) * 12,
                enforcedMode: command.forcedMode,
                reasonCodes: command.reasonCodes
            )
        }
    }

}

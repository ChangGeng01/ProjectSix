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
                    actionDigestParts: BASSovereignTurnArtifactParts.parts(
                        scope: .checkpointCommit,
                        thoughtFold: thoughtFold,
                        renderedOutput: renderedOutput,
                        updateTickets: updateTickets) ?? [],
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
                    actionDigestParts: BASSovereignTurnArtifactParts.parts(
                        scope: .memoryWrite,
                        thoughtFold: thoughtFold,
                        renderedOutput: renderedOutput,
                        updateTickets: updateTickets) ?? [],
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
                    actionDigestParts: BASSovereignTurnArtifactParts.parts(
                        scope: .renderHighRisk,
                        thoughtFold: thoughtFold,
                        renderedOutput: renderedOutput,
                        updateTickets: updateTickets) ?? [],
                    snapshotRef: snapshotRef,
                    policyHash: sovereignVerdict.policyHash,
                    issuedAt: runtimeTrace.recordedAt,
                    ttlMs: 15_000
                )
            )
        }

        // SOVEREIGNTY TODO — verified NON-GAP as of 2026-06-30 (4-tracer + 3-refuter trace
        // `toolcall-sovereign-gate-trace`). The verdict ALSO revokes `.toolWrite` / `.externalActuation`
        // (see EBrainRuntimeCoordinator+SovereignVerdict.swift:142), but there is DELIBERATELY no commit-scope
        // for them here yet: the LLM tool-dispatch path (BASToolDispatcher, in BASOrgan) is currently dead in
        // production — `toolPlanner` defaults nil and is never set, so the live turn only runs
        // `materializeToolIntent` (RunTurn.swift), which DESCRIBES tool intent without ever dispatching. A
        // whole-repo grep for `contains(.toolWrite)` matches only tests ⇒ the toolWrite revocation is write-only.
        // When a live tool-execution path is wired, CLOSE the gap here: mint a `.toolWrite` scope guarded by
        // `sovereignVerdict.revokedPermissions.contains(.toolWrite) == false` (mirroring the `.memoryWrite` branch
        // above) and wrap the live dispatch in a `BASSovereignGatedTurn` so an ungated tool-call throws
        // `noCommitTokenForScope`. Until then this is wiring debt, not an open breach.
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
        // ch1044 A1: single source of truth (byte-equal to the prior inline digest) so
        // a verifier can independently recompute it from the approved artifact.
        let actionDigest = BASSovereignActionDigest.compute(
            scope: scope, actionDigestParts: actionDigestParts,
            sessionID: sessionID, turnID: turnID,
            snapshotRef: snapshotRef, policyHash: policyHash)
        // ch1044 audit HIGH-1 fix: previously `UUID().uuidString` — a
        // process-random nonce on the NON-opt-in path, so the same turn
        // inputs produced different commit-token bytes across runs,
        // breaking replay-determinism (the token's `nonce` + `signature`
        // are stored Codable fields that reach `BASEBrainTurnResult`). This
        // is the SAME bug class M336 fixed just below for `tokenID` (was
        // randomly-seeded `String.hashValue`). Derive the nonce
        // deterministically from the turn-stable inputs — still unique per
        // (session, turn, scope, action, snapshot, policy, issuedAt) so no
        // two distinct tokens collide, but bit-identical on replay.
        // `issuedAt` is `runtimeTrace.recordedAt` (injected from the
        // request, deterministic), and `sovereignDigestHex` is a pure
        // SHA256 over its inputs (no clock/random). nonce stays the same
        // `nonce.<hex>` shape.
        let nonceDigest = sovereignDigestHexInjective([
            "nonce.v2",
            sessionID,
            turnID,
            scope.rawValue,
            actionDigest,
            snapshotRef,
            policyHash,
            String(issuedAt.timeIntervalSinceReferenceDate)
        ])
        let nonce = "nonce." + String(nonceDigest.prefix(24))
        // M336 deep review fix: previously
        // `abs(actionDigest.hashValue)` — Swift's `String.hashValue`
        // is randomly seeded per process, so token IDs varied
        // across runs (breaking cross-session ID stability the
        // M306 multi-session demo claims). Use a deterministic
        // prefix of the SHA256 digest instead. `actionDigest` is
        // already a hex string from `sovereignDigestHex(...)`.
        let tokenID = "token.\(scope.rawValue).\(sessionID).\(actionDigest.prefix(16))"
        let signature = sovereignDigestHexInjective(
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
        let signature = sovereignDigestHexInjective(
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
        forbiddenAggregate: BASForbiddenKnowledgeCandidate.Aggregate? = nil,
        // M402 — optional Kunlun axis-alignment projection.
        // Producer is `BASKunlunAxisProtocol.computeAlignment(...)`
        // from the L4 audit-projection seam. Consumer emits 3 codes
        // when non-nil:
        //   `kunlun.axis.center:%.3f` — alignment center score
        //   `kunlun.axis.deviation:<sorted+joined>` — deviation
        //     code list (omitted when no deviations)
        //   `kunlun.axis.requires-gate:true` — only when
        //     requiresGate is true (omitted when false)
        // Audit-only emission seam; M406 (chapter 九十三) wires the
        // same alignment value into L11 permit synthesis upstream.
        kunlunAxisAlignment: BASAxisAlignment? = nil,
        // M404 — optional Jade Canon seal verification readout.
        // Producer is `BASKunlunJadeCanonProtocol.verifySeal(_:)`
        // run over a per-turn seal derived for the bound action
        // permit (object class `.actionPermit`). Consumer emits:
        //   `kunlun.jade.seal:<class>:<status>` — class is the
        //     seal's object class raw value; status is
        //     `canonical` when verification passes else
        //     `defective`.
        //   `kunlun.jade.missing:<count>` — only when defective,
        //     sized by the count of failed canonical requirements
        //     (无来源 / 无签名 / 无哈希 / 无撤销路径). Per-reason
        //     codes are joined deterministic.
        // Doctrine red line 4 (玉律不能成黑箱) — every defect is
        // emitted as a stable typed reason code, never elided.
        // Audit-only emission; no permit mutation, no verdict
        // escalation at this milestone.
        jadeCanonVerification: BASKunlunJadeCanonProtocol.Verification? = nil,
        // M404 — class context for the verification, used to
        // disambiguate which canonical class was being verified.
        // Required when `jadeCanonVerification` is non-nil.
        jadeCanonObjectClass: BASJadeCanonObjectClass? = nil,
        // M405 — optional River-Origin lineage analysis. Producer
        // is `BASKunlunRiverOriginProtocol.analyze(_:)` run over a
        // per-turn `BASRiverOriginTrace`. Consumer emits:
        //   `kunlun.river.lineage:<status>` — `wellformed` when
        //     trace has at least one root + audit ref; else
        //     `partial`.
        //   `kunlun.river.upward:N` — root + tributary count
        //   `kunlun.river.downward:N` — derived object count
        //   `kunlun.river.warnings:<sorted+joined>` — only when
        //     analyzer surfaced warnings (orphan / cascade-without-
        //     consent / derived-without-permit).
        //   `kunlun.river.cut:true` — only when at least one
        //     lineage-cut is recorded (Cthulhu 斩谱 cross-link).
        // Doctrine red line 6 (源流追踪不变成隐性监控) — every
        // emission is over typed schema; no raw payload leaked.
        riverOriginLineage: BASKunlunRiverOriginProtocol.LineageReport? = nil,
        // M408 — optional Yaochi sanctum access decision. Producer
        // is `BASKunlunYaochiProtocol.evaluateAccess(...)` run over
        // a per-turn `BASYaochiSanctumEntry`. Consumer emits:
        //   `kunlun.yaochi.access:<class>:<decision>` — class is
        //     the sanctum class raw value; decision is `granted`
        //     when access permitted else `denied`.
        //   `kunlun.yaochi.reasons:<sorted+joined>` — only when
        //     denied; emits the per-reason kebab-case list
        //     (`cooling-period-active` / `human-anchor-required` /
        //     `sealed-policy` / `no-matched-conditions`).
        // Doctrine §4.4 + 红线 #3 (sanctum 不能被系统占有) —
        // audit-only emission, actual L8 gating is M413+ work.
        yaochiAccess: BASKunlunYaochiProtocol.AccessDecision? = nil,
        // M408 — class context for the access decision, used to
        // disambiguate which sanctum class was being evaluated.
        // Required when `yaochiAccess` is non-nil.
        yaochiSanctumClass: BASYaochiSanctumClass? = nil,
        // M409 — optional Heaven Gate readiness readout. Producer
        // is `BASKunlunHeavenGateProtocol.evaluateReadiness(...)`
        // run over a per-turn `BASHeavenGatePermit`. Consumer
        // emits:
        //   `kunlun.tianmen.gate:<domain>:<state>` — domain is the
        //     gate class raw value; state is one of
        //     `passed | denied | pending | remanded` per the
        //     synthesized passState.
        //   `kunlun.tianmen.ready:<bool>` — readiness verdict
        //     surfaces directly so audit walkers don't have to
        //     re-derive it.
        //   `kunlun.tianmen.reasons:<sorted+joined>` — only when
        //     readiness is false; emits per-reason kebab-case
        //     list (`missing-action-permit` / `high-stakes-needs-
        //     sovereign-warrant` / etc.).
        // Doctrine §4.3 (七 transition gates) — audit-only at this
        // milestone (M410 enriches the warrant via reason codes).
        tianmenReadiness: BASKunlunHeavenGateProtocol.Readiness? = nil,
        // M409 — class context for the gate, used to disambiguate
        // which gate class the readiness applied to. Required
        // when `tianmenReadiness` is non-nil.
        tianmenGateClass: BASKunlunGateClass? = nil,
        // M409 — pass state context for the gate (passed |
        // denied | pending | remanded). Required when
        // `tianmenReadiness` is non-nil.
        tianmenPassState: BASKunlunGateState? = nil,
        // M417 (chapter 九十七 deep-review H1 fix-pin) —
        // escalation suppression reason codes harvested at the
        // gating block when M384 abyssal or M406 kunlun
        // escalation fires red-line #8 (humanAnchor.tone ==
        // .reserved). Pre-fix the suppression codes lived only
        // in the discarded `decision.reasonCodes` and never
        // reached the audit ledger; the audit walker had no way
        // to tell "no escalation this turn" apart from
        // "escalation suppressed by reserved-anchor." Empty
        // array elides emission. Doctrine red line 8 —
        // both Cthulhu and Kunlun cross-doctrine — observable
        // via these codes.
        escalationSuppressionCodes: [String] = [],
        // M424 (chapter 一百一) — chapter 九十九 schemas wired
        // into runtime audit emission. Each closes a "typed-
        // surface-only" gap by emitting a status code into
        // signalRefs whenever the schema is non-nil and well-
        // formed. Doctrine pin: audit-only emission, no
        // decision influence.
        kunlunAxisView: BASKunlunAxisView? = nil,
        kunlunTianmenWarrant: BASKunlunTianmenWarrant? = nil,
        kunlunGateDenialWrit: BASKunlunGateDenialWrit? = nil,
        // M436 (chapter 一百四) — close the 14-layer reconciliation
        // gap. Pre-fix, `BASObservationReconciliationVerdictEngine`
        // was a library that production code never invoked (only
        // tests called it), so the substrate had ALL 12 cognitive
        // observation bundles deriving per turn but ZERO of them
        // feeding a per-turn coverage verdict into the audit
        // ledger. Per chapter 一百四 deep architecture audit:
        // 36% of layers were "极致" load-bearing; 57% were
        // "运转 not maxed" (derived but unread). M436 wires
        // `deriveLayerReconciliationReport(...)` (in
        // `EBrainRuntimeCoordinator.swift`) into the audit-build
        // seam, and this parameter carries the verdict so its
        // findings emit `reconciliation.severity` /
        // `reconciliation.findings` / `reconciliation.observed`
        // / `reconciliation.missing:<layer>` codes into
        // `signalRefs`. Doctrine pin: audit-only emission, no
        // verdict escalation, no permit mutation. Default `nil`
        // for legacy / test callers that haven't plumbed the
        // helper yet.
        layerReconciliationVerdict:
            BASObservationReconciliationVerdict? = nil,
        layerReconciliationReport:
            BASObservationReconciliationReport? = nil,
        // M436 + M436.1 — silent-bundle audit emission. Pre-
        // M436 only candidate (M299) + tribunal (M300) bundles
        // emitted `signalRefs` codes; the other 11 cognitive
        // bundles (L1 leaseLife / L2 neuralOrgan / L3
        // thoughtFold / L4 worldPrior / L5 hostConstitution /
        // L6 presence / L7 decomposition / L8 hippocampal / L11
        // risk / L12 softHand / L13 updateTicket) were derived
        // per turn but produced ZERO audit-walker visibility.
        // M436 closed 8 of these (L1/L2/L3/L5/L6/L7/L8/L12);
        // chapter 一百五's M436.1 honest-correction added the
        // remaining 3 (L4 worldPrior / L11 risk / L13
        // updateTicket) closing the asymmetric-coverage HIGH
        // gap. Each optional bundle below now contributes a
        // one-line coverage status code so audit walkers can
        // grep `<layer>.coverage:<full|partial|empty>` per
        // turn. Default `nil` keeps backward-compat for legacy
        // callers.
        presenceObservationBundle:
            BASPresenceObservationBundle? = nil,
        decompositionObservationBundle:
            BASDecompositionObservationBundle? = nil,
        softHandObservationBundle:
            BASSoftHandObservationBundle? = nil,
        leaseLifeObservationBundle:
            BASLeaseLifeObservationBundle? = nil,
        hostConstitutionObservationBundle:
            BASHostConstitutionObservationBundle? = nil,
        thoughtFoldObservationBundle:
            BASThoughtFoldObservationBundle? = nil,
        neuralOrganObservationBundle:
            BASNeuralOrganObservationBundle? = nil,
        hippocampalMemoryObservationBundle:
            BASHippocampalMemoryObservationBundle? = nil,
        // M436.1 (chapter 一百五 honest correction) — close the
        // asymmetric-coverage gap surfaced by the chapter 一百四
        // self-audit. Pre-fix L4 worldPrior / L11 risk / L13
        // updateTicket bundles entered `deriveLayerReconciliationReport`
        // (so they appeared in `reconciliation.observed:`) but never
        // got their own `<layer>.coverage:<status>` emission.
        // The chapter 一百四 changelog claimed "100% coverage"
        // which was inflated; honest tally pre-M436.1 was 8/11
        // cognitive bundles emitting per-layer codes, not 11/11.
        // M436.1 lands the missing 3 bundles to make per-layer
        // coverage actually symmetric. Defaults `nil` for legacy
        // / test callers.
        worldPriorObservationBundle:
            BASWorldPriorObservationBundle? = nil,
        riskObservationBundle:
            BASRiskObservationBundle? = nil,
        updateTicketObservationBundle:
            BASUpdateTicketObservationBundle? = nil,
        // M448-M451 (chapter 一百十八) — production wires for
        // chapter 一百十七 helpers (M444 BASCthulhuLayerProjections
        // / M445 BASCthulhuAssertionCeilingGate / M446
        // BASCthulhuPermitEscalation). Each optional projection
        // adds typed `cthulhu.*` reason codes to `signalRefs`.
        // Default `nil` keeps backward-compat for legacy callers.
        cosmicScaleView: BASCosmicScaleView? = nil,
        ontologyFog: BASOntologyFog? = nil,
        ontologyShiftMark: BASOntologyShiftMark? = nil,
        abyssalRunMode: BASAbyssalRunMode? = nil,
        abyssBudget: BASAbyssBudget? = nil,
        cthulhuAssertionCeilingReasonCodes: [String] = [],
        cthulhuPermitEscalationReasonCodes: [String] = [],
        // M456 (chapter 一百二十) — L8 memory thermal layer
        // production wire. Closes chapter 一百十七 / 一百十九
        // honest-deferred item. Emits `cthulhu.memory.thermal:
        // <rawValue>` reason code when non-nil.
        memoryTemperatureLayer: BASMemoryTemperatureLayer? = nil,
        // M480-M485 (chapter 一百二十五) — Kunlun production
        // wires for chapter-一百二十二/三 schemas. Each emits
        // typed `kunlun.<layer>.*` reason codes when non-nil.
        ascentLease: BASAscentLease? = nil,
        axisDeviation: BASAxisDeviation? = nil,
        gatePressure: BASGatePressure? = nil,
        yaochiMemoryLayer: BASYaochiMemoryLayer? = nil,
        tianhengProfile: BASTianhengProfile? = nil,
        jadePermitGrade: BASJadePermitGrade? = nil,
        // M486-M490 (chapter 一百二十六) — L9 dream-loop +
        // L3 fold-page + L13 refinement production wires.
        ascentBranches: [BASAscentBranch] = [],
        restSteps: [BASRestStep] = [],
        returnPaths: [BASReturnPath] = [],
        jadeCasket: BASJadeCasketSnapshot? = nil,
        jadeRefinementTickets: [BASJadeRefinementTicket] = [],
        // M491-M494 (chapter 一百二十七) — final Kunlun
        // host + integrity production wires.
        jadeFidelityMap: BASJadeFidelityMap? = nil,
        hostJadeRegister: BASHostJadeRegister? = nil,
        jadeMirrorDraft: BASJadeMirrorDraft? = nil,
        kunlunUnnamableSet: BASKunlunUnnamableSet? = nil,
        // M495-M498 (chapter 一百二十七) — chapter 一百二十一
        // Cthulhu leftover production wires.
        narrativeDistortionMap: BASNarrativeDistortionMap? = nil,
        sealedMemory: BASSealedMemory? = nil,
        humanAnchorProfile: BASHumanAnchorProfile? = nil,
        abyssalOrganAlias: BASAbyssalOrganAlias? = nil,
        // M500-M501 (chapter 一百二十八) — Kunlun L4 chapter-99-
        // deferred wires.
        kunlunAscentView: BASKunlunAscentView? = nil,
        kunlunFarWestReserve: BASKunlunFarWestReserve? = nil,
        // M502-M510 (chapter 一百二十八) — L12 doctrine surface
        // aliases.
        cthulhuSurfaceAlias: BASCthulhuSurfaceAlias? = nil,
        kunlunSurfaceAlias: BASKunlunSurfaceAlias? = nil
    ) -> BASSovereignAuditEntry {
        let turnID = "\(runtimeTrace.sessionID)#\(runtimeTrace.recordedAt.timeIntervalSinceReferenceDate)"
        let snapshotRef = sovereignSnapshotRef(for: thoughtFold, sessionID: runtimeTrace.sessionID)
        // deep-audit L-3 follow-on (2026-07-13): auditID must be TURN-UNIQUE. It was
        // `audit.<sessionID>.<verdictLevel>` — so two turns of the same session+verdict
        // collided on the same auditID, which the SQLite ledger's `audit_id PRIMARY KEY`
        // rejects on the second append (the ledger-host-sink was broken on SQLite for
        // multi-turn; only the uniqueness-free in-memory backend hid it). turnID already
        // carries sessionID + a per-turn timestamp, so folding it in makes the auditID
        // unique per turn while keeping sessionID grep-able as the prefix.
        let auditID = "audit.\(turnID).\(sovereignVerdict.verdictLevel.rawValue)"
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
            // M388 — emit the dominant-axis name so audit walkers
            // can grep by specific distortion shape (e.g.
            // `narrative.dominantAxis:role-inversion`). White-paper
            // red line 7 preserved: this is a hint, never a gate.
            observationStatusCodes.append(
                "narrative.dominantAxis:" +
                "\(distortion.dominantAxisName)")
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
        // M402 — Kunlun axis alignment audit emission. Always
        // emit `kunlun.axis.center:<score>`; emit
        // `kunlun.axis.deviation:<codes>` only when deviation
        // codes are present; emit `kunlun.axis.requires-gate:
        // true` only when requiresGate is true. nil alignment →
        // all codes elided.
        if let kunlun = kunlunAxisAlignment {
            observationStatusCodes.append(
                "kunlun.axis.center:" +
                "\(String(format: "%.3f", kunlun.centerScore))")
            if !kunlun.deviationCodes.isEmpty {
                let joined = kunlun.deviationCodes
                    .sorted()
                    .joined(separator: "+")
                observationStatusCodes.append(
                    "kunlun.axis.deviation:\(joined)")
            }
            if kunlun.requiresGate {
                observationStatusCodes.append(
                    "kunlun.axis.requires-gate:true")
            }
        }
        // M404 — Kunlun Jade Canon seal verification audit
        // emission. Doctrine red line 4 (玉律不能成黑箱) — every
        // defect surfaces as a typed reason code so audit walkers
        // can grep `kunlun.jade.missing:` to identify ungated
        // promotions. nil verification → all codes elided.
        if let jadeVerification = jadeCanonVerification {
            let className = jadeCanonObjectClass?.rawValue
                ?? "unknown"
            let status = jadeVerification.isCanonical
                ? "canonical"
                : "defective"
            observationStatusCodes.append(
                "kunlun.jade.seal:\(className):\(status)")
            if !jadeVerification.isCanonical {
                let missingCount = jadeVerification
                    .missingRequirements.count
                observationStatusCodes.append(
                    "kunlun.jade.missing:\(missingCount)")
                // Stable per-defect trace. Sorted to keep cross-
                // build digests deterministic.
                let joined = jadeVerification.missingRequirements
                    .sorted()
                    .joined(separator: "+")
                observationStatusCodes.append(
                    "kunlun.jade.defects:\(joined)")
            }
        }
        // M405 — Kunlun River-Origin lineage audit emission.
        // Doctrine: 没有源流就没有可信成长 (§4.5 line 612). Codes
        // surface trace shape so audit consumers can detect
        // orphans (no root / no audit) without re-running the
        // analyzer. nil report → all codes elided.
        if let lineage = riverOriginLineage {
            let status = lineage.isWellFormed
                ? "wellformed"
                : "partial"
            observationStatusCodes.append(
                "kunlun.river.lineage:\(status)")
            observationStatusCodes.append(
                "kunlun.river.upward:\(lineage.upwardCount)")
            observationStatusCodes.append(
                "kunlun.river.downward:\(lineage.downwardCount)")
            if !lineage.warningCodes.isEmpty {
                let joined = lineage.warningCodes
                    .sorted()
                    .joined(separator: "+")
                observationStatusCodes.append(
                    "kunlun.river.warnings:\(joined)")
            }
            if lineage.hasLineageCut {
                observationStatusCodes.append(
                    "kunlun.river.cut:true")
            }
        }
        // M408 — Yaochi sanctum access audit emission. Doctrine
        // §4.4 + 红线 #3 (sanctum 不能被系统占有). nil decision
        // → all codes elided.
        if let yaochi = yaochiAccess {
            let className = yaochiSanctumClass?.rawValue
                ?? "unknown"
            let decision = yaochi.granted ? "granted" : "denied"
            observationStatusCodes.append(
                "kunlun.yaochi.access:\(className):\(decision)")
            if !yaochi.granted && !yaochi.reasonCodes.isEmpty {
                // Reason codes are already prefixed with
                // `kunlun.yaochi.` by the protocol helper; here
                // we strip that prefix to keep emission compact
                // (consumer concatenates again at the
                // `kunlun.yaochi.reasons:` outer key).
                let stripped = yaochi.reasonCodes
                    .map { code -> String in
                        let prefix = "kunlun.yaochi."
                        if code.hasPrefix(prefix) {
                            return String(code.dropFirst(
                                prefix.count))
                        }
                        return code
                    }
                let joined = stripped
                    .sorted()
                    .joined(separator: "+")
                observationStatusCodes.append(
                    "kunlun.yaochi.reasons:\(joined)")
            }
        }
        // M409 — Heaven Gate (Tianmen) readiness audit emission.
        // Doctrine §4.3 (七 transition gates) — emit gate domain
        // + pass state + readiness flag + per-reason codes when
        // not ready. nil readiness → all codes elided.
        if let tianmen = tianmenReadiness {
            let domain = tianmenGateClass?.rawValue
                ?? "unknown"
            let state = tianmenPassState?.rawValue
                ?? "unknown"
            observationStatusCodes.append(
                "kunlun.tianmen.gate:\(domain):\(state)")
            observationStatusCodes.append(
                "kunlun.tianmen.ready:\(tianmen.isReady)")
            if !tianmen.isReady && !tianmen.reasonCodes.isEmpty {
                // Same prefix-stripping approach as Yaochi; helper
                // emits already-prefixed `kunlun.gate.<reason>`
                // codes.
                let stripped = tianmen.reasonCodes
                    .map { code -> String in
                        let prefix = "kunlun.gate."
                        if code.hasPrefix(prefix) {
                            return String(code.dropFirst(
                                prefix.count))
                        }
                        return code
                    }
                let joined = stripped
                    .sorted()
                    .joined(separator: "+")
                observationStatusCodes.append(
                    "kunlun.tianmen.reasons:\(joined)")
            }
            // M410 — L14 sovereign-warrant Tianmen integration.
            // Doctrine 红线 #5 (天门不绕过宿主授权): the gate must
            // refer to an existing sovereign warrant; it never
            // replaces one. Emit typed cross-protocol bind codes
            // so audit walkers can grep `kunlun.tianmen.bind:`
            // to verify host authorization is upstream of every
            // high-stakes gate.
            //
            // High-stakes gate classes (host / evolution /
            // public) MUST have a warrant present; absence emits
            // `kunlun.tianmen.warrant-missing:high-stakes` so the
            // red line #5 violation is visible in the ledger.
            if let gateClass = tianmenGateClass {
                let highStakes: Set<BASKunlunGateClass> = [
                    .host, .evolution, .public,
                ]
                let isHighStakes = highStakes.contains(gateClass)
                let firstWarrantID =
                    sovereignWarrants.first?.warrantID ?? ""
                if isHighStakes && firstWarrantID.isEmpty {
                    observationStatusCodes.append(
                        "kunlun.tianmen.warrant-missing:high-stakes")
                } else if !firstWarrantID.isEmpty {
                    observationStatusCodes.append(
                        "kunlun.tianmen.warrant-bind:" +
                        "\(firstWarrantID)")
                }
                // Stable reference-only marker that the gate was
                // evaluated against the active session axis. The
                // axis-ID derive is host-side (sessionID-keyed),
                // mirrored in the M402 emission's
                // `kunlun.axis.center` row. Audit walkers can
                // join the two by sessionID.
                observationStatusCodes.append(
                    "kunlun.tianmen.axis-bound:" +
                    "session-\(runtimeTrace.sessionID)")
            }
        }
        // M424 (chapter 一百一) — chapter 九十九 schemas runtime
        // emission. Each schema, when non-nil and well-formed,
        // emits a single status code into signalRefs. This
        // demonstrates the schemas are reachable + correctly-
        // populated at runtime (no longer "typed-surface-only").
        if let axisView = kunlunAxisView {
            let status = axisView.isWellFormed
                ? "wellformed"
                : "partial"
            observationStatusCodes.append(
                "kunlun.axis.view:\(status)")
        }
        if let warrant = kunlunTianmenWarrant {
            let auth = warrant.isFullyAuthorized
                ? "true"
                : "false"
            // §5.14 sovereign-tianmen warrant: emit under the
            // `tianmen` segment to fit the M402 segment whitelist.
            observationStatusCodes.append(
                "kunlun.tianmen.warrant-authorized:\(auth)")
        }
        if let denial = kunlunGateDenialWrit {
            // Doctrine 该断时断: denial well-formedness is the
            // pin. If a denial is present at all, it MUST be
            // well-formed (reason codes + return path + denied
            // domain non-empty); the helper enforces this on
            // every emit. Emitted under the `tianmen` segment
            // since GateDenialWrit is the §5.14 sovereign-
            // tianmen denial counterpart of TianmenWarrant.
            observationStatusCodes.append(
                "kunlun.tianmen.denial-well-formed:" +
                "\(denial.isWellFormed)")
        }
        // M418 — escalation suppression reason codes (red line 8
        // cross-doctrine). Emitted as-is so audit walkers can
        // grep `permit.escalation-skipped:` / `permit.escalation-
        // suppressed:` and see exactly which doctrine suppressed
        // (kunlun-axis-anchor-reserved / human-anchor-reserved).
        // Empty array elides emission entirely.
        //
        // M418 fix-pin (chapter 九十八 deep-review H418-1): hoisted
        // OUT of the `if let tianmen = tianmenReadiness` scope.
        // Pre-fix the loop sat inside that scope, conditionally
        // gating the suppression-code emission on the orthogonal
        // Tianmen-readiness path being active. Today every
        // runTurn invocation feeds non-nil tianmenReadiness so
        // the bug was masked, but the contract was wrong: red-
        // line-8 anchor suppression observability is independent
        // of Heaven Gate readiness, and any future caller passing
        // `tianmenReadiness: nil` (the parameter's default) would
        // silently lose all suppression observability.
        //
        // Note: emission appends raw codes — they already carry
        // typed prefixes (`permit.escalation-skipped:` /
        // `permit.escalation-suppressed:`) from the M384/M406
        // helpers.
        for code in escalationSuppressionCodes {
            observationStatusCodes.append(code)
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
        // M436 + M436.1 — silent-bundle audit emission. Each
        // per-layer bundle gets one `<layer>.coverage:<status>`
        // code so audit walkers can grep "did this layer
        // participate this turn." Status is `full` when the
        // bundle's `hasCoreSignalCoverage` predicate is true,
        // `partial` when observations exist but core coverage
        // is missing, `empty` when the bundle has zero
        // observations. Each emission is conditional on the
        // bundle being non-nil (legacy / test callers that
        // don't plumb the bundle simply elide the code).
        // Doctrine pin: audit-only emission, no decision
        // influence — purely closes the "silent bundle" audit-
        // walker gap identified by the chapter 一百四 deep
        // architecture audit (HIGH defect #2). Pre-M436: 11
        // cognitive bundles (L1/L2/L3/L4/L5/L6/L7/L8/L11/L12/
        // L13-ticket) emitted ZERO signalRefs codes despite
        // being derived per turn. M436 closed 8; M436.1's
        // chapter 一百五 honest-correction closed the remaining
        // 3 (L4 worldPrior / L11 risk / L13 updateTicket).
        // Helper extracted to a `static func` (M436.2) for
        // direct unit-test access closing the chapter 一百六
        // deep-review M-1/M-2 test-coverage gap. Local closure
        // retains the named-parameter call shape used by all
        // 11 in-function emission sites below.
        func coverageStatus(
            observations: Int, core: Bool
        ) -> String {
            Self.coverageStatus(
                observations: observations, core: core)
        }
        if let b = presenceObservationBundle {
            observationStatusCodes.append(
                "presence.coverage:" +
                coverageStatus(
                    observations: b.observations.count,
                    core: b.hasCoreChannelCoverage))
            observationStatusCodes.append(
                "presence.observations:\(b.observations.count)")
        }
        if let b = decompositionObservationBundle {
            observationStatusCodes.append(
                "decomposition.coverage:" +
                coverageStatus(
                    observations: b.observations.count,
                    core: b.hasCoreSignalCoverage))
            observationStatusCodes.append(
                "decomposition.observations:" +
                "\(b.observations.count)")
        }
        if let b = softHandObservationBundle {
            observationStatusCodes.append(
                "softHand.coverage:" +
                coverageStatus(
                    observations: b.observations.count,
                    core: b.hasCoreSignalCoverage))
            observationStatusCodes.append(
                "softHand.observations:\(b.observations.count)")
        }
        if let b = leaseLifeObservationBundle {
            observationStatusCodes.append(
                "leaseLife.coverage:" +
                coverageStatus(
                    observations: b.observations.count,
                    core: b.hasCoreSignalCoverage))
            observationStatusCodes.append(
                "leaseLife.observations:\(b.observations.count)")
        }
        if let b = hostConstitutionObservationBundle {
            observationStatusCodes.append(
                "hostConstitution.coverage:" +
                coverageStatus(
                    observations: b.observations.count,
                    core: b.hasCoreSignalCoverage))
            observationStatusCodes.append(
                "hostConstitution.observations:" +
                "\(b.observations.count)")
        }
        if let b = thoughtFoldObservationBundle {
            observationStatusCodes.append(
                "thoughtFold.coverage:" +
                coverageStatus(
                    observations: b.observations.count,
                    core: b.hasCoreSignalCoverage))
            observationStatusCodes.append(
                "thoughtFold.observations:\(b.observations.count)")
        }
        if let b = neuralOrganObservationBundle {
            observationStatusCodes.append(
                "neuralOrgan.coverage:" +
                coverageStatus(
                    observations: b.observations.count,
                    core: b.hasCoreSignalCoverage))
            observationStatusCodes.append(
                "neuralOrgan.observations:\(b.observations.count)")
        }
        if let b = hippocampalMemoryObservationBundle {
            observationStatusCodes.append(
                "hippocampal.coverage:" +
                coverageStatus(
                    observations: b.observations.count,
                    core: b.hasCoreSignalCoverage))
            observationStatusCodes.append(
                "hippocampal.observations:" +
                "\(b.observations.count)")
        }
        // M436.1 — close the asymmetric-coverage gap. L4
        // worldPrior / L11 risk / L13 updateTicket bundles
        // entered `deriveLayerReconciliationReport` (so they
        // appeared in `reconciliation.observed:`) but never
        // had their own `<layer>.coverage:<status>` per-layer
        // emission pre-fix. Closes the chapter 一百四 honest-
        // audit HIGH finding.
        if let b = worldPriorObservationBundle {
            observationStatusCodes.append(
                "worldPrior.coverage:" +
                coverageStatus(
                    observations: b.observations.count,
                    core: b.hasCoreSignalCoverage))
            observationStatusCodes.append(
                "worldPrior.observations:" +
                "\(b.observations.count)")
        }
        if let b = riskObservationBundle {
            observationStatusCodes.append(
                "risk.coverage:" +
                coverageStatus(
                    observations: b.observations.count,
                    core: b.hasCoreSignalCoverage))
            observationStatusCodes.append(
                "risk.observations:\(b.observations.count)")
        }
        if let b = updateTicketObservationBundle {
            observationStatusCodes.append(
                "updateTicket.coverage:" +
                coverageStatus(
                    observations: b.observations.count,
                    core: b.hasCoreSignalCoverage))
            observationStatusCodes.append(
                "updateTicket.observations:" +
                "\(b.observations.count)")
        }
        // M436 — reconciliation verdict emission. The verdict's
        // findings encode the substrate's per-turn answer to
        // "did all 13 expected layers participate, and did total
        // budget stay under ceiling?" — pre-fix this answer
        // existed as a library output but was never written to
        // the ledger. Now it lands as four code prefixes:
        //   reconciliation.severity:<halt|advisory|nominal>
        //   reconciliation.findings:<count>
        //   reconciliation.observed:<L1+L2+...>  (sorted)
        //   reconciliation.missing:<layer>      (one per missing)
        if let verdict = layerReconciliationVerdict,
            let report = layerReconciliationReport
        {
            // Severity is the verdict's structural answer:
            // clean / advisory / halt. The engine guarantees
            // `severity == .clean` iff `findings.isEmpty`.
            observationStatusCodes.append(
                "reconciliation.severity:" +
                "\(verdict.severity.rawValue)")
            observationStatusCodes.append(
                "reconciliation.findings:" +
                "\(verdict.findings.count)")
            // Observed layers — sorted raw values joined with
            // '+' so audit walkers can grep "did L9 participate
            // this turn" in O(log n) without re-parsing.
            let observed = report.summaries
                .map { $0.layer.rawValue }
                .sorted()
                .joined(separator: "+")
            if !observed.isEmpty {
                observationStatusCodes.append(
                    "reconciliation.observed:\(observed)")
            }
            // Per-finding emission. Missing-layer findings
            // surface as `reconciliation.missing:<layer>`;
            // missing-core-coverage as
            // `reconciliation.partial:<layer>`; budget overspend
            // as `reconciliation.overspend:<observed>:<ceiling>`.
            for finding in verdict.findings {
                switch finding {
                case .missingLayer(let layer):
                    observationStatusCodes.append(
                        "reconciliation.missing:" +
                        "\(layer.rawValue)")
                case .layerMissingCoreCoverage(let layer):
                    observationStatusCodes.append(
                        "reconciliation.partial:" +
                        "\(layer.rawValue)")
                case .budgetOverspend(let observed, let ceiling):
                    observationStatusCodes.append(
                        "reconciliation.overspend:" +
                        "\(String(format: "%.3f", observed))" +
                        ":\(String(format: "%.3f", ceiling))")
                }
            }
        }
        // M448-M451 (chapter 一百十八) — emit chapter 一百十七
        // helper outputs as typed `cthulhu.*` reason codes.
        // Doctrine pin: audit-only emission, no verdict
        // escalation. Each block elides cleanly when the
        // projection is `nil` / empty.
        if let abyssalRunMode = abyssalRunMode {
            observationStatusCodes.append(
                "cthulhu.runMode:\(abyssalRunMode.rawValue)")
        }
        if let abyssBudget = abyssBudget {
            observationStatusCodes.append(
                "cthulhu.budget.aggregateAvailability:" +
                String(format: "%.3f",
                       abyssBudget.aggregateAvailability))
        }
        if let cosmicScaleView = cosmicScaleView {
            observationStatusCodes.append(
                "cthulhu.cosmic.scale:" +
                "\(cosmicScaleView.temporalHorizon.rawValue):" +
                "\(cosmicScaleView.spatialHorizon.rawValue)")
            if cosmicScaleView.consequenceDilutionWarning {
                observationStatusCodes.append(
                    "cthulhu.cosmic.dilution:warning")
            }
        }
        if let ontologyFog = ontologyFog {
            observationStatusCodes.append(
                "cthulhu.fog.quality:" +
                ontologyFog.partialGraspQuality.rawValue)
        }
        if let memoryTemperatureLayer = memoryTemperatureLayer {
            observationStatusCodes.append(
                "cthulhu.memory.thermal:" +
                memoryTemperatureLayer.rawValue)
        }
        // M480-M485 (chapter 一百二十五) — Kunlun production
        // wires. Doctrine pin: audit-only emission, no permit
        // / verdict mutation. Each block elides cleanly when
        // the projection is nil.
        if let ascentLease = ascentLease {
            observationStatusCodes.append(
                "kunlun.ascent.mode:" +
                ascentLease.ascentMode.rawValue)
            observationStatusCodes.append(
                "kunlun.ascent.budget:" +
                "\(ascentLease.gateBudget)")
            if ascentLease.returnRequired {
                observationStatusCodes.append(
                    "kunlun.ascent.return-required")
            }
        }
        if let axisDeviation = axisDeviation {
            observationStatusCodes.append(
                "kunlun.axis.deviationScore:" +
                String(format: "%.3f",
                       axisDeviation.deviationScore))
            if !axisDeviation.reasonCodes.isEmpty {
                observationStatusCodes.append(
                    "kunlun.axis.deviationCodes:" +
                    axisDeviation.reasonCodes
                        .sorted()
                        .joined(separator: ","))
            }
        }
        if let gatePressure = gatePressure {
            observationStatusCodes.append(
                "kunlun.gate.urgency:" +
                String(format: "%.3f", gatePressure.urgency))
            if gatePressure.gateRequired {
                observationStatusCodes.append(
                    "kunlun.gate.required")
            }
        }
        if let yaochiMemoryLayer = yaochiMemoryLayer,
           !yaochiMemoryLayer.sanctumPolicy.isEmpty
        {
            observationStatusCodes.append(
                "kunlun.yaochi.policy:" +
                yaochiMemoryLayer.sanctumPolicy)
        }
        if let tianhengProfile = tianhengProfile {
            observationStatusCodes.append(
                "kunlun.tianheng.center:" +
                String(format: "%.3f",
                       tianhengProfile.centerBias))
            observationStatusCodes.append(
                "kunlun.tianheng.dignity:" +
                String(format: "%.3f",
                       tianhengProfile.dignityFloor))
            if !tianhengProfile.imbalanceCodes.isEmpty {
                observationStatusCodes.append(
                    "kunlun.tianheng.imbalance:" +
                    tianhengProfile.imbalanceCodes
                        .sorted()
                        .joined(separator: ","))
            }
        }
        if let jadePermitGrade = jadePermitGrade {
            observationStatusCodes.append(
                "kunlun.permit.grade:" +
                "\(String(format: "%.3f", jadePermitGrade.clarityScore))" +
                ":\(String(format: "%.3f", jadePermitGrade.reversibilityScore))" +
                ":\(String(format: "%.3f", jadePermitGrade.provenanceScore))")
            if !jadePermitGrade.gateRequirements.isEmpty {
                observationStatusCodes.append(
                    "kunlun.permit.gates-required")
            }
        }
        // M486-M490 (chapter 一百二十六) — L9 dream-loop + L3
        // fold-page + L13 refinement production wires.
        if !ascentBranches.isEmpty {
            observationStatusCodes.append(
                "kunlun.ascent.branchCount:" +
                "\(ascentBranches.count)")
            // §5.9 dignity invariant pin: every branch carries
            // non-empty returnPathRef.
            let dignityViolations = ascentBranches.filter {
                !$0.honorsDignityInvariant
            }.count
            if dignityViolations > 0 {
                observationStatusCodes.append(
                    "kunlun.ascent.dignity-violation:" +
                    "\(dignityViolations)")
            }
        }
        if !restSteps.isEmpty {
            observationStatusCodes.append(
                "kunlun.rest.stepCount:\(restSteps.count)")
        }
        if !returnPaths.isEmpty {
            observationStatusCodes.append(
                "kunlun.return.pathCount:\(returnPaths.count)")
            let dignityHonored = returnPaths.filter {
                $0.dignityPreserved
            }.count
            observationStatusCodes.append(
                "kunlun.return.dignityHonored:" +
                "\(dignityHonored)")
        }
        if let jadeCasket = jadeCasket {
            let verdict = jadeCasket.honorsJadeCanonInvariants
                ? "canonical"
                : "defective"
            observationStatusCodes.append(
                "kunlun.jade.casket:\(verdict)")
        }
        if !jadeRefinementTickets.isEmpty {
            observationStatusCodes.append(
                "kunlun.refinement.ticketCount:" +
                "\(jadeRefinementTickets.count)")
            let noGhostTickets = jadeRefinementTickets.filter {
                $0.honorsNoGhostInvariant
            }.count
            observationStatusCodes.append(
                "kunlun.refinement.noGhost:" +
                "\(noGhostTickets)")
        }
        // M491-M494 (chapter 一百二十七) — final Kunlun
        // host + integrity production wires.
        if let jadeFidelityMap = jadeFidelityMap {
            observationStatusCodes.append(
                "kunlun.jade.fidelity:" +
                "\(jadeFidelityMap.fidelityLevel.rawValue)")
            // §3.2 contamination invariant pin: contaminated
            // fidelity → auditRequired must be true.
            if jadeFidelityMap.fidelityLevel == .contaminated {
                let invariantHonored = jadeFidelityMap
                    .honorsContaminationInvariant
                observationStatusCodes.append(
                    "kunlun.jade.audit-required:" +
                    "\(invariantHonored ? "honored" : "violated")")
            }
        }
        if let hostJadeRegister = hostJadeRegister {
            // §5.5 provenance invariant pin: riverOriginRef
            // must be non-empty.
            let invariantHonored = hostJadeRegister
                .honorsProvenanceInvariant
            observationStatusCodes.append(
                "kunlun.host.register:" +
                "\(invariantHonored ? "honored" : "violated")")
        }
        if let jadeMirrorDraft = jadeMirrorDraft {
            // §5.7 玉鉴 invariant pin: noInducementFlag must
            // be true.
            let invariantHonored = jadeMirrorDraft
                .honorsNoInducementInvariant
            observationStatusCodes.append(
                "kunlun.jade.mirror:" +
                "\(invariantHonored ? "honored" : "violated")")
        }
        if let kunlunUnnamableSet = kunlunUnnamableSet {
            observationStatusCodes.append(
                "kunlun.unnamable.refCount:" +
                "\(kunlunUnnamableSet.unknownRefs.count)")
        }
        // M495-M498 (chapter 一百二十七) — chapter 一百二十一
        // Cthulhu leftover production wires.
        if let distortionMap = narrativeDistortionMap {
            observationStatusCodes.append(
                "cthulhu.distortionMap.subjects:" +
                "\(distortionMap.subjectRefs.count)")
            observationStatusCodes.append(
                "cthulhu.distortionMap.dominant:" +
                "\(distortionMap.dominantSubjectRef != nil)")
        }
        if let sealedMemory = sealedMemory {
            observationStatusCodes.append(
                "cthulhu.sealed.class:" +
                "\(sealedMemory.sealClass.rawValue)")
            observationStatusCodes.append(
                "cthulhu.sealed.disclosure:" +
                "\(sealedMemory.disclosureMode.rawValue)")
        }
        if let humanAnchorProfile = humanAnchorProfile {
            observationStatusCodes.append(
                "cthulhu.anchor.dignity:" +
                "\(humanAnchorProfile.dignityInvariants.count)")
            observationStatusCodes.append(
                "cthulhu.anchor.guards:" +
                "\(humanAnchorProfile.noExploitationGuards.count)")
        }
        if let abyssalOrganAlias = abyssalOrganAlias {
            observationStatusCodes.append(
                "cthulhu.organ.alias:" +
                "\(abyssalOrganAlias.rawValue)")
        }
        // M500-M501 (chapter 一百二十八) — Kunlun L4 chapter-99-
        // deferred wires.
        if let kunlunAscentView = kunlunAscentView {
            // §5.4 不急着登顶 invariant pin: view must declare
            // both preconditions AND a way back.
            observationStatusCodes.append(
                "kunlun.l4.ascent:" +
                "\(kunlunAscentView.isWellFormed ? "wellformed" : "partial")")
        }
        if let kunlunFarWestReserve = kunlunFarWestReserve {
            observationStatusCodes.append(
                "kunlun.l4.far-west.distance:" +
                "\(kunlunFarWestReserve.distanceBand.rawValue)")
            observationStatusCodes.append(
                "kunlun.l4.far-west.refCount:" +
                "\(kunlunFarWestReserve.unknownRefs.count)")
        }
        // M502-M510 (chapter 一百二十八) — L12 doctrine surface
        // aliases. Internal-only audit-walker vocabulary (red
        // line 10 — public Qinao surface unchanged).
        if let cthulhuSurfaceAlias = cthulhuSurfaceAlias {
            observationStatusCodes.append(
                "cthulhu.surface.alias:" +
                "\(cthulhuSurfaceAlias.rawValue)")
        }
        if let kunlunSurfaceAlias = kunlunSurfaceAlias {
            observationStatusCodes.append(
                "kunlun.surface.alias:" +
                "\(kunlunSurfaceAlias.rawValue)")
        }
        if let ontologyShiftMark = ontologyShiftMark,
           !ontologyShiftMark.observedShiftAxes.isEmpty
        {
            let axesJoined = ontologyShiftMark.observedShiftAxes
                .map(\.rawValue)
                .sorted()
                .joined(separator: ",")
            observationStatusCodes.append(
                "cthulhu.shift.axes:\(axesJoined)")
            observationStatusCodes.append(
                "cthulhu.shift.confidence:" +
                String(format: "%.3f",
                       ontologyShiftMark.shiftConfidence))
        }
        observationStatusCodes.append(
            contentsOf: cthulhuAssertionCeilingReasonCodes)
        observationStatusCodes.append(
            contentsOf: cthulhuPermitEscalationReasonCodes)
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
        // Comprehensive-audit fix (LOW): this coordinator-built entry terminates in the turn RESULT
        // (EBrainTurnResult.sovereignAuditEntry) and is NEVER passed to the keyed BASSovereignAuditLedger.append.
        // Emitting a KEYLESS SHA256 tag here NAMED `signature` over-claimed authentication — and would fail
        // CLOSED if ever piped to the keyed ledger (which treats a non-empty `signature` as a base64 MAC/Ed25519,
        // so a hex SHA256 string is invalid). Leave it EMPTY — matching the established empty-signature
        // convention — so the keyed ledger is the SOLE producer of a real signature when this entry is appended.
        return BASSovereignAuditEntry(
            // chapter 九百九十六.5 META-REVIEW Round-15 CRITICAL-2
            // fix:explicit "1.1.0" for hardened canonical-bytes
            // separators (U+001F inner / U+001E outer) per ch 993
            // cross-arc fix。 Round-15 caught ch 993 only bumped
            // the warrant bridge — main commit emission was still
            // using vulnerable "1.0.0" default separator class。
            // chapter 一千零十一 / M3770 — Round-21 HIGH-1 fix:
            // reference shared constant instead of inlining the
            // literal。 Future schema bump (e.g. 1.2.0) updates
            // one place。
            schemaVersion:
                BASSovereignAuditEntry.hardenedSchemaVersion,
            auditID: auditID,
            sessionID: runtimeTrace.sessionID,
            turnID: turnID,
            verdictRef: sovereignVerdict.verdictID,
            ruleIDs: ruleIDs,
            signalRefs: signalRefs,
            actionRefs: actionRefs,
            snapshotRef: snapshotRef,
            actor: .system,
            signature: "",   // keyed ledger.append is the sole signer (see note above) — no keyless over-claim
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
        // Comprehensive-audit fix (MEDIUM): present lineage → the SINGLE canonical recipe
        // (`BASTrustedPolicyHash.compute`) shared with the commit gate's INDEPENDENT recompute, so a
        // legitimately-minted token's policyHash byte-matches the gate's trusted hash and the policy-rotation
        // check is no longer tautological. Byte-IDENTICAL to the prior inline computation for a present lineage
        // (same 4 fields, same injective `lengthPrefixed`+SHA256+hex primitives).
        if let lineage = policyLineage {
            return BASTrustedPolicyHash.compute(lineage: lineage)
        }
        // Nil lineage (legacy fallback): still deterministic, but a token minted here will be REJECTED by the
        // gate's TrustedPolicyHashProvider (fail-closed on nil lineage) — so it can never authorize a commit.
        // ch1044 深入 audit fix: injective digest (was `|`-join, forgeable at any field boundary).
        let components = [
            budgetFrame.policyBundleVersion ?? "policy.none",
            budgetFrame.policyDecisionIDs.first ?? "routing.none",
            budgetFrame.policyDecisionIDs.dropFirst().first ?? "tuning.none",
            "resolution.none"
        ]
        return sovereignDigestHexInjective(components)
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
        // LEGACY (chapter 七百二十 第一刀 / M2271):
        //     return digest.map {
        //         String(format: "%02x", $0) }.joined()
        return BASAutoRouteRanker.bytesToHexLower(
            Array(digest))
    }

    /// ch1044 D3 — INJECTIVE digest: SHA256 over the length-prefixed canonical bytes
    /// (`BASSovereignCanonicalBytes`) instead of a `"|"`-join. The `"|"`-join is
    /// forgeable — an in-band `"|"` in a component (a composite `sessionID`, or a
    /// rendered headline/body in `actionDigestParts`) can shift a component boundary so
    /// two DISTINCT inputs collide onto one digest (`["a","b"]` vs `["a|b"]`). Used for
    /// the commit-token / warrant digests, whose inputs include variable-length lists
    /// AND caller-influenced text. (Byte-CHANGING vs the old tag, but deterministic; no
    /// test pins the coordinator's computed tag value — verified — so no re-pin.)
    func sovereignDigestHexInjective(_ components: [String]) -> String {
        let digest = SHA256.hash(
            data: BASSovereignCanonicalBytes.lengthPrefixed(components))
        return BASAutoRouteRanker.bytesToHexLower(Array(digest))
    }

    /// audit hostkit-spine F9 / operator decision 2B: these are COMMIT-TIME receipts — the commands
    /// were actuated (status `.executed`) but this layer measures NO per-command timing. So `latencyMs`
    /// is 0 (unmeasured sentinel, NOT a claimed 0ms) and `executedAt` is the real trace `recordedAt`
    /// for all — the previous `(index+1)*12ms` latency + per-index timestamp stagger were FABRICATED
    /// numbers presented as if measured. (Kept `.executed` + the schema; only the fake metrics dropped.)
    static func buildSovereignExecutionReceipts(
        sovereignActuationCommands: [BASSovereignActuationCommand],
        runtimeTrace: BASRuntimeTrace
    ) -> [BASSovereignExecutionReceipt] {
        sovereignActuationCommands.map { command in
            BASSovereignExecutionReceipt(
                commandID: command.commandID,
                kind: command.kind,
                status: .executed,
                executedAt: runtimeTrace.recordedAt,
                latencyMs: 0,
                enforcedMode: command.forcedMode,
                reasonCodes: command.reasonCodes
            )
        }
    }

}

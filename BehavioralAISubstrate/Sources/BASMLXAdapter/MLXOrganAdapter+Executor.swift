import Foundation
import BASRuntimeCore
import BASOrgan
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

extension MLXOrganAdapter {

    /// Execute a planned `BASDecodeStrategy` — the "execution hands" (DecodePlan S3). Each arm dispatches to an
    /// EXISTING byte-identity path (the S1 helpers / the kernels), so the OUTPUT is identical to the legacy inline
    /// routing — only WHICH lane runs differs. The "strategy brain" is `BASDecodeLanePolicy.decodeStrategy(...)`;
    /// this method makes no further decision. Every arm emits the target's argmax (ADR-039) → token-identical to
    /// plain greedy for the same request.
    ///
    /// `purpose` + `sessionID` close two gap-audit holes (查缺补漏 T2/T3) WITHOUT changing per-turn output:
    ///   • T2 — model-free lanes fold their acceptance telemetry into `draftProfiler` (the fold runs AFTER the
    ///     generate, so it cannot affect the current turn; it only makes the planner's NEXT model-free lane choice
    ///     adaptive — and every lane is byte-identical, so a different choice changes latency, not bytes). Without
    ///     this the profiler was permanently COLD in production and the router never learned.
    ///   • T3 — when a `sessionID` is supplied (the `draft(_:purpose:sessionID:)` overload), `.suffixLookup` seeds
    ///     its drafter from the cross-turn corpus and folds this turn back in, so the device-gated cross-turn win
    ///     (1.07–1.41×) is actually reachable. `sessionID == nil` (the single-shot entries) keeps the empty-store
    ///     path → byte-identical to prompt-lookup, exactly as before.
    /// NOTE — the `.draftModelSpec` lane does NOT fold telemetry: `_draftSpeculative` consumes only a chunk stream +
    /// `GenerateCompletionInfo` and never surfaces per-round accept stats, so the draft-MODEL `emaAccepted` (the
    /// `minDraftModelAccepted=2.7` gate) cannot learn from here. It is currently MOOT (no draft model is deployed);
    /// making the 2.7 gate live needs spec-accept-stat plumbing out of MLX generate (deferred follow-up).
    /// 可解释性①: THE turn line — one grep-friendly line per eager turn, emitted where the
    /// EXECUTED lane is finally known (the audit: planned-vs-executed divergence was visible
    /// only as a console error; a fail-closed draft was indistinguishable from planned-plain).
    static let turnLineEnabled = ProcessInfo.processInfo.environment["BAS_DECODE_CTX"] == "1"
    private func _finish(
        _ draft: BASOrganDraft, planned: BASDecodeStrategy, context: BASDecodeContext?,
        request: BASOrganRequest, failClose: String? = nil
    ) -> BASOrganDraft {
        // Lane funcs may have attached partial facts (trace-exit/B2/thermal) — keep them,
        // overwrite the election fields the executor owns.
        _persistExperienceIfDue()   // P0: every eager turn exits through here (post-fold)
        let partial = draft.decodeAttribution
        let executed = failClose != nil ? "plain"
            : (partial?.executedLane ?? String(describing: planned))
        let a = BASDecodeAttribution(
            requestID: request.requestID, context: context,
            plannedLane: String(describing: planned), executedLane: executed,
            failCloseReason: failClose ?? partial?.failCloseReason,
            traceExitReason: partial?.traceExitReason,
            traceThinkTokens: partial?.traceThinkTokens,
            diffProbe: partial?.diffProbe ?? .off)
        if Self.turnLineEnabled { print(a.summaryLine) }
        return draft.withDecodeAttribution(a)
    }

    func _execute(
        _ strategy: BASDecodeStrategy, for request: BASOrganRequest,
        purpose: BASDecodeLanePolicy.Purpose, sessionID: String? = nil,
        context: BASDecodeContext? = nil
    ) async throws -> BASOrganDraft {
        #if canImport(MLXLLM)
        await _ensureExperienceLoaded()   // P0: THE eager funnel (covers all draft overloads)
        switch strategy {
        case .plain:
            return _finish(try await _plainDraft(request), planned: strategy,
                           context: context, request: request)

        case .draftModelSpec:
            // `_draftSpeculative` uses the adapter's configured `numDraftTokens`; the strategy's K is advisory.
            // audit mlx-adapter-core LOW-13: fail-close to plain on error, matching every other fallible
            // arm — greedy speculation is token-identical to target-only decode, so plain is a byte-safe
            // fallback and the failure is logged (never silent).
            do {
                return _finish(try await _draftSpeculative(request), planned: strategy,
                               context: context, request: request)
            } catch {
                BASDiagnosticLog.emit("[draft-model-spec] lane fail-closed to plain: \(error)")
                return _finish(try await _plainDraft(request), planned: strategy,
                               context: context, request: request, failClose: "\(error)")
            }

        case .mtpSpecSampling:
            do {
                let g = try await _generateMTPSpec(for: request, sampling: true)
                // 缝5: TRUE proposed (K=1 ⇒ equals rounds here, but the field is now honest).
                draftProfiler = draftProfiler.observing(
                    sourceID: BASDecodeStrategy.mtpSpecSamplingID, purpose: purpose,
                    accepted: g.accepted, proposed: g.proposed, rounds: g.rounds)
                return _finish(g.draft, planned: strategy, context: context, request: request)
            } catch {
                BASDiagnosticLog.emit("[mtp-spec-sampling] lane fail-closed to plain: \(error)")
                return _finish(try await _plainDraft(request), planned: strategy,
                               context: context, request: request, failClose: "\(error)")
            }

        case .mtpSpec:
            // Full pipeline via _generateMTPSpec (template + EOS + ADR-039 lossless decode). FAIL-CLOSED:
            // any error (not Qwen3.5 / weights missing / decode failure) falls back to plain — byte-identical
            // output by the ADR-039 invariant, never silent (reason logged via the thrown error's description).
            do {
                let g = try await _generateMTPSpec(for: request)
                // LIVE acceptance telemetry (checklist trap #2: the draft-model lane's cold-forever gap must not
                // be replicated) — the planner's 0.15 floor bites on real stats.
                // 缝5 (2026-07-06 audit): fold TRUE proposed tokens (Σ kEff per round) — folding
                // rounds put the fused lane's emaHitRate on a 0-3 scale in the same ledger as the
                // model-free lanes' ≤1 (three currencies, one 0.05 floor). The per-round floors
                // (0.15/0.60) read emaAccepted and are untouched — calibration preserved.
                draftProfiler = draftProfiler.observing(
                    sourceID: BASDecodeStrategy.mtpSpecID, purpose: purpose,
                    accepted: g.accepted, proposed: g.proposed, rounds: g.rounds)
                return _finish(g.draft, planned: strategy, context: context, request: request)
            } catch {
                BASDiagnosticLog.emit("[mtp-spec] lane fail-closed to plain: \(error)")
                return _finish(try await _plainDraft(request), planned: strategy,
                               context: context, request: request, failClose: "\(error)")
            }

        case .promptLookup(let k):
            // audit H1: FAIL-CLOSED like .mtpSpec — `_generateModelFree` throws `nonTrimmableCache`
            // on a GDN/Qwen3.5 (non-trimmable Mamba/Arrays cache), and this arm had NO catch, so a
            // Qwen3.5 + serious/critical-thermal turn (which drops .mtpSpec then elects model-free)
            // threw uncaught EVERY turn instead of degrading. `_plainDraft` is the certified GDN path.
            do {
                let g = try await _generateModelFree(
                    for: request, drafter: BASPromptLookupDrafter(numDraftTokens: k))
                // T2: online telemetry → the router learns prompt-lookup's net acceptance for this purpose.
                draftProfiler = draftProfiler.observing(
                    sourceID: BASDraftSourceChoice.promptLookupID, purpose: purpose,
                    accepted: g.accepted, proposed: g.proposed, rounds: g.rounds)
                return _finish(_modelFreeDraft(body: g.body, request: request), planned: strategy,
                               context: context, request: request)
            } catch {
                BASDiagnosticLog.emit("[prompt-lookup] lane fail-closed to plain: \(error)")
                return _finish(try await _plainDraft(request), planned: strategy,
                               context: context, request: request, failClose: "\(error)")
            }

        case .suffixLookup(let k):
            // T3: seed from the session corpus when present; nil session → empty store = byte-identical to
            // prompt-lookup (the BASCrossTurnDrafter empty-store parity anchor).
            let prior = sessionID.map { crossTurnStore.tokens(session: $0) } ?? []
            // audit H1: FAIL-CLOSED (same GDN nonTrimmableCache throw as .promptLookup). The corpus
            // append + telemetry only run on a successful generate, so a throw degrades to plain with
            // no partial cross-turn mutation.
            do {
                let g = try await _generateModelFree(
                    for: request, drafter: BASCrossTurnDrafter(priorTokens: prior, numDraftTokens: k))
                // Carry THIS turn (prompt + generated) into the corpus for the next turn's cross-turn draft.
                // HOST CONTRACT (footgun): accumulate via a stable sessionID and do NOT re-send chat history in
                // request.context, else the re-rendered prompt re-contains prior turns → duplicate appends + premature
                // FIFO eviction. (A store-level synced cursor mirroring BASCrossTurnDrafter.synced is the eventual fix.)
                if let sid = sessionID {
                    crossTurnStore.append(session: sid, contentsOf: g.promptTokens + g.genTokens)
                }
                // T2: online telemetry for the cross-turn lane.
                draftProfiler = draftProfiler.observing(
                    sourceID: BASDraftSourceChoice.suffixAutomatonID, purpose: purpose,
                    accepted: g.accepted, proposed: g.proposed, rounds: g.rounds)
                return _finish(_modelFreeDraft(body: g.body, request: request), planned: strategy,
                               context: context, request: request)
            } catch {
                BASDiagnosticLog.emit("[suffix-lookup] lane fail-closed to plain: \(error)")
                return _finish(try await _plainDraft(request), planned: strategy,
                               context: context, request: request, failClose: "\(error)")
            }

        case .saguaro:
            throw BASOrganError.providerUnavailable(
                reason: "saguaro strategy requires an injected CoreAI speculator — use respondCoreAIMambaSaguaro(speculator:)")

        case .probeOnly:
            // Measure-only sentinel; the production planner never returns it. Fail-closed to plain.
            return _finish(try await _plainDraft(request), planned: strategy,
                           context: context, request: request, failClose: "probeOnly-sentinel")
        }
        #else
        throw BASOrganError.providerUnavailable(
            reason: MLXOrganAdapter.frameworkUnavailableReason
                + MLXOrganAdapter.frameworkUnavailablePlatformSuffix)
        #endif
    }
}

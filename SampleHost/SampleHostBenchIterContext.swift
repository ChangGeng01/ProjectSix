// MARK: - SampleHostBenchIterContext
//
// chapter 二百十 / M791 — per-iter pure-derive struct.
//
// Carve-out from `SampleHostModel.startHybridBench()` bench loop
// (~95 LOC of pure computation per iter). Inputs: iter index +
// per-bench config. Outputs: chosenStride / mutationSeed / layer
// profile / pressure profile / adversarial kind / final prompt /
// final signature. No I/O, no @Published, no actor — fully
// deterministic given the inputs.
//
// Why this matters (architectural deconstruction step 2 per
// ADR-004 future migration list):
//   chapter 二百九 carved out thermal cooldown into its own value
//   type. chapter 二百十 carves out the per-iter context derive.
//   Each carve-out:
//     - shrinks the bench loop body's cyclomatic load
//     - gains independent unit tests (deterministic by iter)
//     - sets up chapter 二百十一-二百十二 SampleHostBenchEngine
//       actor to consume these typed structs as input/output
//   The bench loop becomes a thin orchestrator over typed
//   value transformations. By chapter 二百十二 the loop body
//   should be < 200 LOC of pure orchestration, with all derive
//   logic + dispatch + sink in dedicated modules.
//
// Doctrine pins (red-line preservation):
//   - Red line 7 (HINT-ONLY observability):   ✓ this struct does
//     no decision-making; it just selects + derives a prompt.
//     The substrate's downstream evaluation is unchanged.
//   - 不变量 #1 (先醒再答):                     ✓ wake path unchanged.
//   - 不变量 #2 (神经不掌权):                   ✓ permit decision still
//     L11 / L14 single-mouth.
//   - 不变量 #3 (私有经验不进权重):             ✓ no weight write.
//   - chapter 一百九十二 single-source-of-truth: this file owns the
//     per-iter input→prompt+signature derive invariant. The
//     bench loop calls in via `derive(...)` and uses the result.

import Foundation

/// Pure value type capturing the per-iter context derived from an
/// iter index + per-bench config. Replaces the inline derive logic
/// that previously lived directly in `SampleHostModel.startHybridBench()`.
///
/// Construction is via `derive(...)` only — the memberwise init is
/// kept internal so call sites can't bypass the doctrine path
/// (e.g. accidentally hand-build a context that pairs `.benign`
/// smokeMode with a high-stake layer profile, which the bench
/// loop never produced).
struct SampleHostBenchIterContext: Sendable, Equatable {

    // MARK: Iter coordinates

    /// 0-based iter counter (drives all derivations).
    let iter: Int

    /// Stride from the rotation, picked via `iter / rotationPeriod`.
    let chosenStride: Int

    /// Mutation seed `iter % mutationCount`. Catalog stride-mutation
    /// reads this to vary surface form within a stride window.
    let mutationSeed: Int

    /// SmokeMode active at iter start. Captured at iter start so a
    /// mid-iter UI flip doesn't tear the iter's derive (chapter
    /// 一百九十一 doctrine).
    let smokeMode: HybridBenchConfig.SmokeMode

    // MARK: Profile + pressure

    /// 14-layer profile for this iter, if `.fourteenLayer` cycles
    /// or `.heavyTailed` weighted-pick produced one. nil for
    /// `.canonical` / `.benign` / `.rawLLM`.
    let layerProfile: FourteenLayerSmokeProfile.Profile?

    /// Heavy-tail layer name tag (only for `.heavyTailed` mode).
    /// Recorded in row.pressureProfile so JSONL replay can stratify
    /// by which layer bucket fired this iter.
    let pressureProfile: String?

    /// Adversarial mutation decided for this iter (5% prob in
    /// `.heavyTailed` mode by default; nil in others). Stored on
    /// the row so replay can group by adversarial kind.
    let adversarialKind: SampleHostBenchAdversarialKind?

    // MARK: Final prompt + signature

    /// Final prompt (catalog prompt, possibly post-adversarial).
    let prompt: String

    /// Final signature. Either:
    /// - layer profile's signature (when `layerProfile != nil`
    ///   AND `smokeMode != .benign`), OR
    /// - catalog's signature (default).
    let signature: SampleHostPromptSignature

    // MARK: Derive

    /// Per-iter pure-derive entry point. Deterministic given the
    /// inputs — every call with the same args yields a byte-equal
    /// `SampleHostBenchIterContext`.
    ///
    /// Doctrine pins (chained from chapter 一百九十一+):
    /// - chapter 一百九十一 (M711): `.fourteenLayer` cycles iter %
    ///   14 through `FourteenLayerSmokeProfile.profile(forIter:)`.
    /// - chapter 一百九十二 (M719): `.heavyTailed` picks a layer
    ///   via weighted-random `SampleHostBenchPressureMixer`.
    /// - chapter 一百九十二 (M720): adversarial mutator only fires
    ///   in `.heavyTailed` mode at the configured probability.
    /// - chapter 二百五 (M772): `.benign` mode pins low-risk
    ///   signature via `SampleHostBenignPromptCatalog`; layer
    ///   override doesn't apply.
    /// - chapter 二百八 (M784): `.rawLLM` uses catalog signatures
    ///   (any) without layer override; substrate runs as normal.
    static func derive(
        iter: Int,
        rotationPeriod: Int,
        strideRotation: [Int],
        mutationCount: Int,
        smokeMode: HybridBenchConfig.SmokeMode,
        mutationProbability: Double
    ) -> SampleHostBenchIterContext {
        // Stride / mutation seed — chapter 一百八十二 stride rotation
        // doctrine. Defensive math against zero divisors so a
        // mis-configured catalog can't crash the bench task.
        let safeRotationCount = max(1, strideRotation.count)
        let safePeriod = max(1, rotationPeriod)
        let safeMutationCount = max(1, mutationCount)
        let strideIndex = (iter / safePeriod) % safeRotationCount
        let chosenStride = strideRotation[strideIndex]
        let mutationSeed = iter % safeMutationCount

        // Layer profile + pressure tag derived from smokeMode.
        var pressureProfile: String? = nil
        let layerProfile: FourteenLayerSmokeProfile.Profile? = {
            switch smokeMode {
            case .fourteenLayer:
                return FourteenLayerSmokeProfile.profile(forIter: iter)
            case .heavyTailed:
                let layerIdx = SampleHostBenchPressureMixer
                    .pickLayerIndex(forIter: iter)
                let p = FourteenLayerSmokeProfile
                    .profile(forLayerIndex: layerIdx)
                if let p = p {
                    pressureProfile = "heavy-tail-\(p.layerName)"
                }
                return p
            case .canonical, .benign, .rawLLM:
                return nil
            }
        }()

        // Adversarial mutator. Only `.heavyTailed` enables it.
        let adversarialKind = SampleHostBenchAdversarialMutator
            .decideMutation(
                forIter: iter,
                enabled: smokeMode == .heavyTailed,
                probability: mutationProbability)

        // Catalog selection. `.benign` swaps to benign catalog;
        // every other mode uses the chapter-173+ adversarial catalog.
        let g: SampleHostGeneratedPrompt
        if smokeMode == .benign {
            g = SampleHostBenignPromptCatalog.generate(forIter: iter)
        } else {
            g = SampleHostBenchPromptCatalog
                .generateScatteredWithMutation(
                    iter: iter,
                    stride: chosenStride,
                    mutationSeed: mutationSeed)
        }

        // Final prompt: base or adversarial-overlaid.
        let basePrompt = g.prompt
        let prompt = adversarialKind?.apply(to: basePrompt) ?? basePrompt

        // Final signature: benign pin / layer override / catalog.
        let signature: SampleHostPromptSignature
        if smokeMode == .benign {
            signature = g.signature
        } else if let profile = layerProfile {
            signature = SampleHostPromptSignature(
                tone: profile.tone,
                domain: profile.domain,
                stake: profile.stake,
                timeframe: profile.timeframe,
                confidant: profile.confidant,
                askShape: profile.askShape)
        } else {
            signature = g.signature
        }

        return SampleHostBenchIterContext(
            iter: iter,
            chosenStride: chosenStride,
            mutationSeed: mutationSeed,
            smokeMode: smokeMode,
            layerProfile: layerProfile,
            pressureProfile: pressureProfile,
            adversarialKind: adversarialKind,
            prompt: prompt,
            signature: signature)
    }
}

// MARK: - Equatable conformance for FourteenLayerSmokeProfile.Profile
//
// Profile is `Sendable` but the source declaration omitted Equatable.
// Adding it via extension here so `SampleHostBenchIterContext` can
// derive Equatable automatically. Chapter 二百十 doctrine: small
// type-system additions go to the carve-out file that needs them,
// not back into the god file SampleHostModel.swift.
extension FourteenLayerSmokeProfile.Profile: Equatable {
    static func == (
        lhs: FourteenLayerSmokeProfile.Profile,
        rhs: FourteenLayerSmokeProfile.Profile
    ) -> Bool {
        return lhs.layerIndex == rhs.layerIndex
            && lhs.layerName == rhs.layerName
            && lhs.tone == rhs.tone
            && lhs.domain == rhs.domain
            && lhs.stake == rhs.stake
            && lhs.timeframe == rhs.timeframe
            && lhs.confidant == rhs.confidant
            && lhs.askShape == rhs.askShape
            && lhs.risk == rhs.risk
            && lhs.workflow == rhs.workflow
            && lhs.kind == rhs.kind
    }
}

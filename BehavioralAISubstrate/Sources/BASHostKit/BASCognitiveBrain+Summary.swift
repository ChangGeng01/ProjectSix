// MARK: - BASCognitiveBrain summary DTO · observation · derived signals · history queries
// chapter 一千〇四十 / WS-brain-decomp — relocated from BASCognitiveBrain.swift (god-object split).
// `extension BASCognitiveBrain` method cluster — same actor, same symbols, call sites unchanged.
// Pure relocation ⇒ byte-equal (cascade-digest net).

import Foundation
import CryptoKit
import BASMemory
import BASPolicy
import BASRuntimeCore
import BASMetalSubstrate
import BASRustCoreBridge
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

extension BASCognitiveBrain {
    /// Run the cognitive cascade + return the lightweight
    /// summary DTO instead of the full BASEBrainTurnResult。
    /// This is the recommended API for typical host
    /// integration where the full audit cascade fields
    /// aren't needed。
    ///
    /// Equivalent to calling process(_:) + safetyVerdict
    /// (_:) but only runs the cascade ONCE (safetyVerdict
    /// internally calls process so calling them separately
    /// runs the cascade twice)。
    public func summary(
        _ input: String,
        deviceState: BASDeviceState =
            BASCognitiveBrain.defaultDeviceState,
        hostID: String =
            BASCognitiveBrain.defaultHostID
    ) async -> BASCognitiveBrainSummary {
        // C pilot integration: measure wall-clock latency
        // via clock_gettime_nsec_np (or DispatchTime
        // fallback)。
        let startNanos = await currentNanos()
        // 主线 加强 实用性 — query native pilots for
        // repetition signals BEFORE recording this call so
        // the count reflects "occurrences BEFORE this one"。
        let nativeSignals = await nativeRepetitionSignals(
            forInput: input)
        // 主线 继续 开发 — when Metal is wired,compute a
        // deterministic per-input signature on the GPU。
        // Nil-on-failure; cascade never blocks on Metal。
        let metalSignal = await computeMetalDerivedSignal(
            forInput: input)
        if let cachedSummary = await cxxCachedSummary(
            forInput: input,
            startedAtNanos: startNanos)
        {
            // 主线 加强 实用性:layer fresh native-pilot
            // signals onto the cached ML-classification
            // result。 The ML parts don't change across
            // cache hits,but repetitionCount + Metal
            // signature MUST be computed per-call。
            let layered = cachedSummary
                .withNativePilotSignals(
                    repetitionCount:
                        nativeSignals.repetitionCount,
                    crossSessionEcho:
                        nativeSignals.crossSessionEcho,
                    metalDerivedSignal: metalSignal)
            await recordSummaryObservation(layered)
            await maybeAutoCaptureHealthSnapshot()
            return layered
        }
        let result = await process(
            input,
            deviceState: deviceState,
            hostID: hostID)
        let endNanos = await currentNanos()
        // Saturating subtraction: clamp to 0 if the clock
        // somehow went backwards (shouldn't happen on a
        // monotonic clock, but defensive).
        let latencyNanos: UInt64 = endNanos > startNanos
            ? endNanos - startNanos
            : 0
        // confidence ≡ 1 - ambiguityScore (BASMLContextService
        // sets ambiguityScore as the softmax-confidence
        // complement). Documented inversion, not a magic
        // constant.
        let confidence =
            BASCognitiveBrain.ambiguityComplement
                - result.contextFrame.ambiguityScore
        let verdict: BASCognitiveSafetyVerdict
        if confidence >=
            instanceSafetyConfidenceThreshold
        {
            switch result.contextFrame.taskType {
            case .manipulationRisk:
                verdict = .block
            case .highPressure, .highConsequence,
                .conflict:
                verdict = .warn
            case .chat, .task, .choice:
                verdict = .safe
            }
        } else {
            verdict = .safe
        }
        // 主线 Metal cascade influence — when configured
        // AND the per-input signature exceeds threshold,
        // append a typed hint to the manipulationHints
        // array。 Hosts that consume manipulationHints
        // for downstream safety / audit logic now see
        // real Metal contribution。
        var hintsWithMetal: [String] =
            result.contextFrame.manipulationHints
        if let threshold = metalSignalThreshold,
           let sig = metalSignal,
           Double(sig) > threshold
        {
            hintsWithMetal.append(
                String(
                    format: "metal.high-signal=%.4f",
                    Double(sig)))
        }
        let summary = BASCognitiveBrainSummary(
            input: result.contextFrame.utterance,
            taskType: result.contextFrame.taskType,
            confidence: confidence,
            ambiguityScore:
                result.contextFrame.ambiguityScore,
            safetyVerdict: verdict,
            manipulationHints: hintsWithMetal,
            latencyNanos: latencyNanos,
            emotionalLoad:
                result.contextFrame.emotionalLoad,
            timePressure:
                result.contextFrame.timePressure,
            consequenceLevel:
                result.contextFrame.consequenceLevel,
            relationPattern:
                result.contextFrame.relationPattern,
            repetitionCount:
                nativeSignals.repetitionCount,
            crossSessionEcho:
                nativeSignals.crossSessionEcho,
            metalDerivedSignal: metalSignal)
        await recordSummaryObservation(summary)
        // C++ pilot integration:persist to process-global
        // cache so subsequent calls with the same input
        // get cache hits。 Non-fatal on encode/bridge error。
        //
        // 主线 继续 开发 — switched from
        // `cacheSummary` (unconditional overwrite) to
        // `cacheSummaryIfAbsent` (first-write-wins via
        // C++ lookupOrInsert)。 Eliminates the TOCTOU
        // window where two concurrent brain.summary
        // calls with the same input both insert,with
        // the second clobbering the first。 First write
        // wins;subsequent identical-input misses see
        // the first inserter's value via the cache hit
        // path on next call。
        if let cache = cxxSummaryCache {
            _ = try? await cache.cacheSummaryIfAbsent(
                summary)
        }
        await maybeAutoCaptureHealthSnapshot()
        return summary
    }

    /// 持续性 发展 — increments the per-summary counter
    /// and captures a healthSnapshot when the counter hits
    /// a multiple of `healthSnapshotAutoCaptureEvery`。
    /// No-op when auto-capture disabled (0) OR when no
    /// healthHistory ring buffer is allocated。
    private func maybeAutoCaptureHealthSnapshot() async {
        summaryCallCount += 1
        guard healthSnapshotAutoCaptureEvery > 0,
              healthHistory != nil
        else { return }
        if summaryCallCount
            % healthSnapshotAutoCaptureEvery == 0
        {
            _ = await recordHealthSnapshot()
        }
    }

    private func cxxCachedSummary(
        forInput input: String,
        startedAtNanos startNanos: UInt64
    ) async -> BASCognitiveBrainSummary? {
        guard let cache = cxxSummaryCache,
              let cached = await cache.cachedSummary(
                forInput: input)
        else {
            return nil
        }
        let endNanos = await currentNanos()
        let cacheLatency: UInt64 = endNanos > startNanos
            ? endNanos - startNanos
            : 0
        return BASCognitiveBrainSummary(
            input: cached.input,
            taskType: cached.taskType,
            confidence: cached.confidence,
            ambiguityScore: cached.ambiguityScore,
            safetyVerdict: cached.safetyVerdict,
            manipulationHints: cached.manipulationHints,
            latencyNanos: cacheLatency,
            emotionalLoad: cached.emotionalLoad,
            timePressure: cached.timePressure,
            consequenceLevel: cached.consequenceLevel,
            relationPattern: cached.relationPattern)
    }

    private func recordSummaryObservation(
        _ summary: BASCognitiveBrainSummary
    ) async {
        if summaryHistoryCapacity > 0 {
            summaryHistory.append(summary)
            while summaryHistory.count > summaryHistoryCapacity {
                summaryHistory.removeFirst()
            }
        }
        // chapter 七百五十七 第四刀 / M2440 — capture a SINGLE
        // timestamp once at the brain layer,thread it into both
        // history stores。 Without this,each store's tracker
        // stamps its own Date()/SystemTime independently,which
        // can disagree by tens of microseconds under load。 That
        // disagreement made `recentRecords(limit: 1)` from the
        // two stores return records from different inputs even
        // though both stores held the same set,which surfaced as
        // a flaky atomID-parity assertion in
        // BASProductionAdoptionSmokeTests.testCanonicalAuditCompliance
        // HostAdoption。 Fix:single source-of-truth timestamp →
        // cross-store ordering byte-equal by construction。
        let retrievedAt = Date()
        if let store = sqlHistoryStore {
            _ = try? await store.recordSummary(
                summary, retrievedAt: retrievedAt)
        }
        // Rust pilot — same write semantics as SQL store,
        // backed by the Rust-vendored memory tracker
        // instead of SQLite。 try? keeps Rust failures
        // (V1 mode / platform without XCFramework slice)
        // non-fatal — the cognitive pipeline never blocks
        // on telemetry storage failures。
        if let store = rustHistoryStore {
            _ = try? await store.recordSummary(
                summary, retrievedAt: retrievedAt)
        }
    }

    /// 主线 加强 实用性 — query the native history pilots
    /// for input-repetition signals BEFORE recording the
    /// current call。 Returns a tuple of:
    ///   - repetitionCount: prior occurrences of this
    ///     input across all history (Rust preferred,SQL
    ///     fallback,0 if neither wired)
    ///   - crossSessionEcho: true if prior occurrences
    ///     span >= 2 distinct sessionRef values
    ///
    /// Rust path uses the round-3 atom-filter FFI
    /// (`recordsForAtom`) — query goes into Rust under
    /// one read lock,no Swift-side allRecords() fold。
    /// SQL path uses native `usageCountViaSQL` +
    /// recordsForInputViaSQL — both push the WHERE into
    /// the engine。
    ///
    /// Best-effort: failures surface as (0, false) rather
    /// than throwing。 Hosts wanting strict propagation
    /// can query the underlying stores directly。
    /// 主线 全面 开发 — expose the 8-channel Metal-derived
    /// SIGNATURE VECTOR (not the L2-reduced scalar)。
    ///
    /// `brain.summary` already computes this internally
    /// + reduces it to `metalDerivedSignal` (a Float)。
    /// This entry point exposes the underlying 8-element
    /// [Float] vector — letting hosts:
    ///   - Combine with `brain.cosineSimilarity(a, b)`
    ///     for input-similarity comparison
    ///   - Store signatures in their own index for NN
    ///     search across past inputs
    ///   - Build clustering / dedup features without
    ///     constructing a new pilot
    ///
    /// Returns nil when no Metal loader is wired or the
    /// dispatch fails。 Returns an 8-element vector on
    /// success — the y[] output of the SSMScan kernel
    /// for this input's SHA256-derived channel inputs。
    ///
    /// Deterministic:same input → identical 8-vector
    /// across runs (chapter 392 replay-determinism
    /// preserved)。 Two inputs with similar SHA256
    /// prefixes will have similar — but not identical —
    /// signature vectors。 Two inputs with different
    /// SHA256 prefixes are statistically guaranteed to
    /// produce different signature vectors。
    public func derivedSignalVector(
        forInput input: String
    ) async -> [Float]? {
        return await computeMetalDerivedSignalVector(
            forInput: input)
    }

    /// 主线 继续 开发 — compute the Metal-derived
    /// deterministic signature for `input`。 Nil when:
    ///   - No Metal loader wired
    ///   - Dispatch failed (V1 mode,Metal unavailable,
    ///     compile error)
    ///   - Non-Apple platform (Metal not importable)
    ///
    /// Same input → identical signature across runs。
    /// Hosts can use this as a cross-language fingerprint
    /// without re-running CoreML。
    ///
    /// 持续性 发展 — D bumped from 2 to 8。 Uses the FULL
    /// SHA256 output (32 bytes → 8 channels × 4 bytes
    /// each)。 Richer signature without changing the
    /// deterministic property — same input still produces
    /// identical signature。 8D L2-norm reduction
    /// preserves the original "sign-invariant scalar
    /// magnitude" semantics from D=2。
    private func computeMetalDerivedSignal(
        forInput input: String
    ) async -> Float? {
        guard let y = await
            computeMetalDerivedSignalVector(
                forInput: input)
        else { return nil }
        // 8D L2 norm — single deterministic scalar
        // signature with sign invariance。 Richer
        // input-sensitivity than D=2 while keeping
        // the same scalar return type。
        var sumSq: Float = 0
        for v in y { sumSq += v * v }
        return sqrt(sumSq)
    }

    /// 主线 全面 开发 — shared helper:run the SSMScan
    /// kernel on SHA256-derived 8-channel input and
    /// return the full 8-element y[] vector。 Both
    /// `computeMetalDerivedSignal` (reduce to L2 norm)
    /// AND `derivedSignalVector` (expose raw vector)
    /// delegate here so the math is single-sourced。
    private func computeMetalDerivedSignalVector(
        forInput input: String
    ) async -> [Float]? {
        guard metalLibraryLoader != nil else {
            return nil
        }
        // Derive 8-channel x[] from full SHA256 (32 bytes)。
        let digest = SHA256.hash(
            data: Data(input.utf8))
        let seedBytes = Array(digest)
        guard seedBytes.count >= 32 else { return nil }
        var channels: [Float] = []
        channels.reserveCapacity(8)
        for i in 0..<8 {
            let base = i * 4
            let u = (UInt32(seedBytes[base]) << 24)
                | (UInt32(seedBytes[base + 1]) << 16)
                | (UInt32(seedBytes[base + 2]) << 8)
                | UInt32(seedBytes[base + 3])
            channels.append(
                Float(u) / Float(UInt32.max) - 0.5)
        }
        // Build (B=1, L=1, D=8) inputs。 Math per channel:
        //   A_bar[d] = exp(delta[d] * A[d])
        //   B_bar[d] = delta[d] * B[d]
        //   h_1[d]   = B_bar[d] * x[0,d]
        //   y_1[d]   = C[d] * h_1[d]
        let shape = BASSSMScanShape(B: 1, L: 1, D: 8)
        let x: [Float] = channels
        let delta: [Float] = channels.map {
            abs($0) + 0.5
        }
        let A: [Float] = [Float](
            repeating: -0.5, count: 8)
        let B: [Float] = [Float](
            repeating: 1.0, count: 8)
        let C: [Float] = [Float](
            repeating: 1.0, count: 8)
        do {
            let y = try await dispatchSSMScan(
                x: x, delta: delta, A: A, B: B, C: C,
                shape: shape)
            guard y.count == 8 else { return nil }
            return y
        } catch {
            return nil
        }
    }

    private func nativeRepetitionSignals(
        forInput input: String
    ) async -> (repetitionCount: Int,
                crossSessionEcho: Bool)
    {
        if let store = rustHistoryStore {
            if let records = try? await store
                .recordsForInputViaRust(forInput: input)
            {
                let priorCount = records.count
                let currentSession = await store.sessionRef
                // Cross-session echo:any prior record
                // carries a sessionRef OTHER than this
                // store's current one → input was seen
                // outside this brain instance。
                let echo = records.contains { record in
                    record.sessionRef != currentSession
                }
                return (
                    repetitionCount: priorCount,
                    crossSessionEcho: echo)
            }
        }
        if let store = sqlHistoryStore {
            if let records = try? await store
                .recentRecordsForInputViaSQL(
                    forInput: input, limit: Int.max)
            {
                let priorCount = records.count
                let currentSession = await store.sessionRef
                let echo = records.contains { record in
                    record.sessionRef != currentSession
                }
                return (
                    repetitionCount: priorCount,
                    crossSessionEcho: echo)
            }
        }
        return (repetitionCount: 0,
            crossSessionEcho: false)
    }

    /// Return up to `limit` most-recent summaries from the
    /// in-memory history buffer。 Newest last (append order)。
    /// Empty if no summary() calls or history disabled
    /// (`summaryHistoryCapacity == 0`)。
    public func recentSummaries(
        limit: Int = .max
    ) -> [BASCognitiveBrainSummary] {
        let take = min(max(0, limit), summaryHistory.count)
        if take == 0 { return [] }
        return Array(summaryHistory.suffix(take))
    }

    /// Number of summaries currently held in history。
    public var summaryHistoryCount: Int {
        return summaryHistory.count
    }

    /// Clear the in-memory history buffer。 Hosts call this
    /// when starting a new user session,switching users,
    /// or honoring an explicit "forget recent" request。
    /// Does NOT affect SQL or C++ pilot persistence —
    /// those are separately addressable via their own
    /// `clear()` surfaces。
    public func clearSummaryHistory() {
        summaryHistory.removeAll(keepingCapacity: true)
    }

    /// Filter history by safety verdict。 Returns oldest-
    /// first ordering matching `recentSummaries(limit:)`
    /// conventions。 Use for audit views like "show me all
    /// blocked turns" or "show me all warnings"。
    public func summaries(
        withVerdict verdict: BASCognitiveSafetyVerdict
    ) -> [BASCognitiveBrainSummary] {
        return summaryHistory.filter {
            $0.safetyVerdict == verdict
        }
    }

    /// Filter history by ML task type。 Use for telemetry
    /// like "how many manipulation attempts has this user
    /// made today" or "what fraction of turns are chat
    /// vs task"。
    public func summaries(
        withTaskType taskType: BASContextTaskType
    ) -> [BASCognitiveBrainSummary] {
        return summaryHistory.filter {
            $0.taskType == taskType
        }
    }

    /// History entries that surfaced at least one
    /// manipulation hint。 Useful for safety-review
    /// dashboards regardless of the final verdict
    /// (hints can surface even on lower-confidence
    /// classifications that didn't reach .block)。
    public func summariesWithManipulationHints()
        -> [BASCognitiveBrainSummary]
    {
        return summaryHistory.filter {
            !$0.manipulationHints.isEmpty
        }
    }

    /// Count history entries by verdict。 Aggregation
    /// convenience — equivalent to
    /// `summaries(withVerdict:).count` but avoids the
    /// intermediate array allocation。
    public func summaryCount(
        byVerdict verdict: BASCognitiveSafetyVerdict
    ) -> Int {
        return summaryHistory.reduce(0) {
            $0 + ($1.safetyVerdict == verdict ? 1 : 0)
        }
    }

    /// Count history entries by ML task type。 Aggregation
    /// convenience for telemetry dashboards。
    public func summaryCount(
        byTaskType taskType: BASContextTaskType
    ) -> Int {
        return summaryHistory.reduce(0) {
            $0 + ($1.taskType == taskType ? 1 : 0)
        }
    }

}

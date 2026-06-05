// MARK: - BASCognitiveBrain pilot classification · metrics · config · warmup · invariants
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
    /// Full multi-class probability distribution from the
    /// underlying ML classifier。 Returns a map from
    /// taskType to its softmax probability (sums to ~1.0).
    /// Returns nil when the brain was constructed via the
    /// explicit-services init (no ML adapter held)。
    ///
    /// Use this when you need richer routing logic than
    /// the top-1 confidence + taskType pair from
    /// `summary(_:)`。 For example:
    ///   - Detect "ambiguous" inputs where the top-2 are
    ///     within 0.1 of each other
    ///   - Log secondary signals (e.g. P(manipulationRisk)
    ///     > 0.2 even when not the top class)
    ///   - Compute custom thresholds across class subsets
    public func classifyProbabilities(
        _ input: String
    ) -> [BASContextTaskType: Double]? {
        guard let adapter = mlClassifierAdapter else {
            return nil
        }
        let triple = try? adapter.classify(text: input)
        guard let (_, _, logits) = triple else {
            return nil
        }
        // Numerical-stable softmax (subtract max before
        // exp)。 Mirrors BASMLContextService.softmax —
        // same algorithm,inlined to avoid coupling the
        // two surfaces。
        let maxLogit = logits.max() ?? 0
        var exps = [Double]()
        exps.reserveCapacity(logits.count)
        var sum: Double = 0
        for l in logits {
            let e = exp(Double(l - maxLogit))
            exps.append(e)
            sum += e
        }
        guard sum > 0 else { return nil }
        // Map probabilities back to typed taskType enum
        // via the adapter's label order。
        let labels = BASContextClassifierMLAdapter.labels
        var result: [BASContextTaskType: Double] = [:]
        for (i, label) in labels.enumerated() {
            guard i < exps.count else { break }
            let prob = exps[i] / sum
            // Map string label to typed enum。 Unknown
            // labels skipped (defensive — shouldn't
            // happen with the pinned label set)。
            let taskType: BASContextTaskType
            switch label {
            case "chat": taskType = .chat
            case "task": taskType = .task
            case "choice": taskType = .choice
            case "conflict": taskType = .conflict
            case "highPressure": taskType = .highPressure
            case "manipulationRisk":
                taskType = .manipulationRisk
            case "highConsequence":
                taskType = .highConsequence
            default: continue
            }
            result[taskType] = prob
        }
        return result
    }

    /// Pilot wire-up status snapshot — Codable bundle
    /// reporting which of the 5 multi-language pilots
    /// are active on this brain instance。 Hosts use
    /// this for telemetry / adoption dashboards / debug
    /// without needing to introspect each optional
    /// pilot field individually。
    ///
    /// The 5 pilots:
    ///   - C    — always active (built into latency
    ///            measurement;not host-injectable)
    ///   - SQL  — active when sqlHistoryStore != nil
    ///   - C++  — active when cxxSummaryCache != nil
    ///   - Rust — active when rustHistoryStore != nil
    ///   - Metal — active when metalLibraryLoader != nil
    public var pilotStatus: BASCognitiveBrainPilotStatus {
        return BASCognitiveBrainPilotStatus(
            cActive: true,
            sqlActive: sqlHistoryStore != nil,
            cxxActive: cxxSummaryCache != nil,
            rustActive: rustHistoryStore != nil,
            metalActive: metalLibraryLoader != nil)
    }

    /// Operational metrics snapshot — per-pilot record /
    /// cache counts captured at call time。 Hosts use
    /// this for dashboards / health monitoring without
    /// needing to chase the optional pilot fields and
    /// query each backend individually。
    ///
    /// All counts are best-effort: bridge failures (e.g.
    /// Rust core unavailable on a platform missing the
    /// XCFramework slice) surface as 0 rather than
    /// propagating the error。 Hosts that need
    /// distinguishing "0 records" from "bridge failed"
    /// should query each pilot's underlying store
    /// directly。
    public func pilotMetrics() async
        -> BASCognitiveBrainPilotMetrics
    {
        let sqlCount: Int
        if let store = sqlHistoryStore {
            sqlCount = await store.recordCount
        } else { sqlCount = 0 }
        let rustCount: Int
        if let store = rustHistoryStore {
            rustCount = await store.recordCount
        } else { rustCount = 0 }
        let cxxSize: Int
        if let cache = cxxSummaryCache {
            cxxSize = Int(await cache.size())
        } else { cxxSize = 0 }
        return BASCognitiveBrainPilotMetrics(
            sqlRecordCount: sqlCount,
            rustRecordCount: rustCount,
            cxxCacheSize: cxxSize,
            inMemorySummaryCount: summaryHistory.count)
    }

    /// Clear pilot-owned storage in one call。 Affects:
    ///   - In-memory summary history buffer
    ///   - C++ summary cache (process-global!  Other
    ///     brain instances sharing the same bridge
    ///     also lose their cached entries)
    ///   - SQL / Rust stores: NOT cleared (durable
    ///     persistence is intentional;hosts wanting
    ///     to wipe SQL/Rust must call the underlying
    ///     tracker APIs directly)
    ///
    /// Use for session boundaries / testing teardown
    /// where you want to reset the in-process pilot
    /// state without touching durable history。
    public func clearVolatilePilotStorage() async {
        clearSummaryHistory()
        if let cache = cxxSummaryCache {
            try? await cache.clear()
        }
    }

    /// Runtime configuration snapshot — Codable bundle
    /// capturing the brain's construction-time settings。
    /// Use for debug logs / reproducibility / config
    /// regression detection。 Completes the observability
    /// triad with pilotStatus + pilotMetrics:
    ///   - pilotStatus: which pilots are wired
    ///   - pilotMetrics: what each pilot has stored
    ///   - configSnapshot: how the brain was constructed
    public func configSnapshot() async
        -> BASCognitiveBrainConfigSnapshot
    {
        // Cheap snapshot — no cascade run。 We just
        // need the typed init params + pilotStatus。
        // Host goals + no-go zones come from the
        // host-profile service which we don't have a
        // direct reference to。 Hosts wanting them
        // can call `process()` themselves and read
        // result.hostContext。
        return BASCognitiveBrainConfigSnapshot(
            summaryHistoryCapacity: summaryHistoryCapacity,
            safetyConfidenceThreshold:
                instanceSafetyConfidenceThreshold,
            pilotStatus: pilotStatus)
    }

    /// Pre-warm the Metal pilot's MTLLibrary compile —
    /// amortizes the kernel JIT-compile cost so the
    /// first downstream Mamba/SSM inference does NOT
    /// pay it。 No-op when metalLibraryLoader is nil。
    ///
    /// 主线 全面 提升:Metal pilot now has a real
    /// brain-side consumer instead of accessor-only。
    /// Hosts call this at app launch / brain init to
    /// move Metal compile latency off the first user
    /// turn。
    ///
    /// Returns true when the library was compiled (or
    /// already memoized) successfully,false on any
    /// failure (V1 mode,resource missing,compile
    /// error)。 Hosts that need the typed error case
    /// should call `metalLibraryLoader?.library()`
    /// directly。
    @discardableResult
    public func warmMetalKernel() async -> Bool {
        guard let loader = metalLibraryLoader else {
            return false
        }
        return await warmMetalLibrary(loader)
    }

    /// Internal helper splits out the Metal warm so
    /// the optional handling stays in one place。
    private func warmMetalLibrary(
        _ loader: BASMetalKernelLibraryLoader
    ) async -> Bool {
        #if canImport(Metal)
        do {
            _ = try await loader.library()
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    /// 主线 继续 开发 — warmup overload that ALSO runs
    /// the kernel self-test (a tiny B=1,L=1,D=1
    /// dispatch with known inputs,verifying the GPU
    /// returns the expected value within 1e-5)。 Moves
    /// Metal warmup from "compile only" to "compile +
    /// PROVE the kernel actually runs"。
    ///
    /// Returns a typed BASMetalKernelSelfTestResult。
    /// `.skipped` when no loader wired / V1 mode /
    /// non-Apple host。
    public func warmMetalKernelWithSelfTest() async
        -> BASMetalKernelSelfTestResult
    {
        guard let loader = metalLibraryLoader else {
            return BASMetalKernelSelfTestResult(
                status: .skipped,
                reason: "no metalLibraryLoader wired",
                measuredOutput: 0,
                expectedOutput: 1.0)
        }
        return await loader.runKernelSelfTest()
    }

    /// 持续性 发展 — verify cross-pilot invariants and
    /// return a typed report。 Hosts use this in tests
    /// + monitoring to assert that the 5 native pilots
    /// agree on what they've seen,not silently drift。
    ///
    /// **Invariants checked**:
    ///   1. SQL.totalRecords == Rust.totalRecords
    ///      (both stores receive identical
    ///      recordSummary mirror writes per
    ///      recordSummaryObservation)
    ///   2. SQL.distinctSessions == Rust.distinctSessions
    ///      (mirror writes preserve session_ref equally)
    ///   3. SQL.recordsByPermitMode == Rust.recordsByPermitMode
    ///      (mirror writes preserve permit_mode equally)
    ///
    /// **NOT checked** (deliberate):
    ///   - C++ cache size vs SQL total。 The C++ cache is
    ///     PROCESS-GLOBAL — entries from other brain
    ///     instances share the same backing store。 A
    ///     "cxx ≤ history" invariant would be false in
    ///     any multi-instance / multi-test scenario。
    ///     The cxxCacheSize field is still surfaced in
    ///     the report so hosts can inspect,but no
    ///     equality assertion is enforced。
    ///
    /// Pilots that aren't wired are skipped (no
    /// invariant to check)。 Best-effort — query failures
    /// surface as `.unverifiable` cases rather than
    /// throwing。
    public func verifyPilotInvariants() async
        -> BASCognitiveBrainPilotInvariantReport
    {
        var violations: [String] = []
        var checks: [String] = []
        // Pull aggregations from both history pilots if
        // wired
        var sqlTotal: Int? = nil
        var rustTotal: Int? = nil
        var sqlDistinct: Int? = nil
        var rustDistinct: Int? = nil
        var sqlPermit: [String: Int]? = nil
        var rustPermit: [String: Int]? = nil
        var cxxSize: Int? = nil
        if let store = sqlHistoryStore {
            if let agg = try? await store
                .aggregationSnapshot()
            {
                sqlTotal = agg.totalRecords
                sqlDistinct = agg.distinctSessions
                sqlPermit = agg.recordsByPermitMode
            }
        }
        if let store = rustHistoryStore {
            if let agg = try? await store
                .aggregationSnapshot()
            {
                rustTotal = agg.totalRecords
                rustDistinct = agg.distinctSessions
                rustPermit = agg.recordsByPermitMode
            }
        }
        if let cache = cxxSummaryCache {
            cxxSize = Int(await cache.size())
        }
        // Invariant 1: SQL total == Rust total
        if let sqlT = sqlTotal, let rustT = rustTotal {
            checks.append(
                "sql.totalRecords == rust.totalRecords")
            if sqlT != rustT {
                violations.append(
                    "SQL/Rust total drift:" +
                    " sql=\(sqlT) rust=\(rustT)")
            }
        }
        // (C++ cache size deliberately NOT checked vs
        // history — see the doc comment above。 Cache is
        // process-global,history is per-brain。)
        // Invariant 2: distinct sessions equal
        if let sqlD = sqlDistinct, let rustD = rustDistinct {
            checks.append(
                "sql.distinctSessions == " +
                "rust.distinctSessions")
            if sqlD != rustD {
                violations.append(
                    "distinctSessions drift:" +
                    " sql=\(sqlD) rust=\(rustD)")
            }
        }
        // Invariant 3: permit mode distributions equal
        if let sqlP = sqlPermit, let rustP = rustPermit {
            checks.append(
                "sql.recordsByPermitMode == " +
                "rust.recordsByPermitMode")
            if sqlP != rustP {
                violations.append(
                    "permit-mode dist drift:" +
                    " sql=\(sqlP) rust=\(rustP)")
            }
        }
        return BASCognitiveBrainPilotInvariantReport(
            checksRun: checks,
            violations: violations,
            sqlTotalRecords: sqlTotal,
            rustTotalRecords: rustTotal,
            cxxCacheSize: cxxSize,
            collectedAt: Date())
    }

}

import Foundation
import BASRuntimeCore

// P0 经验持久化(RSI 章程 2026-07-07)——"先记住昨天,不改进"。
// 基座此前是"每次重启都失忆的反射机":profiler 表/chainEmaL 全部进程生命期。本文件给
// 解码经验一个版本化、带 staleness 门、防抖、原子写的本地快照。宪法约束:latency-only
// (先验只影响车道选举/K 预热,字节由 ADR-039 锚定)、opt-in(BAS_PROFILER_PERSIST=1,
// 拔掉=字节等价现行为)、本地零遥测、损坏/越界/过期整体拒载=冷启动(现行为)。

/// One decode-experience snapshot on disk (schema v1). Whole-snapshot validity: any
/// out-of-band value rejects the ENTIRE snapshot — a corrupt prior must not partially apply.
public struct BASDecodeExperienceSnapshot: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    /// The catalog model ID the experience was learned on — mismatch ⇒ prior void.
    public let modelID: String
    /// Caller-supplied wall clock (ms) — injected for replay-deterministic tests.
    public let savedAtMs: Int64
    public let cells: [BASAcceptanceProfiler.ExportedCell]
    /// The fused lane's cross-turn regime EMA (decoder-resident, lost on rung-2/process death).
    public let chainEmaL: Double?

    public init(modelID: String, savedAtMs: Int64,
                cells: [BASAcceptanceProfiler.ExportedCell], chainEmaL: Double?) {
        self.schemaVersion = Self.currentSchemaVersion
        self.modelID = modelID
        self.savedAtMs = savedAtMs
        self.cells = cells
        self.chainEmaL = chainEmaL
    }

    /// Sanity bands (mirror B4's clamp philosophy: a corrupt store can't wedge the consumer).
    /// emaHitRate ≤ 1 is the 缝5 unit contract; emaAccepted is per-round (≤ 16 generous);
    /// chainEmaL ∈ [0, 8] (K never exceeds 3, band generous).
    public var isSane: Bool {
        guard schemaVersion == Self.currentSchemaVersion else { return false }
        if let c = chainEmaL, !(c.isFinite && (0.0 ... 8.0).contains(c)) { return false }
        for cell in cells {
            let s = cell.stat
            guard s.emaAccepted.isFinite, (0.0 ... 16.0).contains(s.emaAccepted),
                  s.emaHitRate.isFinite, (0.0 ... 1.0).contains(s.emaHitRate),
                  // 复审修3:上界防溢出 trap(损坏快照 observations=Int.max ⇒ 首次
                  // fold 的 +1 崩进程,违反本文件自己的 can't-wedge 契约)。
                  (0 ... 1_000_000_000).contains(s.observations)
            else { return false }
        }
        return true
    }
}

/// Actor-isolated disk store for `BASDecodeExperienceSnapshot` — atomic writes, debounced,
/// staleness-gated loads. Deletion-averse: a corrupt/stale file is IGNORED, never removed
/// (the next save overwrites atomically).
public actor BASAcceptanceProfilerStore {

    public struct Policy: Sendable {
        /// Snapshots older than this are void (default 7d) — the heat surface/model drift bound.
        public let maxAgeMs: Int64
        /// Minimum spacing between disk writes (default 10s) — decode turns are seconds apart.
        public let debounceMs: Int64
        public init(maxAgeMs: Int64 = 7 * 24 * 3600 * 1000, debounceMs: Int64 = 10_000) {
            self.maxAgeMs = maxAgeMs
            self.debounceMs = debounceMs
        }
    }

    private let url: URL
    private let policy: Policy
    private var lastSaveMs: Int64?

    public init(url: URL, policy: Policy = Policy()) {
        self.url = url
        self.policy = policy
    }

    /// Load the snapshot, or nil (= cold start) on: missing file, unreadable JSON, schema
    /// mismatch, model mismatch, staleness, or any out-of-band value. Never deletes.
    public func load(expectedModelID: String, nowMs: Int64) -> BASDecodeExperienceSnapshot? {
        guard let data = try? Data(contentsOf: url),
              let snap = try? JSONDecoder().decode(BASDecodeExperienceSnapshot.self, from: data)
        else { return nil }
        guard snap.isSane,
              snap.modelID == expectedModelID,
              nowMs >= snap.savedAtMs,
              nowMs - snap.savedAtMs <= policy.maxAgeMs
        else { return nil }
        return snap
    }

    /// Debounced atomic save. `force` bypasses the debounce (e.g. final flush).
    /// Write failures are non-fatal by design (experience is an optimization, never load-bearing).
    public func save(_ snapshot: BASDecodeExperienceSnapshot, nowMs: Int64, force: Bool = false) {
        if !force, let last = lastSaveMs, nowMs - last < policy.debounceMs { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            #if os(iOS)
            // 缝2 卫生对齐:落盘文件带 Data Protection(锁屏后不可读,首解锁后可用——
            // 经验文件在解锁前不会被读:load 只发生在 draft 路径)。
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            #else
            try data.write(to: url, options: .atomic)
            #endif
            lastSaveMs = nowMs
        } catch {
            // Non-fatal: log-and-continue (never let persistence failures touch the decode path).
            BASDiagnosticLog.emit("[experience-store] save failed (non-fatal): \(error)")
        }
    }
}

// MARK: - profiler export/restore (P0)

extension BASAcceptanceProfiler {
    /// One (source × purpose) cell in exportable form. `purpose` is the rawValue string —
    /// forward-compatible: unknown purposes are skipped on restore, never crash.
    public struct ExportedCell: Codable, Sendable, Equatable {
        public let sourceID: String
        public let purpose: String
        public let stat: Stat
        public init(sourceID: String, purpose: String, stat: Stat) {
            self.sourceID = sourceID
            self.purpose = purpose
            self.stat = stat
        }
    }

    /// Deterministically ordered export (sorted by source|purpose) — replayable verdicts need
    /// stable serialization.
    public func exportCells() -> [ExportedCell] {
        allCells()
            .map { ExportedCell(sourceID: $0.sourceID, purpose: $0.purpose, stat: $0.stat) }
            .sorted { ($0.sourceID, $0.purpose) < ($1.sourceID, $1.purpose) }
    }

    /// Lanes whose break-even gate is STICKY BY DESIGN (a gated lane folds no new observations, so
    /// it never self-un-gates) and therefore MUST re-probe cold each session — see
    /// `BASDecodePlanner.swift:89` "a fresh profiler (new session) re-probes". Restoring their cell
    /// verbatim (P0 persistence) would defeat that contract: one sub-break-even measurement would
    /// exile the lane to `.plain` forever across sessions (audit organ-eval MED-4). The warm-start
    /// benefit for these lanes is a single cold probe turn, so dropping them on restore costs nothing
    /// while honoring the planner's per-session re-probe invariant.
    public static let reprobeOnRestoreSourceIDs: Set<String> = [BASDecodeStrategy.mtpSpecSamplingID]

    /// Restore from exported cells. Unknown purpose rawValues (future schema) are skipped, and the
    /// sticky-by-design re-probe lanes (`reprobeOnRestoreSourceIDs`) are dropped so a "new session"
    /// is genuinely cold for them (audit organ-eval MED-4).
    public init(cells: [ExportedCell], alpha: Double = 0.4) {
        var restored = BASAcceptanceProfiler(alpha: alpha)
        for cell in cells
        where BASDecodeLanePolicy.Purpose(rawValue: cell.purpose) != nil
            && !BASAcceptanceProfiler.reprobeOnRestoreSourceIDs.contains(cell.sourceID) {
            restored = restored.inserting(
                sourceID: cell.sourceID, purposeRaw: cell.purpose, stat: cell.stat)
        }
        self = restored
    }
}

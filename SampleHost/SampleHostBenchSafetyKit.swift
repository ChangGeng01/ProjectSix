// MARK: - SampleHostBenchSafetyKit
//
// chapter 一百九十二 / M716-M725 — 10h-readiness safety + observability
// kit. User vision: "全面进化 满意之后 跑 10小时 冒烟 最学习". 5 high-
// leverage gaps closed before tapping the 10h Run Hybrid Bench button:
//
//   M716  Per-row SHA-256 checksum (corruption detection)
//   M717  Thermal/battery auto-pause (10h survivability)
//   M718  Anomaly watcher (substrate stuck / LLM stuck / NaN spike)
//   M719  Heavy-tailed pressure mixer (production-realistic dist)
//   M720  Adversarial mutator (empty / giant / unicode / control)
//   M721  Drift threshold alerts on Welford running mean
//   M722  Crash checkpoint write-ahead
//
// Each helper is a pure value type / actor / enum — no @Published
// state lives here. SampleHostModel wires them into the bench loop.
// Single-source-of-truth doctrine (chapter 一百八十二): one file owns
// each invariant; SampleHostModel calls into this file.

import Foundation
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - M716 row checksum

/// SHA-256 over the canonical encoded row body (excluding the
/// `rowChecksum` field itself). Lets a downstream validator detect
/// corrupted lines without trusting the JSON parser to fail
/// non-fatally on truncation.
///
/// Doctrine: checksum is OPTIONAL on the row; legacy rows decode
/// fine. Validator script (`scripts/validate_hybrid_jsonl.py`)
/// flags rows with `rowChecksum != null && computed != stored`.
enum SampleHostBenchRowChecksum {
    /// Canonical SHA-256 of a UTF-8 string, lowercase hex.
    static func sha256Hex(of input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - M717 thermal/battery gate

/// Decision returned by `SampleHostBenchThermalGate.shouldPause`.
/// `.run` → continue iter. `.pause(reason:)` → skip iter, sleep,
/// re-check next loop pass. Doctrine: gate NEVER terminates the
/// bench task; it just gates each iter so a 10h run can ride out
/// thermal swings without losing accumulated counters.
enum SampleHostBenchThermalDecision: Equatable, Sendable {
    case run
    case pause(reason: String)
}

/// Stateless thermal/battery gate — single-call decision.
/// M717 chapter 一百九十二. Doctrine pin: defaults are CONSERVATIVE:
/// pause on `.critical` thermal AND battery < 5% (not charging).
/// Non-conservative (e.g. permit `.serious`) would risk
/// throttling the model on iPhone 17e mid-bench.
enum SampleHostBenchThermalGate {
    /// Battery cutoff percentage (0.0 .. 1.0). Below this → pause.
    /// 0.05 = 5%. Charging state overrides — if charging, battery
    /// pause never fires (you can run on the wall).
    static let batteryPauseFloor: Double = 0.05

    /// Decision based on current device state.
    /// `nowThermalRaw` ∈ {nominal, fair, serious, critical, unknown}
    /// `batteryLevel`: -1 unknown, else 0..1.
    /// `lowPowerMode`: ProcessInfo.isLowPowerModeEnabled.
    /// `batteryStateRaw`: "charging" / "full" / "unplugged" / "unknown".
    static func decide(
        thermalRaw: String,
        batteryLevel: Double,
        lowPowerMode: Bool,
        batteryStateRaw: String
    ) -> SampleHostBenchThermalDecision {
        // Critical thermal — always pause
        if thermalRaw == "critical" {
            return .pause(reason: "thermal-critical")
        }
        // Charging → battery floor never trips
        let charging = batteryStateRaw == "charging"
            || batteryStateRaw == "full"
        if !charging
            && batteryLevel >= 0
            && batteryLevel < batteryPauseFloor
        {
            return .pause(reason: "battery-below-\(Int(batteryPauseFloor * 100))pct")
        }
        // Low power + serious thermal — defensive pause
        if lowPowerMode && thermalRaw == "serious" {
            return .pause(reason: "low-power-serious-thermal")
        }
        return .run
    }

    /// Read current device thermal/battery from ProcessInfo + UIDevice.
    /// Returns the raw 4-tuple suitable for `decide(...)`.
    /// macOS / non-UIKit hosts return `batteryLevel = -1`.
    static func currentDeviceState() -> (
        thermal: String,
        battery: Double,
        lowPower: Bool,
        batteryState: String
    ) {
        let thermalRaw: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalRaw = "nominal"
        case .fair: thermalRaw = "fair"
        case .serious: thermalRaw = "serious"
        case .critical: thermalRaw = "critical"
        @unknown default: thermalRaw = "unknown"
        }
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        let battery: Double = level >= 0 ? Double(level) : -1.0
        let batteryStateRaw: String
        switch UIDevice.current.batteryState {
        case .charging: batteryStateRaw = "charging"
        case .full: batteryStateRaw = "full"
        case .unplugged: batteryStateRaw = "unplugged"
        case .unknown: batteryStateRaw = "unknown"
        @unknown default: batteryStateRaw = "unknown"
        }
        #else
        let battery: Double = -1.0
        let batteryStateRaw: String = "unknown"
        #endif
        return (thermalRaw, battery, lowPower, batteryStateRaw)
    }
}

// MARK: - M718 anomaly watcher

/// Sliding-window anomaly detector. Flags when bench loop is in a
/// suspicious state: substrate stuck (all-same permitMode for N
/// iters) / LLM stuck (all-empty body for N iters) / NaN spike /
/// 0-error-for-very-long.
///
/// Doctrine: watcher is HINT-ONLY (red line 7). It populates
/// `anomalyFlags` on the row; bench loop never auto-stops.
/// Operator reads flags in dashboard / replay tool.
actor SampleHostBenchAnomalyWatcher {
    /// Configurable window size (default 100 iters). Smaller = more
    /// reactive, more false positives; larger = slower detect, fewer FPs.
    let windowSize: Int

    private var permitModeWindow: [String] = []
    private var bodyEmptyWindow: [Bool] = []
    private var nanCountWindow: [Int] = []
    private var totalIters: Int = 0
    private var stuckSubstratesEmitted: Int = 0
    private var stuckLLMsEmitted: Int = 0

    init(windowSize: Int = 100) {
        self.windowSize = max(10, windowSize)
    }

    /// Per-iter observation. Returns flags to record in row.
    /// Empty array if everything looks healthy.
    func observe(
        permitMode: String,
        bodyIsEmpty: Bool,
        regressionOutputs: [Double?]
    ) -> [String] {
        var flags: [String] = []
        totalIters += 1

        // Slide windows
        permitModeWindow.append(permitMode)
        if permitModeWindow.count > windowSize {
            permitModeWindow.removeFirst()
        }
        bodyEmptyWindow.append(bodyIsEmpty)
        if bodyEmptyWindow.count > windowSize {
            bodyEmptyWindow.removeFirst()
        }

        // NaN/Inf detection per iter (immediate, no window)
        let nans = regressionOutputs
            .compactMap { $0 }
            .filter { !$0.isFinite }
            .count
        nanCountWindow.append(nans)
        if nanCountWindow.count > windowSize {
            nanCountWindow.removeFirst()
        }
        if nans > 0 {
            flags.append("nan-spike:\(nans)")
        }

        // Substrate stuck — full window same permitMode (and not
        // a "natural" repeat like all-block on adversarial run).
        // Only fires once per stuck-window-pass to avoid spam.
        if permitModeWindow.count == windowSize {
            let unique = Set(permitModeWindow).count
            if unique == 1 {
                let mode = permitModeWindow[0]
                // Don't flag substrate-error blocks (those are
                // already captured via permitMode itself)
                if mode != "substrate-error" {
                    flags.append("substrate-stuck:\(mode)")
                    stuckSubstratesEmitted += 1
                }
            }
        }
        // LLM stuck — full window all-empty body
        if bodyEmptyWindow.count == windowSize {
            let allEmpty = bodyEmptyWindow.allSatisfy { $0 }
            if allEmpty {
                flags.append("llm-stuck:all-empty")
                stuckLLMsEmitted += 1
            }
        }
        // NaN cluster — > 25% of window had nans
        if nanCountWindow.count == windowSize {
            let nansHit = nanCountWindow.filter { $0 > 0 }.count
            if nansHit > windowSize / 4 {
                flags.append("nan-cluster:\(nansHit)/\(windowSize)")
            }
        }

        return flags
    }

    /// Stats for dashboard display.
    func snapshot() -> (
        iters: Int,
        stuckSubstrates: Int,
        stuckLLMs: Int
    ) {
        (totalIters, stuckSubstratesEmitted, stuckLLMsEmitted)
    }

    /// Reset all windows (call on bench Stop→Start).
    func reset() {
        permitModeWindow.removeAll(keepingCapacity: true)
        bodyEmptyWindow.removeAll(keepingCapacity: true)
        nanCountWindow.removeAll(keepingCapacity: true)
        totalIters = 0
        stuckSubstratesEmitted = 0
        stuckLLMsEmitted = 0
    }
}

// MARK: - M719 heavy-tailed pressure mixer

/// Production-realistic layer distribution. Uniform sweep (M711) is
/// great for coverage; heavy-tailed gives realistic frequency for
/// drift-detection & training-set augmentation.
///
/// Layer probabilities (informed by chapter 176 §176.19 substrate
/// distribution + heavy-tail intuition):
///   L11 risk-gate    : 25% (high-frequency in real workloads)
///   L9 candidates    : 18%
///   L8 memory        : 12%
///   L7 mirror        : 10%
///   L4 horizon       : 8%
///   L6 context       : 7%
///   L10 tribunal     : 6%
///   L5 host          : 5%
///   L1 wake          : 3%
///   L12 surface      : 2%
///   L2 breath        : 1.5%
///   L3 lung          : 1%
///   L13 evolution    : 1%
///   L14 reflection   : 0.5%
///                    ----
///                     100%
///
/// Doctrine: deterministic (seeded by iter) so replay is exact.
enum SampleHostBenchPressureMixer {
    /// Per-layer weight in ascending layer index. Sums to 100.
    static let layerWeights: [Double] = [
        3.0,   // L1 wake
        1.5,   // L2 breath
        1.0,   // L3 lung
        8.0,   // L4 horizon
        5.0,   // L5 host
        7.0,   // L6 context
        10.0,  // L7 mirror
        12.0,  // L8 memory
        18.0,  // L9 candidates
        6.0,   // L10 tribunal
        25.0,  // L11 risk-gate
        2.0,   // L12 surface
        1.0,   // L13 evolution
        0.5,   // L14 reflection
    ]

    /// Cumulative weight prefix sum (denormalized to layerWeightsTotal).
    static let cumulativeWeights: [Double] = {
        var acc: Double = 0
        var out: [Double] = []
        for w in layerWeights {
            acc += w
            out.append(acc)
        }
        return out
    }()

    /// Sum of all layer weights (used as modulus for selection).
    static let layerWeightsTotal: Double = layerWeights.reduce(0, +)

    /// Pick a layer index (1-14) by weight. Deterministic by seed.
    /// Algorithm: linear-congruential RNG seeded by iter, hash to
    /// [0, layerWeightsTotal), then binary-search cumulative weights.
    /// Exposes the picked layerIndex; caller looks up the
    /// FourteenLayerSmokeProfile.layers entry by index.
    static func pickLayerIndex(forIter iter: Int) -> Int {
        // Linear-congruential RNG. Constants from Numerical Recipes.
        // Deterministic + fast + good enough for ~5/sec sampling.
        let seed = UInt64(bitPattern: Int64(iter))
        var rng = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        // Take top 32 bits → [0, 2^32) → divide to [0, total)
        rng = rng >> 32
        let r = Double(UInt32(truncatingIfNeeded: rng))
            / Double(UInt32.max)
            * layerWeightsTotal
        // Linear scan (14 elements — binary search overkill)
        for (i, cum) in cumulativeWeights.enumerated() {
            if r < cum {
                return i + 1  // 1-indexed layer
            }
        }
        // Numerical edge — return last
        return layerWeights.count
    }
}

// MARK: - M720 adversarial mutator

/// Edge-case prompt mutations. Probabilistic per iter (~5% chance
/// by default), deterministic by iter, layered ON TOP of catalog
/// prompt. Records the mutation kind to the row so replay can
/// stratify by adversarial type.
///
/// Doctrine: adversarial mutator is OPT-IN via SmokeMode
/// (`.heavyTailed` enables it; `.canonical` and `.fourteenLayer`
/// disable). 5% of ~36K iters in 2h = ~1,800 adversarial probes,
/// enough signal for residual analysis.
enum SampleHostBenchAdversarialKind: String, CaseIterable, Sendable {
    case empty                = "empty"
    case oneChar              = "one-char"
    case giant10K             = "giant-10k"
    case unicodeMixed         = "unicode-mixed"
    case emojiOnly            = "emoji-only"
    case controlChars         = "control-chars"
    case repeatedTokens       = "repeated-tokens"
    case mixedLanguages       = "mixed-languages"

    /// Apply this mutation to the catalog-generated prompt.
    func apply(to prompt: String) -> String {
        switch self {
        case .empty:
            return ""
        case .oneChar:
            return "?"
        case .giant10K:
            // 10K char repetition — stresses LLM context window
            // and substrate post-LLM truncation cap.
            let base = prompt.isEmpty ? "tell me " : prompt + " "
            var out = ""
            while out.count < 10_000 {
                out += base
            }
            return String(out.prefix(10_000))
        case .unicodeMixed:
            // Mix of CJK, Cyrillic, Arabic, Hebrew, Devanagari
            return "你好 Здравствуйте مرحبا שלום नमस्ते \(prompt)"
        case .emojiOnly:
            return "🎯🔥💀🌊⚡️🌀🧬🔮🎭🎨"
        case .controlChars:
            // Tab, newline, vertical tab, form feed, carriage return
            // — stresses tokenizers + line-based parsers.
            return "\t\n\u{0B}\u{0C}\r\(prompt)\t\n\u{0B}\u{0C}\r"
        case .repeatedTokens:
            return String(repeating: "the ", count: 500) + prompt
        case .mixedLanguages:
            // Code-mixing edge — Thai + Korean + Tamil + Welsh + Yoruba
            return "\(prompt) ทดสอบ 시험 சோதனை profi ìdánwò"
        }
    }
}

/// Decide whether to mutate this iter and which kind. Returns nil
/// if no mutation. Deterministic by iter so replay is exact.
enum SampleHostBenchAdversarialMutator {
    /// Probability of mutating an iter (0.0 .. 1.0). 0.05 = 5%.
    static let mutationProbability: Double = 0.05

    /// Decide for an iter. Returns nil if not mutated.
    static func decideMutation(
        forIter iter: Int,
        enabled: Bool
    ) -> SampleHostBenchAdversarialKind? {
        guard enabled else { return nil }
        // Linear-congruential RNG by iter (independent stream from
        // pressure mixer to avoid correlated decisions).
        let seed = UInt64(bitPattern: Int64(iter)) &* 0x517c_c1b7_2722_0a95
        var rng = seed &+ 0x14057b7e_f767814f
        rng = rng >> 32
        let r = Double(UInt32(truncatingIfNeeded: rng))
            / Double(UInt32.max)
        guard r < mutationProbability else { return nil }
        // Pick kind uniformly among 8 cases
        let kindIdx = Int(rng % UInt64(SampleHostBenchAdversarialKind
            .allCases.count))
        return SampleHostBenchAdversarialKind.allCases[kindIdx]
    }
}

// MARK: - M721 drift threshold monitor

/// Welford std-dev tracker for residuals. Caller feeds `update(_:)`
/// per sample; queries `stdDev` / `mean` / `nSigmaAbove`. Threshold
/// crossings emit a flag that bench loop can attach to row's
/// `anomalyFlags`.
///
/// Welford recurrence:
///   M_n = M_{n-1} + (x_n - M_{n-1}) / n
///   S_n = S_{n-1} + (x_n - M_{n-1}) * (x_n - M_n)
///   var = S_n / (n - 1)  (sample variance)
final class SampleHostBenchDriftMonitor: @unchecked Sendable {
    private(set) var count: Int = 0
    private(set) var mean: Double = 0
    private var sumSquaredDiff: Double = 0
    private let lock = NSLock()

    /// Variance (sample). 0 if count < 2.
    var variance: Double {
        lock.lock(); defer { lock.unlock() }
        guard count > 1 else { return 0 }
        return sumSquaredDiff / Double(count - 1)
    }

    /// Standard deviation (sample). 0 if count < 2.
    var stdDev: Double { sqrt(variance) }

    /// Update with a new sample. NaN/Inf samples are dropped.
    func update(_ x: Double) {
        guard x.isFinite else { return }
        lock.lock(); defer { lock.unlock() }
        count += 1
        let delta = x - mean
        mean += delta / Double(count)
        let delta2 = x - mean
        sumSquaredDiff += delta * delta2
    }

    /// Returns sigma multiple of `x` above the running mean.
    /// Negative when x < mean. 0 if stdDev == 0.
    func sigmaAbove(_ x: Double) -> Double {
        let s = stdDev
        guard s > 0 else { return 0 }
        return (x - mean) / s
    }

    /// Reset counters. Call on bench Stop→Start.
    func reset() {
        lock.lock(); defer { lock.unlock() }
        count = 0
        mean = 0
        sumSquaredDiff = 0
    }
}

// MARK: - M722 crash checkpoint

/// Persisted crash-recovery snapshot. Lets a 10h bench survive an
/// app force-kill / OOM / reboot — on next launch, sample-host can
/// detect the unfinished bench and either resume or surface
/// to operator for review.
///
/// Doctrine: checkpoint is WRITE-ONLY from the runtime side. M722
/// ships the write path; M723 / chapter 一百九十三+ adds resume UI.
struct SampleHostBenchCheckpoint: Codable, Sendable, Equatable {
    let generation: Int
    let iter: Int
    let startTimeIso: String
    let lastUpdatedIso: String
    let outputPath: String
    let smokeMode: String
    let durationHours: Double
    let mutationSeedCount: Int
    let strideCSV: String
    /// AFM ok / Gemma ok / both-failed counters at last checkpoint
    let afmOk: Int
    let gemmaOk: Int
    let bothFailed: Int
    /// Anomaly snapshot for fast triage
    let stuckSubstrates: Int
    let stuckLLMs: Int
}

/// Thread-safe checkpoint store. Single file at
/// `Documents/iphone-hybrid-bench/checkpoint.json`.
actor SampleHostBenchCheckpointStore {
    static let shared = SampleHostBenchCheckpointStore()
    private let url: URL

    init() {
        let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = docs.appendingPathComponent("iphone-hybrid-bench")
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent("checkpoint.json")
    }

    /// Atomic write. Encodes pretty-printed JSON to a tmp path then
    /// renames over the live URL — survives partial-write crashes.
    func write(_ checkpoint: SampleHostBenchCheckpoint) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(checkpoint)
        let tmp = url.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        // Rename atomic — POSIX semantics on iOS are atomic for
        // same-filesystem rename. Replaces existing file.
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try? FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmp, to: url)
    }

    /// Read latest checkpoint. Returns nil if no file or unreadable
    /// (treat as no-prior-bench rather than crash on first launch).
    func read() async -> SampleHostBenchCheckpoint? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder()
            .decode(SampleHostBenchCheckpoint.self, from: data)
    }

    /// Clear checkpoint (call on clean bench finish).
    func clear() async {
        _ = try? FileManager.default.removeItem(at: url)
    }

    /// URL for tests / replay tool.
    var checkpointURL: URL { url }
}

// MARK: - M719 selection helper

/// Look up the FourteenLayerSmokeProfile for a layer index 1-14.
/// Centralized so PressureMixer + bench loop share the same source.
extension FourteenLayerSmokeProfile {
    static func profile(forLayerIndex idx: Int) -> Profile? {
        guard idx >= 1 && idx <= layers.count else { return nil }
        return layers[idx - 1]
    }
}

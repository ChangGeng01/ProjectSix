import Foundation

// P1 判决对象类型化(RSI 章程 2026-07-07)——把三个互不相连的判决表示(战役散文判据 /
// build_verdict rows / EvaluationCore Codable)统一为一个可执行类型。宪法界:这是判决的
// 【执行】代码化;判决的【设计】(预注册)与对判决器的【怀疑】(逐行核对)永在人手。
// 判决器输出的是"判决候选"——采纳签字不在这里。
//
// 验收(预注册):历史战役回放——cacheLimit 设备日志必须复现 512/768/∞ PARITY + 256 的
// 位置伪影否决;v1 Mac 日志必须复现 fidelity 仪器失效。任一分歧 = 对象错,不是历史错。

/// The pre-registered A/B protocol — freeze BEFORE measuring (the object carries the criteria
/// the campaign prose used to). Mirrors the cacheLimit campaign's criteria 1-7.
public struct BASABProtocolSpec: Codable, Sendable, Equatable {
    /// Arm tags in block-0 order (block 1 is the mirror when `mirroredBlocks`).
    public let arms: [String]
    /// The incumbent arm deltas are judged against.
    public let incumbentArm: String
    public let mirroredBlocks: Bool
    public let warmupPerArmBlock: Int
    public let measuredPerArmBlock: Int
    /// |Δ| ≤ band ⇒ parity (percent, e.g. 3.0).
    public let parityBandPct: Double
    /// Real effect additionally requires same-sign > band in BOTH blocks independently —
    /// the position-artifact veto (the rule that killed b0/256's cold-burst "win").
    public let twoBlockSameSignRule: Bool
    /// Byte-anchor requirement: any prompt with >1 distinct output across rows ⇒ instrument invalid.
    public let fidelityAnchorRequired: Bool
    /// Max thermal-tier delta between an arm's two blocks before cross-block pooling is void.
    public let thermalConfoundTierDelta: Int
    /// Minimum measured rows per arm for a verdict (below ⇒ DNF).
    public let minMeasuredRowsPerArm: Int

    public init(arms: [String], incumbentArm: String, mirroredBlocks: Bool = true,
                warmupPerArmBlock: Int = 1, measuredPerArmBlock: Int = 6,
                parityBandPct: Double = 3.0, twoBlockSameSignRule: Bool = true,
                fidelityAnchorRequired: Bool = true, thermalConfoundTierDelta: Int = 2,
                minMeasuredRowsPerArm: Int = 8) {
        self.arms = arms
        self.incumbentArm = incumbentArm
        self.mirroredBlocks = mirroredBlocks
        self.warmupPerArmBlock = warmupPerArmBlock
        self.measuredPerArmBlock = measuredPerArmBlock
        self.parityBandPct = parityBandPct
        self.twoBlockSameSignRule = twoBlockSameSignRule
        self.fidelityAnchorRequired = fidelityAnchorRequired
        self.thermalConfoundTierDelta = thermalConfoundTierDelta
        self.minMeasuredRowsPerArm = minMeasuredRowsPerArm
    }
}

/// One measurement row (one generation). `tokHash` nil when the harness computed fidelity
/// itself (the judge then consumes `externalFidelityMismatches`).
public struct BASABMeasurementRow: Codable, Sendable, Equatable {
    public let block: Int
    public let arm: String
    public let gen: Int
    public let prompt: Int
    public let tokens: Int
    public let seconds: Double
    public let thermal: Int
    public let measured: Bool
    public let tokHash: Int?
    public let aborted: Bool

    public init(block: Int, arm: String, gen: Int, prompt: Int, tokens: Int, seconds: Double,
                thermal: Int, measured: Bool, tokHash: Int? = nil, aborted: Bool = false) {
        self.block = block
        self.arm = arm
        self.gen = gen
        self.prompt = prompt
        self.tokens = tokens
        self.seconds = seconds
        self.thermal = thermal
        self.measured = measured
        self.tokHash = tokHash
        self.aborted = aborted
    }
}

/// Per-arm finding — the verdict CANDIDATE (adoption stays human).
public struct BASABArmFinding: Codable, Sendable, Equatable {
    public enum Finding: String, Codable, Sendable {
        case parity            // |Δ pooled| ≤ band
        case realEffect        // > band, same sign in BOTH blocks (when the rule is armed)
        case artifactSuspect   // pooled > band but blocks disagree — position-artifact veto
        case thermalConfounded // cross-block pooling void (tier delta ≥ spec threshold)
        case dnf               // aborted / below row quorum
        case incumbent
    }
    public let arm: String
    public let pooledTps: Double
    public let blockTps: [Int: Double]
    public let deltaVsIncumbentPct: Double?
    public let blockDeltaPcts: [Int: Double]
    public let finding: Finding
}

/// The typed verdict report — replayable, append-only-loggable.
public struct BASABReport: Codable, Sendable, Equatable {
    public enum Overall: String, Codable, Sendable {
        case pass              // instrument valid, all arms judged
        case instrumentInvalid // fidelity anchor failed — verdict void, fix the harness first
        case dnf               // quorum failures dominate
    }
    public let overall: Overall
    public let fidelityMismatches: Int
    /// audit organ-eval MED-2: whether the fidelity anchor had COMPARABLE DATA
    /// (an external count OR ≥1 row with a tokHash). `false` ⇒ `fidelityMismatches
    /// == 0` means "nothing to compare", NOT "verified clean" — the anchor was
    /// never actually applied. Consumers that require fidelity must treat `false`
    /// as unverified rather than a silent pass.
    public let fidelityVerifiable: Bool
    public let arms: [BASABArmFinding]

    public init(overall: Overall, fidelityMismatches: Int,
                fidelityVerifiable: Bool = true, arms: [BASABArmFinding]) {
        self.overall = overall
        self.fidelityMismatches = fidelityMismatches
        self.fidelityVerifiable = fidelityVerifiable
        self.arms = arms
    }

    // Byte-stable decode — a report logged before the field decodes as
    // fidelityVerifiable = true (those came from real runs with token hashes).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        overall = try c.decode(Overall.self, forKey: .overall)
        fidelityMismatches = try c.decode(Int.self, forKey: .fidelityMismatches)
        fidelityVerifiable = try c.decodeIfPresent(Bool.self, forKey: .fidelityVerifiable) ?? true
        arms = try c.decode([BASABArmFinding].self, forKey: .arms)
    }
}

public enum BASABJudge {

    /// Execute the pre-registered criteria on the rows. Pure; deterministic; no adoption power.
    public static func judge(
        spec: BASABProtocolSpec, rows: [BASABMeasurementRow],
        externalFidelityMismatches: Int? = nil
    ) -> BASABReport {
        // ── 判据 1: fidelity anchor ───────────────────────────────────────────
        // audit organ-eval MED-2: `mismatches == 0` is AMBIGUOUS — it means
        // "verified clean" when there is comparable data, but "nothing to compare"
        // when no external count is given and no row carries a tokHash. The old
        // code read both as a silent PASS. The report now records
        // `fidelityVerifiable` so a consumer can tell a real clean pass from an
        // unverified one (the anchor is no longer SILENTLY bypassed). A stricter
        // verdict-level fail-closed is deferred: judge() has no production caller
        // yet, and it would require reworking the synthetic-row test suite (which
        // deliberately omits tokHash to exercise the OTHER criteria in isolation).
        let mismatches = externalFidelityMismatches ?? Self.fidelityMismatches(rows: rows)
        let fidelityVerifiable =
            externalFidelityMismatches != nil || Self.fidelityVerifiable(rows: rows)
        if spec.fidelityAnchorRequired, mismatches > 0 {
            return BASABReport(overall: .instrumentInvalid,
                               fidelityMismatches: mismatches,
                               fidelityVerifiable: fidelityVerifiable, arms: [])
        }

        // ── per-arm pooled + per-block tok/s ─────────────────────────────────
        func pooledTps(_ sel: [BASABMeasurementRow]) -> Double {
            let t = sel.reduce(0) { $0 + $1.tokens }
            let s = sel.reduce(0.0) { $0 + $1.seconds }
            return s > 0 ? Double(t) / s : 0
        }
        var perArm: [String: (pooled: Double, blocks: [Int: Double], maxTier: [Int: Int], measured: Int, aborted: Bool)] = [:]
        for arm in spec.arms {
            let armRows = rows.filter { $0.arm == arm }
            let m = armRows.filter(\.measured)
            var blocks: [Int: Double] = [:]
            var tiers: [Int: Int] = [:]
            for b in Set(m.map(\.block)) {
                let bm = m.filter { $0.block == b }
                blocks[b] = pooledTps(bm)
                tiers[b] = bm.map(\.thermal).max() ?? 0
            }
            perArm[arm] = (pooledTps(m), blocks, tiers,
                           m.count, armRows.contains(where: \.aborted))
        }
        // 复审修7:在位臂自身必须过 quorum/aborted/热闸——坏基线(冷启 burst 分母/
        // 降频分母)会把全场候选判成假 parity/假 realEffect。基线不可用 ⇒ 整报告 DNF。
        guard let incumbent = perArm[spec.incumbentArm], incumbent.pooled > 0,
              !incumbent.aborted,
              incumbent.measured >= spec.minMeasuredRowsPerArm,
              Self.tierSpread(incumbent.maxTier) < spec.thermalConfoundTierDelta
        else {
            return BASABReport(overall: .dnf, fidelityMismatches: mismatches,
                               fidelityVerifiable: fidelityVerifiable, arms: [])
        }

        // ── 判据 3/5/6: parity band + two-block same-sign + thermal confound ──
        var findings: [BASABArmFinding] = []
        var dnfCount = 0
        for arm in spec.arms {
            guard let a = perArm[arm] else { continue }
            let deltaPct = (a.pooled / incumbent.pooled - 1) * 100
            var blockDeltas: [Int: Double] = [:]
            for (b, tps) in a.blocks {
                if let itps = incumbent.blocks[b], itps > 0 {
                    blockDeltas[b] = (tps / itps - 1) * 100
                }
            }
            let finding: BASABArmFinding.Finding
            if arm == spec.incumbentArm {
                finding = .incumbent
            } else if a.aborted || a.measured < spec.minMeasuredRowsPerArm {
                finding = .dnf
                dnfCount += 1
            } else if Self.tierSpread(a.maxTier) >= spec.thermalConfoundTierDelta {
                // 复审修8:块索引不点名 0/1(三块/非零起始设计下静默跳检)——取全块 max−min。
                finding = .thermalConfounded
            } else if abs(deltaPct) <= spec.parityBandPct {
                finding = .parity
            } else if spec.twoBlockSameSignRule {
                let over = blockDeltas.values.filter { abs($0) > spec.parityBandPct }
                let sameSign = blockDeltas.count >= 2
                    && over.count == blockDeltas.count
                    && Set(blockDeltas.values.map { $0 > 0 }).count == 1
                finding = sameSign ? .realEffect : .artifactSuspect
            } else {
                finding = .realEffect
            }
            findings.append(BASABArmFinding(
                arm: arm, pooledTps: a.pooled, blockTps: a.blocks,
                deltaVsIncumbentPct: arm == spec.incumbentArm ? nil : deltaPct,
                blockDeltaPcts: blockDeltas, finding: finding))
        }
        let overall: BASABReport.Overall =
            dnfCount >= max(1, spec.arms.count - 1) ? .dnf : .pass
        return BASABReport(overall: overall, fidelityMismatches: mismatches,
                           fidelityVerifiable: fidelityVerifiable, arms: findings)
    }

    /// Max−min thermal tier across an arm's blocks (0 when <2 blocks carry data).
    static func tierSpread(_ tiers: [Int: Int]) -> Int {
        guard tiers.count >= 2, let lo = tiers.values.min(), let hi = tiers.values.max()
        else { return 0 }
        return hi - lo
    }

    /// Row-level fidelity: per prompt, all rows (warmup included) must agree on tokHash.
    public static func fidelityMismatches(rows: [BASABMeasurementRow]) -> Int {
        var mismatches = 0
        let hashed = rows.filter { $0.tokHash != nil }
        for p in Set(hashed.map(\.prompt)) {
            if Set(hashed.filter { $0.prompt == p }.compactMap(\.tokHash)).count > 1 {
                mismatches += 1
            }
        }
        return mismatches
    }

    /// audit organ-eval MED-2: whether the fidelity anchor is VERIFIABLE from
    /// these rows (at least one carries a tokHash). Distinguishes "0 mismatches =
    /// verified clean" from "0 = no comparable data", so a REQUIRED anchor can't
    /// be silently satisfied by absence.
    public static func fidelityVerifiable(rows: [BASABMeasurementRow]) -> Bool {
        rows.contains { $0.tokHash != nil }
    }
}

/// Format-specific adapter: the cacheLimit harness's `[climit]` log lines → typed rows.
/// (Log adapters live at the edge; the judge only ever sees typed rows.)
public enum BASClimitLogParser {

    /// Parse `[climit] b=0 arm=256 g=1 p=1 tok=192 tok/s=20.7 … thermal=0 …( (warmup))?` rows,
    /// plus the harness-computed `FIDELITY-FAIL prompt=N` count, `ABORT` lines (mark the arm's
    /// last row aborted so the judge's DNF rule is reachable through this adapter), and a
    /// `skipped` count — 复审修9:坏行(tok/s≤0/缺字段)绝不静默消失(最慢行消失 =
    /// 臂均值向快偏),调用方必须核对 skipped==0 或注记。
    public static func parse(
        log: String
    ) -> (rows: [BASABMeasurementRow], fidelityMismatches: Int, skipped: Int) {
        var rows: [BASABMeasurementRow] = []
        var fidelityFails = 0
        var skipped = 0
        var abortKeys: [(arm: String, block: Int)] = []
        for line in log.split(separator: "\n") {
            if line.contains("[climit] FIDELITY-FAIL prompt=") { fidelityFails += 1; continue }
            if line.contains("[climit] ABORT arm=") {
                var f: [String: String] = [:]
                for tok in line.split(separator: " ") {
                    if let eq = tok.firstIndex(of: "=") {
                        f[String(tok[..<eq])] = String(tok[tok.index(after: eq)...])
                    }
                }
                if let arm = f["arm"], let b = f["b"].flatMap({ Int($0) }) {
                    abortKeys.append((arm, b))
                }
                continue
            }
            guard line.contains("[climit] b=") else { continue }
            var fields: [String: String] = [:]
            for tokenSub in line.split(separator: " ") {
                let token = String(tokenSub)
                if let eq = token.firstIndex(of: "=") {
                    fields[String(token[..<eq])] = String(token[token.index(after: eq)...])
                }
            }
            guard let b = fields["b"].flatMap({ Int($0) }),
                  let arm = fields["arm"],
                  let g = fields["g"].flatMap({ Int($0) }),
                  let p = fields["p"].flatMap({ Int($0) }),
                  let tok = fields["tok"].flatMap({ Int($0) }),
                  let tps = fields["tok/s"].flatMap({ Double($0) }), tps > 0,
                  let thermal = fields["thermal"].flatMap({ Int($0) })
            else { skipped += 1; continue }
            rows.append(BASABMeasurementRow(
                block: b, arm: arm, gen: g, prompt: p, tokens: tok,
                seconds: Double(tok) / tps, thermal: thermal,
                measured: !line.contains("(warmup)")))
        }
        for key in abortKeys {
            if let idx = rows.lastIndex(where: { $0.arm == key.arm && $0.block == key.block }) {
                let r = rows[idx]
                rows[idx] = BASABMeasurementRow(
                    block: r.block, arm: r.arm, gen: r.gen, prompt: r.prompt, tokens: r.tokens,
                    seconds: r.seconds, thermal: r.thermal, measured: r.measured,
                    tokHash: r.tokHash, aborted: true)
            }
        }
        return (rows, fidelityFails, skipped)
    }
}

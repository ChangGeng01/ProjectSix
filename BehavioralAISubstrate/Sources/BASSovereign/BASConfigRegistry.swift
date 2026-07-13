import Foundation

// P2 生产开关只读注册表(RSI 章程 2026-07-07)——kill-switch 宇宙首次可枚举。
// 宪法条款(不建清单#7):【明文禁运行时写】——kill-switch 的安全语义依赖它在任何
// 自动化环路的写域之外(手动 env + 进程重启);开关运行时可写化 = 给自改进环造后门,
// 包括翻掉自己 kill-switch 的那个。本注册表是只读的【描述】,不是控制面。
// 来源:RSI 审计读者3 的全仓 census(239 个 BAS_* 字面量中的生产解码栈真开关)。

/// One production switch, described — never actuated.
public struct BASProductionSwitch: Sendable, Equatable {
    public enum Polarity: String, Sendable {
        case defaultOnKill   // 默认开;env 设 0(或 *_OFF=1)关 —— ADR-014 毕业态
        case optIn           // 默认关;env 设 1 开
        case constantKnob    // 数值常数覆盖
    }
    public let envName: String
    public let polarity: Polarity
    public let owner: String            // file:line 锚(census 时点)
    public let what: String             // 一句话:控什么
    public let adrRef: String?          // 采纳出处(ADR/账本)
}

public enum BASConfigRegistry {

    /// The production switch census (2026-07-07; widened repo-wide 2026-07-13). Append-only by
    /// convention: a NEW production default-on switch must land here in the same commit. The
    /// completeness of the default-on class is CI-asserted (both directions) by
    /// `BASImprovementCandidateTests.testRegistryCoversDefaultOnSwitchesInSource`, which greps
    /// all of Sources for the three default-on signatures (`!= "0"`, `_OFF ==/!= "1"`, and the
    /// skip-style `BAS_SKIP_* != "1"`). (The earlier comment named a `BASConfigRegistryTests`
    /// file that never existed.)
    public static let switches: [BASProductionSwitch] = [
        // ── 默认开 + kill-switch(ADR-014 毕业态)──────────────────────────────
        .init(envName: "BAS_SESSION_CAPPED_FUSED", polarity: .defaultOnKill,
              owner: "MLXOrganAdapter.swift:1422",
              what: "capped-fused MTP 会话车道(≤384 cap 会话轮走 fused 链)",
              adrRef: "FRONTIER_2026H2 + DECODE_OS_AUDIT 设备认证 07-06"),
        .init(envName: "BAS_SESSION_SPILL", polarity: .defaultOnKill,
              owner: "MLXOrganAdapter.swift:1474",
              what: "B5 KV spill 落盘(LRU 逐出→磁盘快照,endurance 67轮12/12)",
              adrRef: "FRONTIER_2026H2_EVOLUTION B5"),
        .init(envName: "BAS_TRACE_EXIT_OFF", polarity: .defaultOnKill,
              owner: "MLXOrganAdapter+MTPSpec.swift:221-238",
              what: "B3 trace-exit(capped 轮自动武装的熵早退;OFF=1 杀)",
              adrRef: "FRONTIER_2026H2_EVOLUTION B3"),
        .init(envName: "BAS_DIFF_PROBE_OFF", polarity: .defaultOnKill,
              owner: "MLXOrganAdapter+MTPSpec.swift:289-290",
              what: "B2 难度探针(capped 轮武装,v2 权重 AUC 0.817;OFF=1 杀)",
              adrRef: "FRONTIER_2026H2_EVOLUTION B2 (probe v2)"),
        .init(envName: "BAS_SESSION_GATE", polarity: .defaultOnKill,
              owner: "MLXOrganAdapter.swift:363",
              what: "梯次3 per-key 会话闸(串行化 draftMultiTurn/spill/clear;GATE=0 杀)",
              adrRef: "MEGA_AUDIT 梯次3 双设备认证 07-08(endurance 71t + 并发同座位)"),
        .init(envName: "BAS_SPILL_QUANTIZE_UNDER_PRESSURE", polarity: .defaultOnKill,
              owner: "MLXOrganAdapter.swift (_spillQuantizeUnderPressureEnabled)",
              what: "device-recon id9 溢写量化(压力≤0.10 headroom 时 parked KV Q4;=0 杀=恒 fp16)",
              adrRef: "device_recon id9 + A19 认证 299432f3b 07-11"),
        .init(envName: "BAS_TURN_SERIAL", polarity: .defaultOnKill,
              owner: "BASTurnRuntimeEngine.swift (turnSerializer)",
              what: "M-k F1 引擎整轮串行化(一turn一engine不变量;共享 last*/seq 不跨turn串扰;SERIAL=0 杀)",
              adrRef: "MEGA_AUDIT §9 M-k F1 整轮串行化 07-09"),
        // ── 默认开 + kill-switch:数据安全 / 删除教义(BASRuntimeCore 存储层)──────
        // deep-audit sweep 2026-07-13: these 4 default-on DATA-SAFETY kill-switches were live in
        // Sources/BASRuntimeCore but ABSENT from this registry, and the CI drift-detector scanned
        // only the decode stack (BASMLXAdapter/BASHostKit) — so the "every production default-on
        // switch is enumerable + registered" invariant passed green while blind to the storage
        // layer. Registered now; the detector is widened repo-wide + gains the skip-style signature.
        .init(envName: "BAS_SECURE_DELETE", polarity: .defaultOnKill,
              owner: "BASSQLiteSecureDelete.swift:21",
              what: "secure_delete=ON pragma(删除时零填释放页,#16 删除教义;=0 复原 pre-fix 写成本)",
              adrRef: "ADR-014 + MEGA_AUDIT #16 删除教义 + RUNTIME_SECURITY_REPORT F6"),
        .init(envName: "BAS_SECURE_DELETE_VACUUM", polarity: .defaultOnKill,
              owner: "BASSQLiteSecureDelete.swift:79",
              what: "一次性遗留空闲页 VACUUM(重写库文件,清 pre-#16 明文空闲页;=0 关)",
              adrRef: "MEGA_AUDIT memory-a F4 残余"),
        .init(envName: "BAS_FILE_PROTECTION", polarity: .defaultOnKill,
              owner: "BASSQLiteFileProtection.swift:27",
              what: "SQLite 存储文件 NSFileProtection.complete(静态加密;=0 关)",
              adrRef: "ADR-014 + x-sov#5 at-rest 加密"),
        .init(envName: "BAS_SKIP_STORE_INTEGRITY_CHECK", polarity: .defaultOnKill,
              owner: "BASSQLiteIntegrity.swift:32",
              what: "每次开库 PRAGMA integrity_check(损坏=空 防御,fail-closed;SKIP=1 杀跳过)",
              adrRef: "MEGA_AUDIT M-c(损坏=空)"),
        // ── opt-in ───────────────────────────────────────────────────────────
        .init(envName: "BAS_THERMAL_PREDICT", polarity: .optIn,
              owner: "BASEnduranceAppRunner.swift:1545 (app host)",
              what: "B4 热危害预测(learnedBudget 跨会话持久)",
              adrRef: "FRONTIER_2026H2_EVOLUTION B4"),
        .init(envName: "BAS_PRESSURE_LADDER", polarity: .optIn,
              owner: "MLXOrganAdapter.swift:1534",
              what: "案5 压力梯子(rung1 park/rung2 drop MTP/rung3 clearAll)",
              adrRef: "DECODE_OS_AUDIT 案5"),
        .init(envName: "BAS_DECODE_CTX", polarity: .optIn,
              owner: "MLXOrganAdapter+Executor.swift:32",
              what: "可解释性① 📊 turn line(每轮一行,零落盘)",
              adrRef: "INTERPRETABILITY_AUDIT 立即项①"),
        .init(envName: "BAS_HONESTY_OBSERVE", polarity: .optIn,
              owner: "EBrainRuntimeCoordinator.swift:375-384",
              what: "🪞 三轴诚实行(observe-only;永不进 fitness——宪法条款)",
              adrRef: "INTERPRETABILITY_AUDIT 触发器①"),
        .init(envName: "BAS_DISABLE_THINKING", polarity: .optIn,
              owner: "MLXOrganAdapter+Streaming.swift:85 + pooled 4 构造点",
              what: "enable_thinking=false 模板变量(v12 测量先例;观点轴 harness)",
              adrRef: "v12 honesty + trigger4 观点轴 07-07"),
        .init(envName: "BAS_PROFILER_PERSIST", polarity: .optIn,
              owner: "MLXOrganAdapter.swift (P0 2026-07-07)",
              what: "P0 经验持久化(profiler 表+chainEmaL 落盘,温启动)",
              adrRef: "RSI_IMPLANT_CHARTER P0"),
        .init(envName: "BAS_FACTUAL_ADJUDICATE", polarity: .optIn,
              owner: "BASAdjudicatingOrganAdapter.swift:10",
              what: "事实裁决适配器(默认 ABSTAIN)",
              adrRef: "propose/dispose 框架"),
        .init(envName: "BAS_ADJ_OBSERVE", polarity: .optIn,
              owner: "BASAdjudicationObservation.swift:93",
              what: "裁决观察 sink(gateSkipped/noAssertion 等五出口)",
              adrRef: nil),
        .init(envName: "BAS_SESSION_DEBUG", polarity: .optIn,
              owner: "MLXOrganAdapter.swift:1187",
              what: "会话池调试日志", adrRef: nil),
        // ── 常数旋钮 ─────────────────────────────────────────────────────────
        .init(envName: "BAS_MLX_CACHE_LIMIT_MB", polarity: .constantKnob,
              owner: "MLXRuntimeConfig + BASEnduranceAppRunner:1672",
              what: "MLX 自由缓冲池顶棚(默认 512;07-07 设备扫测 DON'T-CARE)",
              adrRef: "ADR-038 + CACHELIMIT_AB_2026-07-07"),
        .init(envName: "BAS_MAX_LIVE_SESSIONS", polarity: .constantKnob,
              owner: "MLXOrganAdapter.swift:343",
              what: "常驻会话席上限(默认 16;2-slot decode governor 另计)",
              adrRef: "T4 cert 系统效率战役"),
        .init(envName: "BAS_TRACE_EXIT_TAU", polarity: .constantKnob,
              owner: "MLXOrganAdapter+MTPSpec.swift:221-238",
              what: "B3 熵阈(默认 300 millinats;+MIN/WINDOW/RESERVE 族)",
              adrRef: "FRONTIER B3"),
        .init(envName: "BAS_KV_BITS", polarity: .constantKnob,
              // deep-audit tests-arch ① (2026-07-13): owner anchor was stale — it read
              // "MLXOrganAdapter" but the actual reader is the DeviceTestApp endurance runner.
              owner: "DeviceTestApp/BASEnduranceAppRunner.swift:1482 (KV 量化 A/B)",
              what: "KV cache 量化位宽（4|8;unset=vendor default）", adrRef: nil),
    ]

    public static func entry(_ envName: String) -> BASProductionSwitch? {
        switches.first { $0.envName == envName }
    }

    /// The default-on set — the exact collection ADR-014 polarity changes graduate into;
    /// 100% coverage of this set is the P2 acceptance gate.
    public static var defaultOnKillSwitches: [BASProductionSwitch] {
        switches.filter { $0.polarity == .defaultOnKill }
    }
}

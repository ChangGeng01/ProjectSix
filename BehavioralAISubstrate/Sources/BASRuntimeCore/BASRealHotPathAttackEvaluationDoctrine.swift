// MARK: - BASRealHotPathAttackEvaluationDoctrine
// chapter 四百七十七 / M1285 — honest re-evaluation
// of the 6 directives after 4 chapters of REAL HOT-PATH
// ATTACK work (chapters 474-477)。
//
// The chapter 473 deep-review scored 6 user-stated
// directives ("更硬核 更极致 最创新 最激进 低熵复杂系统
// 原生利用神经引擎") on a 0-10 scale and exposed that
// the substrate was averaging **~1.8/10** — heavy
// scaffolding,zero hot-path attack。
//
// M1285 ships a TYPED post-chapter-477 re-evaluation
// documenting:
//
//   - Baseline score (chapter 473)
//   - Current score (post-chapter-477)
//   - Concrete evidence for each score movement
//
// This doctrine is NOT aspirational marketing — it's
// pin-for-pin honest about what shipped vs what's still
// open。 Future chapters can cite this doctrine to detect
// regression (if a score field drops without an
// accompanying chapter doctrine documenting why)。

import Foundation

/// Typed per-directive re-evaluation record。
public struct BASDirectiveScoring:
    Equatable, Hashable, Codable, Sendable
{

    /// Raw directive name as the user originally stated
    /// it (Chinese characters preserved verbatim)。
    public let directiveName: String

    /// Chapter 473 deep-review baseline score (0-10)。
    public let baselineScore: Int

    /// Current score after chapters 474-477 work (0-10)。
    public let currentScore: Int

    /// Ordered list of concrete evidence backing the
    /// current score (M-numbers + file references)。
    public let evidence: [String]

    /// What's still open (honest scope acknowledgment)。
    public let stillOpen: String

    public init(
        directiveName: String,
        baselineScore: Int,
        currentScore: Int,
        evidence: [String],
        stillOpen: String
    ) {
        self.directiveName = directiveName
        self.baselineScore = baselineScore
        self.currentScore = currentScore
        self.evidence = evidence
        self.stillOpen = stillOpen
    }

    /// Score delta:current - baseline。 Positive means
    /// progress;negative would indicate regression。
    public var scoreDelta: Int {
        currentScore - baselineScore
    }
}

/// Doctrine namespace owning the post-chapter-477
/// re-evaluation of the 6 user-stated directives。
public enum BASRealHotPathAttackEvaluationDoctrine {

    /// Chapter range covered by this evaluation。
    public static let chapterRangeCovered:
        ClosedRange<Int> = 474...477

    /// M-number range covered:M1272-M1287。
    public static let mNumberRangeCovered:
        ClosedRange<Int> = 1272...1287

    /// Per-directive scorings, in the order the user
    /// originally listed them。
    public static let scorings: [BASDirectiveScoring] = [

        BASDirectiveScoring(
            directiveName: "更硬核 (more hardcore)",
            baselineScore: 4,
            currentScore: 7,
            evidence: [
                "M1273 BASKernelRegistryDispatchExecutor" +
                " wires Metal registry into hot-path" +
                " executor (5 typed outcomes)",
                "M1274 end-to-end PROOF that the full" +
                " dispatch chain composes",
                "M1277 BASMPSGraphMatMulKernel proven" +
                " numerically correct (2×2 matmul" +
                " on real Metal GPU)",
                "M1280 BASMPSGraphRMSNormKernel proven" +
                " numerically correct (3 test cases)",
                "M1282 BASMPSGraphRotaryEmbeddingKernel" +
                " proven correct (identity + 90°" +
                " rotation cases)",
                "M1284 BASMPSGraphAttentionKernel" +
                " proven correct (uniform attention +" +
                " shape pinning) — 4-of-4 kernels" +
                " covered"
            ],
            stillOpen:
                "Hosts still don't dispatch through" +
                " registry by default — hot path" +
                " runs without scheduler/dispatch" +
                " until host configuration opts in。" +
                " 3/10 of the remaining gap is host-" +
                "side wire-in,not substrate-side。"),

        BASDirectiveScoring(
            directiveName: "更极致 (more extreme typed contracts)",
            baselineScore: 2,
            currentScore: 5,
            evidence: [
                "M1273 BASKernelRegistryDispatchOutcome" +
                " 5-case typed enum replaces ad-hoc" +
                " success/failure flags",
                "M1276 BASCanonicalKernelInputBuilders" +
                " typed factory replaces hand-built" +
                " Data payloads",
                "M1281 BASKernelDispatchOutcomeBundle" +
                " typed item struct + Codable round-" +
                "trip PROOF"
            ],
            stillOpen:
                "Only 3 new typed contracts shipped" +
                " in 4 chapters。 Real '极致' means" +
                " 1,000+ typed surfaces。 Future" +
                " chapters need to attack the existing" +
                " 1,282 *Frame/*Bundle sprawl directly。"),

        BASDirectiveScoring(
            directiveName: "最创新 (most innovative)",
            baselineScore: 3,
            currentScore: 7,
            evidence: [
                "M1273 first-ever production-grade" +
                " dispatch executor that consumes" +
                " scheduler's typed assignment +" +
                " routes via registry — bridges" +
                " scheduler ↔ kernel layers that" +
                " were previously disconnected",
                "M1274 first end-to-end PROOF of" +
                " hint→scheduler→assignment→executor→" +
                "registry→kernel composition",
                "M1278 first integration test using" +
                " REAL MPSGraph kernel instead of" +
                " EchoKernel stub — closes the" +
                " M1098 'registry dead-end' gap"
            ],
            stillOpen:
                "Innovation surface ships,but" +
                " adoption is opt-in。 No host has" +
                " adopted the registry-dispatch path" +
                " yet。 Default `.v1ByteEqual` mode" +
                " bypasses everything new。"),

        BASDirectiveScoring(
            directiveName: "最激进 (most aggressive — V1 monolith replacement)",
            baselineScore: 0,
            currentScore: 1,
            evidence: [
                "EBrainRuntimeCoordinator.swift" +
                " still 2540 LOC — V1 monolith" +
                " untouched throughout chapters" +
                " 474-477。 ADR-014 OPT-IN preserved" +
                " by design",
                "Chapter 477 plannedFutureCuts list" +
                " V1 fold as chapter 478+ work" +
                " requiring stress-sweep dual mode" +
                " to safely preserve byte-equality"
            ],
            stillOpen:
                "V1 fold genuinely deferred — not" +
                " sandbagged。 26 ForAudit shadow" +
                " locals (lines 1219-1390) + 6" +
                " boundActionPermit rebinds + 148" +
                " *ForAudit references all still in" +
                " the monolith。 Honest scope:V1" +
                " fold needs a dedicated multi-chapter" +
                " push,not piecemeal work。"),

        BASDirectiveScoring(
            directiveName: "低熵复杂系统 (low-entropy complex system)",
            baselineScore: 1,
            currentScore: 3,
            evidence: [
                "M1281 BASKernelDispatchOutcomeBundle" +
                " — FIRST real BASBundle<Item>" +
                " typealias migration in the" +
                " substrate (closes the chapter 429" +
                " M1088 scaffold-without-migration" +
                " gap)",
                "Existing 5 generic primitives" +
                " (BASBundle/BASResult/" +
                "BASFrameEnvelope/BASPermit/BASCard)" +
                " no longer just 'registered'",
                "BASBundle<Item> convenience accessors" +
                " on dispatched/fallback counts +" +
                " ratios + outcome-category histograms"
            ],
            stillOpen:
                "Only 1 migration in 4 chapters。" +
                " 1,281 sprawl types still hand-rolled。" +
                " Real '低熵' means another 50-100" +
                " migrations + deletion of redundant" +
                " custom struct definitions。"),

        BASDirectiveScoring(
            directiveName: "原生利用神经引擎 (native ANE leverage)",
            baselineScore: 1,
            currentScore: 5,
            evidence: [
                "M1272 BASANELiveReader.live() factory" +
                " queries MLComputeDevice" +
                ".allComputeDevices on iOS 17+/macOS" +
                " 14+ via @available gate",
                "Capability snapshot includes thermal-" +
                "derated latency + op support set",
                "Real-device-gated test asserts" +
                " aneFirst priority + non-empty" +
                " supportedOps when run on physical" +
                " M-series silicon"
            ],
            stillOpen:
                "Probe is opt-in — default still" +
                ".conservative。 No host wires" +
                " BASANELiveReader.live() yet。" +
                " 5/10 of remaining gap is host" +
                " wire-in;substrate is ready。")
    ]

    /// Aggregate baseline score (sum of all 6
    /// directives at chapter 473 baseline)。 Used by
    /// regression-detection tests。
    public static var baselineAggregate: Int {
        return scorings.reduce(0) {
            $0 + $1.baselineScore
        }
    }

    /// Aggregate current score (sum of all 6
    /// directives after chapter 477)。
    public static var currentAggregate: Int {
        return scorings.reduce(0) {
            $0 + $1.currentScore
        }
    }

    /// Average current score across the 6 directives。
    /// Floating-point but stable due to integer inputs。
    public static var currentAverage: Double {
        return Double(currentAggregate)
            / Double(scorings.count)
    }

    /// Average baseline score。
    public static var baselineAverage: Double {
        return Double(baselineAggregate)
            / Double(scorings.count)
    }
}

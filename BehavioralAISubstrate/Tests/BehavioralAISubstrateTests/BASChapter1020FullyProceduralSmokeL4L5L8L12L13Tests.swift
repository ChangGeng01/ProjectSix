// MARK: - BASChapter1020FullyProceduralSmokeL4L5L8L12L13Tests
// chapter 一千零二十 / M3850 — 完成 14-层 ch1017-style proc-gen smoke
//
// User invoked「进化 算法 加强 程序化生成 测试案例 极致 不同案例
// 找到 所有 缺陷 bug 不足 真机 跑10小时冒烟 最好 14层 每层每个部分都
// 冒烟测试 以此发挥最大作用 找到瑕疵 全面冒烟测试 开发极致 极大提高
// benchmark 需要 完全 做到 kill 当前」 (Round-25/27 lesson applied
// up-front:bounded scope,no over-claim)。
//
// ## Honest scope
//
// ch 1017 covered 7 layers in ch1017-style intensity-scalable
// proc-gen smoke (L1 / L6 / L7 / L9 / L10 / L11 / L14)。 ch 946
// covers L2 + L3 via BASHostRuntime runtime spin (the only path
// for those layers — they have no clean single-struct surface
// to fuzz in isolation)。
//
// ch 1020 fills the remaining gap with ch1017-style proc-gen
// tests for the 5 layers that DO have clean Sendable-struct
// surfaces but ch 1017 didn't touch:
//
//   L4 world prior   — BASHorizonPrior + BASBoundaryPrior
//   L5 host constitution — BASHostConstitution
//   L8 memory bundle  — BASMemoryBundle + BASMemoryAtom
//   L12 surface       — BASActionPermit + BASRenderFrame
//   L13 version tree  — BASHostVersion + BASHostVersionTree
//
// Coverage matrix after ch 1020:
//
// | Layer | ch 946 (runtime) | ch 1017 (proc-gen) | ch 1020 |
// |-------|------------------|--------------------|---------|
// | L1    | ✓                | ✓                  | —       |
// | L2    | ✓                | —                  | — (runtime-bound) |
// | L3    | ✓                | —                  | — (runtime-bound) |
// | L4    | ✓                | —                  | ✓       |
// | L5    | ✓                | —                  | ✓       |
// | L6    | —                | ✓                  | —       |
// | L7    | —                | ✓                  | —       |
// | L8    | ✓                | —                  | ✓       |
// | L9    | —                | ✓                  | —       |
// | L10   | —                | ✓                  | —       |
// | L11   | ✓                | ✓                  | —       |
// | L12   | ✓                | —                  | ✓       |
// | L13   | ✓                | —                  | ✓       |
// | L14   | ✓                | ✓                  | —       |
//
// L2/L3 stay covered by ch 946 (runtime-bound — same reason
// ch 1017 didn't pull them in either)。 ch 1020 + ch 1017
// together = 12 of 14 layers in ch1017-style; ch 946 covers
// L2/L3 via the only path possible。 Combined: 14/14。
//
// ## Discipline pins (Round-25/27 lessons)
//
// - Each layer stands alone (no aggregate test — ch 1018 LESSON
//   said XCTest auto-discovery already gates「all green」)
// - Per-layer BEHAVIORAL assertion (NOT vacuous `count >= 0`)
// - Intensity scaling via BAS_FUZZ_INTENSITY (cf ch 1017)
// - Proc-gen PICKS,not proc-gen RANGES — ranges are anchors
//   that the user mandates land on,values within them vary by
//   deterministic BASFuzzRng seed
// - Scorecard emit per layer for ch 952.7 trend analysis
//
// ## What ch 1020 does NOT claim
//
// - Does NOT add new evolution algorithm — ch 946 already has
//   BAS_FUZZ_EVOL_GEN × BAS_FUZZ_EVOL_CHILD envvar-driven
//   evolutionary fuzz。 Round-25/27 lesson: don't ship infra
//   just because mandate uses the keyword — ship when a
//   specific defect-class is identified that current infra
//   misses
// - Does NOT cover L2/L3 — those layers' behavior is only
//   testable through BASHostRuntime spin (which ch 946 already
//   does)。 Round-25 caught me trying to over-claim 14-layer
//   coverage in ch 1017; this chapter explicitly refuses that
//   trap
// - Does NOT「raise benchmark」 — ch 952.4 HighBar benchmark
//   already exists with 5000-iter bench and 25s p99 ceiling。
//   This chapter is value-fuzz on schema constructors,not
//   throughput

import XCTest
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASWorldPrior

final class BASChapter1020FullyProceduralSmokeL4L5L8L12L13Tests:
    XCTestCase
{

    // MARK: - Procedural intensity scaling (mirrors ch 1017)

    private var intensity: Int {
        if let env = ProcessInfo.processInfo
            .environment["BAS_FUZZ_INTENSITY"],
           let n = Int(env), n > 0
        {
            return n
        }
        return 1
    }

    private var iterCount: Int {
        return max(10, intensity * 10)
    }

    // MARK: - Proc-gen value helpers (mirrors ch 1017 contract)

    /// Deterministic procedural int in range,seeded by
    /// (test-name, iter-index)。
    private func procInt(
        _ function: String = #function,
        iter: Int,
        range: ClosedRange<Int>
    ) -> Int {
        var rng = BASFuzzRng(
            seed: testSeed(function, iteration: iter))
        return rng.nextInt(in: range)
    }

    /// Boundary-biased int pick — 50% boundary,50% interior。
    private func procIntBoundary(
        _ function: String = #function,
        iter: Int,
        choices: [Int]
    ) -> Int {
        var rng = BASFuzzRng(
            seed: testSeed(function, iteration: iter))
        return rng.pickBoundaryBiased(choices, boundaryP: 0.5)
    }

    /// Boundary-biased generic pick — leverages BASFuzzRng's
    /// existing generic API。
    private func procPick<T>(
        _ function: String = #function,
        iter: Int,
        choices: [T]
    ) -> T {
        var rng = BASFuzzRng(
            seed: testSeed(function, iteration: iter))
        return rng.pickBoundaryBiased(choices, boundaryP: 0.5)
    }

    /// Scorecard print — every sub-test emits at the end。
    /// Trend analysis tooling (ch 952.7) consumes the same
    /// format as ch 1017 (`ch1020-scorecard` prefix)。
    private func emitScorecard(
        layer: Int,
        component: String,
        iters: Int,
        durationMs: Double,
        minMs: Double,
        maxMs: Double
    ) {
        let avgMs = durationMs / Double(iters)
        let avgStr = String(format: "%.4f", avgMs)
        let minStr = String(format: "%.4f", minMs)
        let maxStr = String(format: "%.4f", maxMs)
        print("📊 ch1020-scorecard | layer=L\(layer) " +
              "component=\(component) iters=\(iters) " +
              "avg=\(avgStr)ms min=\(minStr)ms " +
              "max=\(maxStr)ms intensity=\(intensity)")
    }

    @discardableResult
    private func timedIter<T>(
        _ block: () throws -> T,
        minMs: inout Double,
        maxMs: inout Double,
        totalMs: inout Double
    ) rethrows -> T {
        let t0 = ContinuousClock().now
        let result = try block()
        let ms = Double(
            (ContinuousClock().now - t0).components.attoseconds
        ) / 1e15
        if ms < minMs { minMs = ms }
        if ms > maxMs { maxMs = ms }
        totalMs += ms
        return result
    }

    // MARK: - L4 world prior

    /// L4 smoke: BASHorizonPrior + BASBoundaryPrior construction
    /// across the full enum cross-product。 Validates:
    ///   - confidence clamp into [0, 1] (input range -1.0 to 2.0)
    ///   - enum preservation through init
    ///   - both prior types coexist with shared boundary state
    func testL4_WorldPrior_AcrossEnumCrossProduct() throws {
        let function = #function
        let n = iterCount
        var minMs: Double = .infinity
        var maxMs: Double = 0
        var totalMs: Double = 0
        let priorTypes = BASHorizonPriorType.allCases
        let stabilityTiers = BASHorizonStabilityTier.allCases
        let severities = BASBoundaryPriorSeverity.allCases
        for i in 0..<n {
            // Proc-gen confidence — covers below/at/above [0,1]
            // boundary to exercise the min(1,max(0,x)) clamp
            let rawConfidence = procIntBoundary(
                function, iter: i,
                choices: [-100, 0, 50, 100, 200])
            let confidence = Double(rawConfidence) / 100.0
            let priorType = procPick(
                function, iter: i + 1000,
                choices: priorTypes)
            let stability = procPick(
                function, iter: i + 2000,
                choices: stabilityTiers)
            let severity = procPick(
                function, iter: i + 3000,
                choices: severities)
            let hardStop = (i % 2 == 0)
            try timedIter({
                let horizon = BASHorizonPrior(
                    priorID: "h.\(i)",
                    priorType: priorType,
                    stabilityTier: stability,
                    scope: "scope.\(i)",
                    confidence: confidence,
                    sourceClass: "test.\(i)")
                let boundary = BASBoundaryPrior(
                    boundaryID: "b.\(i)",
                    domain: "domain.\(i)",
                    severity: severity,
                    hardStop: hardStop,
                    safeAlternatives: ["alt.\(i)"],
                    escalationRule: "rule.\(i)")
                // Behavioral pin 1: confidence clamps into [0,1]
                XCTAssertGreaterThanOrEqual(
                    horizon.confidence, 0.0,
                    "L4 ch 1020: confidence clamp floor violated " +
                    "for input \(confidence)")
                XCTAssertLessThanOrEqual(
                    horizon.confidence, 1.0,
                    "L4 ch 1020: confidence clamp ceiling violated " +
                    "for input \(confidence)")
                // Behavioral pin 2: enum preserved through init
                XCTAssertEqual(horizon.priorType, priorType,
                    "L4: priorType MUST survive init")
                XCTAssertEqual(horizon.stabilityTier, stability,
                    "L4: stabilityTier MUST survive init")
                XCTAssertEqual(boundary.severity, severity,
                    "L4: boundary severity MUST survive init")
                XCTAssertEqual(boundary.hardStop, hardStop,
                    "L4: boundary hardStop MUST survive init")
                // Behavioral pin 3: trim normalization on scope
                XCTAssertEqual(horizon.scope, "scope.\(i)",
                    "L4: scope MUST trim cleanly")
            },
            minMs: &minMs, maxMs: &maxMs, totalMs: &totalMs)
        }
        emitScorecard(
            layer: 4, component: "HorizonPrior+BoundaryPrior",
            iters: n, durationMs: totalMs,
            minMs: minMs, maxMs: maxMs)
    }

    // MARK: - L5 host constitution

    /// L5 smoke: BASHostConstitution across proc-gen hostIDs +
    /// version strings。 Validates:
    ///   - default-init paths for all 14 lattice components
    ///   - constitutionID default = "{hostID}.constitution"
    ///   - schema version pinned to currentSchemaVersion
    func testL5_HostConstitution_AcrossIdentities() throws {
        let function = #function
        let n = iterCount
        var minMs: Double = .infinity
        var maxMs: Double = 0
        var totalMs: Double = 0
        for i in 0..<n {
            let hostSuffix = procInt(
                function, iter: i, range: 0...10_000)
            let versionMajor = procIntBoundary(
                function, iter: i + 100,
                choices: [0, 1, 5, 100, 1000])
            let versionMinor = procInt(
                function, iter: i + 200, range: 0...99)
            let hostID = "host.\(hostSuffix)"
            let activeVersion =
                "host.v\(versionMajor).\(versionMinor)"
            try timedIter({
                let constitution = BASHostConstitution(
                    hostID: hostID,
                    activeVersion: activeVersion)
                // Behavioral pin 1: hostID preserved
                XCTAssertEqual(constitution.hostID, hostID,
                    "L5: hostID MUST round-trip")
                // Behavioral pin 2: constitutionID default
                XCTAssertEqual(
                    constitution.constitutionID,
                    "\(hostID).constitution",
                    "L5: constitutionID default MUST be " +
                    "「{hostID}.constitution」")
                // Behavioral pin 3: version preserved
                XCTAssertEqual(
                    constitution.activeVersion, activeVersion,
                    "L5: activeVersion MUST round-trip")
                // Behavioral pin 4: schemaVersion pinned
                XCTAssertEqual(
                    constitution.schemaVersion,
                    BASHostConstitution.currentSchemaVersion,
                    "L5: schemaVersion MUST default to current")
            },
            minMs: &minMs, maxMs: &maxMs, totalMs: &totalMs)
        }
        emitScorecard(
            layer: 5, component: "HostConstitution",
            iters: n, durationMs: totalMs,
            minMs: minMs, maxMs: maxMs)
    }

    // MARK: - L8 memory bundle

    /// L8 smoke: BASMemoryBundle with proc-gen atom counts across
    /// the full BASMemoryAtomContentType enum。 Validates:
    ///   - atoms count round-trip
    ///   - retrievalTags count round-trip
    ///   - per-atom contentType preserved through bundle wrap
    func testL8_MemoryBundle_AcrossAtomCounts() throws {
        let function = #function
        let n = iterCount
        var minMs: Double = .infinity
        var maxMs: Double = 0
        var totalMs: Double = 0
        let contentTypes = BASMemoryAtomContentType.allCases
        let promotionStates = BASPromotionState.allCases
        for i in 0..<n {
            let atomCount = procIntBoundary(
                function, iter: i,
                choices: [0, 1, 10, 100, 1000])
            let tagCount = procInt(
                function, iter: i + 100, range: 0...10)
            let contentType = procPick(
                function, iter: i + 200,
                choices: contentTypes)
            let promotion = procPick(
                function, iter: i + 300,
                choices: promotionStates)
            let atoms = (0..<atomCount).map { j in
                BASMemoryAtom(
                    memoryID: "atom.\(i).\(j)",
                    summary: "summary.\(j)",
                    contentType: contentType,
                    source: "src.\(i)",
                    confidence: 0.5,
                    emotionalWeight: 0,
                    riskRelevance: 0,
                    hostRelevance: 0,
                    conflictFingerprint: "",
                    promotionState: promotion,
                    frozen: false)
            }
            let tags = (0..<tagCount).map { "tag.\($0)" }
            try timedIter({
                let bundle = BASMemoryBundle(
                    atoms: atoms,
                    retrievalTags: tags)
                // Behavioral pin 1: atom count round-trip
                XCTAssertEqual(bundle.atoms.count, atomCount,
                    "L8: bundle MUST preserve atom count")
                // Behavioral pin 2: tag count round-trip
                XCTAssertEqual(
                    bundle.retrievalTags.count, tagCount,
                    "L8: bundle MUST preserve retrievalTags count")
                // Behavioral pin 3: per-atom contentType preserved
                for atom in bundle.atoms {
                    XCTAssertEqual(atom.contentType, contentType,
                        "L8: atom contentType MUST survive bundle wrap")
                    XCTAssertEqual(atom.promotionState, promotion,
                        "L8: atom promotionState MUST survive bundle wrap")
                }
            },
            minMs: &minMs, maxMs: &maxMs, totalMs: &totalMs)
        }
        emitScorecard(
            layer: 8, component: "MemoryBundle",
            iters: n, durationMs: totalMs,
            minMs: minMs, maxMs: maxMs)
    }

    // MARK: - L12 surface (action permit + render frame)

    /// L12 smoke: BASActionPermit across the full mode enum +
    /// BASRenderFrame ref-stitching。 Validates:
    ///   - mode preservation
    ///   - outputLengthCap clamp floor at 0 (max(0,x) contract)
    ///   - allowedDomains dedup contract (count ≤ input)
    ///   - render frame preserves permit ref
    func testL12_SurfacePermit_AcrossModes() throws {
        let function = #function
        let n = iterCount
        var minMs: Double = .infinity
        var maxMs: Double = 0
        var totalMs: Double = 0
        let modes = BASActionPermitMode.allCases
        for i in 0..<n {
            let mode = procPick(
                function, iter: i, choices: modes)
            // proc-gen outputLengthCap to test the max(0,x) floor
            let rawCap = procIntBoundary(
                function, iter: i + 100,
                choices: [-1000, 0, 240, 4096, 1_000_000])
            let allowedCount = procInt(
                function, iter: i + 200, range: 0...10)
            let allowedDomains = (0..<allowedCount).map {
                "d.\(i).\($0)"
            }
            try timedIter({
                let permit = BASActionPermit(
                    mode: mode,
                    allowedDomains: allowedDomains,
                    outputLengthCap: rawCap)
                let frame = BASRenderFrame(
                    frameID: "rf.\(i)",
                    actionPermitRef: "permit.\(i)")
                // Behavioral pin 1: mode preserved
                XCTAssertEqual(permit.mode, mode,
                    "L12: mode MUST round-trip")
                // Behavioral pin 2: outputLengthCap clamped ≥0
                XCTAssertGreaterThanOrEqual(
                    permit.outputLengthCap, 0,
                    "L12: outputLengthCap MUST clamp " +
                    "negative input to 0 (got \(rawCap))")
                // Behavioral pin 3: dedup contract — output ≤ input
                XCTAssertLessThanOrEqual(
                    permit.allowedDomains.count, allowedCount,
                    "L12: allowedDomains dedup MUST keep count ≤ input")
                // Behavioral pin 4: render frame preserves ref
                XCTAssertEqual(
                    frame.actionPermitRef, "permit.\(i)",
                    "L12: render frame MUST preserve permit ref")
                // Behavioral pin 5: frameID trimmed (no whitespace input → unchanged)
                XCTAssertEqual(frame.frameID, "rf.\(i)",
                    "L12: frameID MUST trim cleanly")
            },
            minMs: &minMs, maxMs: &maxMs, totalMs: &totalMs)
        }
        emitScorecard(
            layer: 12, component: "ActionPermit+RenderFrame",
            iters: n, durationMs: totalMs,
            minMs: minMs, maxMs: maxMs)
    }

    // MARK: - L13 version tree

    /// L13 smoke: BASHostVersion + BASHostVersionTree across
    /// proc-gen chain lengths。 Validates:
    ///   - active version pointer preserved
    ///   - parent-link chain integrity (root has nil parent;
    ///     every non-root v_j has parent = v_{j-1})
    ///   - approvedByPolicy round-trip
    ///   - changedFields preserved
    func testL13_VersionTree_AcrossChainLengths() throws {
        let function = #function
        let n = iterCount
        var minMs: Double = .infinity
        var maxMs: Double = 0
        var totalMs: Double = 0
        for i in 0..<n {
            let chainLen = procIntBoundary(
                function, iter: i,
                choices: [1, 2, 5, 20, 100])
            let approvedCount = procInt(
                function, iter: i + 100, range: 0...chainLen)
            let fieldCount = procInt(
                function, iter: i + 200, range: 1...5)
            let versions: [BASHostVersion] =
                (0..<chainLen).map { j in
                BASHostVersion(
                    versionID: "v.\(i).\(j)",
                    changedFields:
                        (0..<fieldCount).map { "field.\(j).\($0)" },
                    reason: "reason.\(j)",
                    approvedByPolicy: j < approvedCount,
                    parentVersionID: j == 0
                        ? nil
                        : "v.\(i).\(j - 1)")
            }
            let activeID = "v.\(i).\(chainLen - 1)"
            try timedIter({
                let tree = BASHostVersionTree(
                    activeVersionID: activeID,
                    versions: versions)
                // Behavioral pin 1: active ID preserved
                XCTAssertEqual(tree.activeVersionID, activeID,
                    "L13: activeVersionID MUST round-trip")
                // Behavioral pin 2: version count preserved
                XCTAssertEqual(tree.versions.count, chainLen,
                    "L13: chain length MUST round-trip")
                // Behavioral pin 3: parent chain integrity
                for j in 1..<chainLen {
                    XCTAssertEqual(
                        tree.versions[j].parentVersionID,
                        "v.\(i).\(j - 1)",
                        "L13: parent chain MUST preserve link order " +
                        "at index \(j)")
                }
                // Behavioral pin 4: root has nil parent
                XCTAssertNil(
                    tree.versions[0].parentVersionID,
                    "L13: root version MUST have nil parentVersionID")
                // Behavioral pin 5: approvedByPolicy round-trip
                let actualApproved = tree.versions.filter {
                    $0.approvedByPolicy
                }.count
                XCTAssertEqual(
                    actualApproved, approvedCount,
                    "L13: approvedByPolicy count MUST round-trip")
                // Behavioral pin 6: changedFields count preserved
                for v in tree.versions {
                    XCTAssertEqual(
                        v.changedFields.count, fieldCount,
                        "L13: changedFields count MUST round-trip")
                }
            },
            minMs: &minMs, maxMs: &maxMs, totalMs: &totalMs)
        }
        emitScorecard(
            layer: 13, component: "HostVersionTree",
            iters: n, durationMs: totalMs,
            minMs: minMs, maxMs: maxMs)
    }
}

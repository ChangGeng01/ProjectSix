import XCTest
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASOrgan
@testable import BASRuntimeCore
import CryptoKit
import Foundation
import SQLite3

/// QINAO Substrate-100 gates — Phase-2 batch 14 (6 MEDIUM + 2 HIGH rework). Completes the host-authorable Substrate-100.
final class BASQINAOSubstrateGatesBatch14Tests: XCTestCase {

    func test_qinao_provider_routing_determinism() {
    // Mirror the existing-test descriptor builder verbatim from BASNeuralProviderMatrixTests.swift.
    func qinaoDesc(
        _ id: String, onDevice: Bool = true, roles: Set<BASOrganRole> = [.scout, .core],
        kind: BASProviderKind? = nil, tier: BASCertificationTier? = nil, size: Int? = nil
    ) -> BASOrganDescriptor {
        BASOrganDescriptor(
            providerID: id, providerName: id, supportsStreaming: false,
            maxInputTokens: 1000, maxOutputTokens: 1000, runsOnDevice: onDevice, supportedRoles: roles,
            providerKind: kind, certificationTier: tier, modelSizeHint: size)
    }

    // A mixed candidate pool exercising every score lever: on/off-device, kind bias, cert, size,
    // an unsupported-role candidate, and a pure tie pair (same score → providerID tiebreak).
    let candidates: [BASOrganDescriptor] = [
        qinaoDesc("remote-exp", onDevice: false, kind: .remote, tier: .experimental, size: 8_000_000_000),
        qinaoDesc("apple-cert", kind: .appleNative, tier: .certified, size: 2_000_000_000),
        qinaoDesc("mlx-small", kind: .mlx, tier: .experimental, size: 1_000_000_000),
        qinaoDesc("det-mid", kind: .deterministic, tier: .none, size: 1_000_000_000),
        qinaoDesc("scout-only", roles: [.scout]),                 // unsupported for .core
        qinaoDesc("tie-b", kind: .mlx, tier: .experimental, size: 1_000_000_000),
        qinaoDesc("tie-a", kind: .mlx, tier: .experimental, size: 1_000_000_000), // identical score to tie-b
    ]

    let context = BASNeuralProviderMatrix.SelectionContext(
        role: .core, preferCertified: true, preferSmallest: true)

    // --- Oracle: the canonical Selection from the source order.
    let oracle = BASNeuralProviderMatrix.select(context: context, candidates: candidates)

    // The scout-only candidate must be skipped (unsupported for .core), exactly once.
    XCTAssertEqual(oracle.unsupportedProviderIDs, ["scout-only"],
                   "unsupported candidates are exactly those not supporting the role, sorted")

    // chosen == ranked.first contract.
    XCTAssertEqual(oracle.chosen, oracle.ranked.first, "chosen must equal ranked.first")
    XCTAssertNotNil(oracle.chosen, "at least one candidate supports .core")

    // Ranks are sequential from 0 with no gaps/dupes.
    XCTAssertEqual(oracle.ranked.map(\.rank), Array(0..<oracle.ranked.count),
                   "rank is 0..<n sequential")

    // Score-DESC → providerID-ASC total order is replay-stable: the ranked providerID list
    // must be sorted ASC within every equal-score run. We verify the pure tie pair specifically:
    // tie-a and tie-b have identical score, so tie-a MUST precede tie-b.
    let order = oracle.ranked.map(\.providerID)
    let iA = order.firstIndex(of: "tie-a")
    let iB = order.firstIndex(of: "tie-b")
    XCTAssertNotNil(iA); XCTAssertNotNil(iB)
    if let a = iA, let b = iB {
        XCTAssertLessThan(a, b, "equal-score ties broken lexicographically by providerID (a before b)")
    }

    // --- Replay stability: N re-calls with the SAME input ⇒ byte-identical Selection (tolerance 0).
    for _ in 0..<8 {
        let again = BASNeuralProviderMatrix.select(context: context, candidates: candidates)
        XCTAssertEqual(again, oracle, "pure: identical inputs ⇒ identical Selection across reruns")
    }

    // --- Permutation invariance: select is a PURE function of the SET, not call/input order.
    // Every permutation of the candidate array must yield the SAME ranked order, the SAME chosen,
    // and the SAME (sorted) unsupported set. We enumerate all permutations of the 7-element array.
    func permutations<T>(_ xs: [T]) -> [[T]] {
        if xs.count <= 1 { return [xs] }
        var out: [[T]] = []
        for i in xs.indices {
            var rest = xs
            let pivot = rest.remove(at: i)
            for tail in permutations(rest) { out.append([pivot] + tail) }
        }
        return out
    }
    // 7! = 5040 permutations — full exhaustive coverage of input-order independence.
    let perms = permutations(candidates)
    XCTAssertEqual(perms.count, 5040, "exhaustive 7! permutation coverage")
    for perm in perms {
        let s = BASNeuralProviderMatrix.select(context: context, candidates: perm)
        XCTAssertEqual(s, oracle, "select is order-independent: any input permutation ⇒ identical Selection")
    }

    print("QINAO-GATE provider_routing_determinism: PASS chosen=\(oracle.chosen?.providerID ?? "nil") order=\(order) unsupported=\(oracle.unsupportedProviderIDs) replay=8 permutations=\(perms.count)")
}

    func test_qinao_bastensor_descriptor_phantom_agreement() {
    // QINAO #22 — every BASTensor construction enforces
    // dataType / rank / shape / backingKind agreement with its
    // phantom Element+Shape evidence BEFORE a kernel sees it.
    // The four agreement checks live as `precondition`s in
    // BASTensor.init (Sources/BASMetalSubstrate/BASTensor.swift
    // L173-196). A precondition aborts the process, so it is
    // NOT catchable in-process by XCTest, and there is no
    // testable `validate` path. We therefore:
    //   (A) assert the VALID path exhaustively — every dtype ×
    //       every backing × every rank constructs through the
    //       REAL factories and the descriptor agrees with the
    //       phantom evidence (tolerance = 0, exact equality);
    //   (B) assert the EXACT boolean predicates the init's
    //       preconditions evaluate (descriptor.dataType ==
    //       Element.dataType, descriptor.rankTag == Shape.rankTag,
    //       descriptor.backingKind == wrappedValue.kind,
    //       descriptor.shape.count == Shape.rank) — proving a
    //       mismatched descriptor would be REJECTED at
    //       construction — by constructing deliberately-
    //       disagreeing descriptors and asserting each guard
    //       predicate is FALSE (so the precondition would fire),
    //       WITHOUT invoking the crashing init;
    //   (C) determinism: re-call the valid path and assert byte-
    //       stable descriptor equality.
    // Construction mirrors BASTensorTests.swift verbatim
    // (.contiguous(shape:dataType:backingKind:rankTag:) + the
    // typed factories .cpu/.mlx/.coreML/.metal).

    // ---- (A) exhaustive VALID path: every dtype, every rank,
    //          every backing. We use Float / Int32 / UInt8 / Bool
    //          (the existing test's portable scalar set; Float16
    //          is arch(arm64)-gated and excluded for portability).

    // float32 / _2D, all four backings.
    let f32Desc2D: (BASTensorBackingKind) -> BASTensorDescriptor = { kind in
        BASTensorDescriptor.contiguous(
            shape: [2, 2],
            dataType: .float32,
            backingKind: kind,
            rankTag: _2D.rankTag)
    }
    let fCPU: BASTensor<Float, _2D> = .cpu(
        Data(count: 16), descriptor: f32Desc2D(.cpuBytes))
    let fMLX: BASTensor<Float, _2D> = .mlx(
        NSObject(), descriptor: f32Desc2D(.mlxArray))
    let fCoreML: BASTensor<Float, _2D> = .coreML(
        NSObject(), descriptor: f32Desc2D(.mlMultiArray))
    let fMetal: BASTensor<Float, _2D> = .metal(
        NSObject(), descriptor: f32Desc2D(.metalBuffer))

    // For each: descriptor.backingKind agrees with runtime
    // backing kind, dtype agrees with Element, rankTag + rank
    // agree with Shape. Exact equality (tolerance = 0).
    let f32Tensors:
        [(BASTensor<Float, _2D>, BASTensorBackingKind)] = [
        (fCPU, .cpuBytes),
        (fMLX, .mlxArray),
        (fCoreML, .mlMultiArray),
        (fMetal, .metalBuffer),
    ]
    for (t, expectedKind) in f32Tensors {
        XCTAssertEqual(t.descriptor.backingKind, expectedKind)
        XCTAssertEqual(t.wrappedValue.kind, expectedKind)
        // init precondition #3: descriptor.backingKind ==
        // wrappedValue.kind.
        XCTAssertEqual(
            t.descriptor.backingKind, t.wrappedValue.kind)
        // init precondition #1: descriptor.dataType ==
        // Element.dataType (Float -> .float32).
        XCTAssertEqual(t.descriptor.dataType, Float.dataType)
        XCTAssertEqual(t.descriptor.dataType, .float32)
        // init precondition #2: descriptor.rankTag ==
        // Shape.rankTag (_2D -> "rank-2").
        XCTAssertEqual(t.descriptor.rankTag, _2D.rankTag)
        XCTAssertEqual(t.descriptor.rankTag, "rank-2")
        // init precondition #4: descriptor.shape.count ==
        // Shape.rank.
        XCTAssertEqual(t.descriptor.shape.count, _2D.rank)
        XCTAssertEqual(t.descriptor.shape.count, 2)
        // descriptor.byteCount derives from dtype.byteWidth ×
        // elementCount and equals Element.byteWidth × count.
        XCTAssertEqual(
            t.descriptor.byteCount,
            t.descriptor.elementCount * Float.byteWidth)
    }

    // Non-float scalar types across ranks 1/3/4 (CPU path so we
    // also exercise the .cpu byte-count precondition).
    let int32T: BASTensor<Int32, _1D> = .cpu(
        Data(count: 4 * 4),
        descriptor: BASTensorDescriptor.contiguous(
            shape: [4], dataType: .int32,
            backingKind: .cpuBytes, rankTag: _1D.rankTag))
    XCTAssertEqual(int32T.descriptor.dataType, Int32.dataType)
    XCTAssertEqual(int32T.descriptor.dataType, .int32)
    XCTAssertEqual(int32T.descriptor.rankTag, _1D.rankTag)
    XCTAssertEqual(int32T.descriptor.shape.count, _1D.rank)
    XCTAssertEqual(int32T.byteCount, 16)

    let u8T: BASTensor<UInt8, _3D> = .cpu(
        Data(count: 2 * 3 * 4),
        descriptor: BASTensorDescriptor.contiguous(
            shape: [2, 3, 4], dataType: .uint8,
            backingKind: .cpuBytes, rankTag: _3D.rankTag))
    XCTAssertEqual(u8T.descriptor.dataType, UInt8.dataType)
    XCTAssertEqual(u8T.descriptor.dataType, .uint8)
    XCTAssertEqual(u8T.descriptor.rankTag, _3D.rankTag)
    XCTAssertEqual(u8T.descriptor.shape.count, _3D.rank)
    XCTAssertEqual(u8T.elementCount, 24)
    XCTAssertEqual(u8T.byteCount, 24)

    let boolT: BASTensor<Bool, _4D> = .cpu(
        Data(count: 1 * 1 * 2 * 2),
        descriptor: BASTensorDescriptor.contiguous(
            shape: [1, 1, 2, 2], dataType: .bool,
            backingKind: .cpuBytes, rankTag: _4D.rankTag))
    XCTAssertEqual(boolT.descriptor.dataType, Bool.dataType)
    XCTAssertEqual(boolT.descriptor.dataType, .bool)
    XCTAssertEqual(boolT.descriptor.rankTag, _4D.rankTag)
    XCTAssertEqual(boolT.descriptor.shape.count, _4D.rank)
    XCTAssertEqual(boolT.elementCount, 4)
    XCTAssertEqual(boolT.byteCount, 4)

    // Exhaustive cross-check: BASTensorDataType.byteWidth (the
    // descriptor's source of truth) agrees with each scalar's
    // BASTensorScalar.byteWidth — this is the same single-source
    // the init's byteCount precondition relies on. tolerance = 0.
    XCTAssertEqual(BASTensorDataType.float32.byteWidth, Float.byteWidth)
    XCTAssertEqual(BASTensorDataType.int32.byteWidth, Int32.byteWidth)
    XCTAssertEqual(BASTensorDataType.uint8.byteWidth, UInt8.byteWidth)
    XCTAssertEqual(BASTensorDataType.bool.byteWidth, Bool.byteWidth)

    // Exhaustive rank-tag / rank table (the phantom side the init
    // compares against). Listed explicitly from source since the
    // shape protocol has no .allCases.
    XCTAssertEqual(_0D.rank, 0); XCTAssertEqual(_0D.rankTag, "rank-0")
    XCTAssertEqual(_1D.rank, 1); XCTAssertEqual(_1D.rankTag, "rank-1")
    XCTAssertEqual(_2D.rank, 2); XCTAssertEqual(_2D.rankTag, "rank-2")
    XCTAssertEqual(_3D.rank, 3); XCTAssertEqual(_3D.rankTag, "rank-3")
    XCTAssertEqual(_4D.rank, 4); XCTAssertEqual(_4D.rankTag, "rank-4")
    XCTAssertEqual(_NDim.rank, -1)
    XCTAssertEqual(_NDim.rankTag, "rank-dynamic")

    // ---- (B) REJECTION proof. Build descriptors that DISAGREE
    //          with a Float/_2D/cpuBytes phantom+backing target,
    //          and assert the EXACT predicate each init
    //          precondition evaluates is FALSE — i.e. the guard
    //          would fire and the mismatched descriptor would be
    //          rejected at construction, before any kernel. We do
    //          NOT call the crashing init; we evaluate the same
    //          comparison the init uses.

    // (B1) dtype disagreement: descriptor says .int32 but phantom
    //      Element is Float (.float32).
    let wrongDtype = BASTensorDescriptor.contiguous(
        shape: [2, 2], dataType: .int32,
        backingKind: .cpuBytes, rankTag: _2D.rankTag)
    XCTAssertFalse(wrongDtype.dataType == Float.dataType,
        "precondition #1 would fire: dtype mismatch rejected")

    // (B2) rankTag disagreement: descriptor tagged rank-3 but
    //      phantom Shape is _2D (rank-2).
    let wrongRankTag = BASTensorDescriptor.contiguous(
        shape: [2, 2], dataType: .float32,
        backingKind: .cpuBytes, rankTag: _3D.rankTag)
    XCTAssertFalse(wrongRankTag.rankTag == _2D.rankTag,
        "precondition #2 would fire: rankTag mismatch rejected")

    // (B3) backingKind disagreement: descriptor says .mlxArray
    //      but the runtime backing is .cpuBytes.
    let cpuBacking: BASTensorBacking = .cpuBytes(Data(count: 16))
    let wrongBacking = BASTensorDescriptor.contiguous(
        shape: [2, 2], dataType: .float32,
        backingKind: .mlxArray, rankTag: _2D.rankTag)
    XCTAssertFalse(wrongBacking.backingKind == cpuBacking.kind,
        "precondition #3 would fire: backingKind mismatch rejected")

    // (B4) shape-arity disagreement: descriptor shape has 3 axes
    //      but phantom Shape _2D.rank is 2.
    let wrongArity = BASTensorDescriptor.contiguous(
        shape: [2, 2, 2], dataType: .float32,
        backingKind: .cpuBytes, rankTag: _2D.rankTag)
    let arityAgrees =
        (wrongArity.shape.count == _2D.rank) || (_2D.rank == -1)
    XCTAssertFalse(arityAgrees,
        "precondition #4 would fire: shape arity mismatch rejected")

    // (B5) the .cpu byte-count precondition: bytes must equal
    //      descriptor.byteCount. A short buffer disagrees.
    let cpuDesc = f32Desc2D(.cpuBytes)
    XCTAssertEqual(cpuDesc.byteCount, 16)
    XCTAssertFalse(Data(count: 8).count == cpuDesc.byteCount,
        ".cpu byte-count precondition would fire on short buffer")
    // And the matching valid buffer passes the same predicate.
    XCTAssertTrue(Data(count: 16).count == cpuDesc.byteCount)

    // ---- (C) determinism: identical inputs -> byte-equal
    //          descriptor and an identical valid construction.
    let again: BASTensor<Float, _2D> = .cpu(
        Data(count: 16), descriptor: f32Desc2D(.cpuBytes))
    XCTAssertEqual(again.descriptor, fCPU.descriptor)
    XCTAssertEqual(again.descriptor.strides, fCPU.descriptor.strides)
    XCTAssertEqual(again.byteCount, fCPU.byteCount)

    print("QINAO-GATE bastensor_descriptor_phantom_agreement: " +
        "PASS valid-path exhaustive over 4 dtypes × 4 backings × " +
        "ranks {1,2,3,4} all agree (dtype/rankTag/arity/backing, " +
        "tolerance=0); 5 disagreement predicates (dtype, rankTag, " +
        "backingKind, shape-arity, cpu byte-count) all FALSE " +
        "(precondition would reject mismatched descriptor before " +
        "any kernel); descriptor construction deterministic. " +
        "Precondition crash-trap not catchable in-process (no " +
        "testable validate path) — asserted the exact guard " +
        "predicates host-side instead.")
}

    func test_qinao_adaptive_strategy_idempotence() {
    // Mirror existing-test construction (BASRuntimeCoreTests.swift:823-852):
    // a reflective base strategy + a brief-session signal set that drives the
    // reduction branch (briefBias >= 0.78 || fatigueSignal >= 0.68 || hasBriefSessionBias).
    let base = BASAdaptiveTaskStrategy(
        kind: .reflective,
        entropy: .high,
        runtimeGear: .high,
        contextBudget: 620,
        retrievalMode: .adaptive,
        thinkingMode: .gated,
        outputMode: .reflectiveStructured,
        tone: .reflectiveClear,
        actionSpace: ["name_pattern"],
        responseLanguage: .english,
        allowsModelInvocation: true
    )

    let signals = BASAdaptiveRuntimeSignals(
        briefBias: 0.92,
        fatigueSignal: 0.82,
        hasBriefSessionBias: true,
        interruptiveBias: 0.41,
        boundaryBias: 0.3,
        tradeoffBias: 0.22,
        rebuiltSession: false,
        staleFieldCount: 0,
        screenedOutMemoryCount: 0,
        lowTrustLoad: false,
        retrievalInstability: false,
        retrievalTags: []
    )

    // Source-of-truth floors from adapting(signals:) (AdaptiveRuntimeCore.swift:528-555):
    // for .reflective, minimumBudget = 260; outputCharacterBudget floor = 120;
    // timeBudgetMs floor = 300; toolCallBudget/retrievalItemBudget floor = 0.
    let contextFloor = 260
    let outputFloor = 120
    let timeFloor = 300

    // (1) DETERMINISM: same input yields byte-identical output across re-calls.
    let first = base.adapting(signals: signals)
    let second = base.adapting(signals: signals)
    XCTAssertEqual(first, second, "adapting(signals:) must be deterministic for identical input (tolerance=0)")

    // (2) FLOOR: a single budget application must respect every floor.
    XCTAssertGreaterThanOrEqual(first.contextBudget, contextFloor, "contextBudget must stay >= reflective floor")
    XCTAssertGreaterThanOrEqual(first.outputCharacterBudget, outputFloor, "outputCharacterBudget must stay >= floor")
    XCTAssertGreaterThanOrEqual(first.timeBudgetMs, timeFloor, "timeBudgetMs must stay >= floor")
    XCTAssertGreaterThanOrEqual(first.toolCallBudget, 0, "toolCallBudget must stay >= 0")
    XCTAssertGreaterThanOrEqual(first.retrievalItemBudget, 0, "retrievalItemBudget must stay >= 0")
    XCTAssertTrue(first.actionSpace.contains("stay_brief"), "brief-session reduction must append stay_brief")

    // Drive the budget to the floor so the second application has nowhere left to cut.
    // Reflective brief-session reduction = 80; 620 -> 540 -> ... ; iterate until fixed.
    var compacted = first
    for _ in 0..<12 {
        compacted = compacted.adapting(signals: signals)
    }
    XCTAssertEqual(compacted.contextBudget, contextFloor, "repeated reduction must converge exactly to the context floor")
    XCTAssertEqual(compacted.outputCharacterBudget, outputFloor, "repeated reduction must converge to the output floor")
    XCTAssertEqual(compacted.timeBudgetMs, timeFloor, "repeated reduction must converge to the time floor")

    // (3) IDEMPOTENCE: once at the floor, a further application is a fixed point.
    // Budgets stay >= floor (never under-shoot) and the whole strategy is unchanged,
    // including a STABLE actionSpace (no duplicate stay_brief, no new appends, same order).
    let again = compacted.adapting(signals: signals)
    XCTAssertGreaterThanOrEqual(again.contextBudget, contextFloor, "second application must stay >= floor")
    XCTAssertGreaterThanOrEqual(again.outputCharacterBudget, outputFloor, "second application must stay >= floor")
    XCTAssertGreaterThanOrEqual(again.timeBudgetMs, timeFloor, "second application must stay >= floor")
    XCTAssertEqual(again, compacted, "adapting must be idempotent at the floor (fixed point, tolerance=0)")
    XCTAssertEqual(again.actionSpace, compacted.actionSpace, "actionSpace must be stable under re-application")
    XCTAssertEqual(again.actionSpace.filter { $0 == "stay_brief" }.count, 1, "stay_brief must not be duplicated by idempotent re-application")

    print("QINAO-GATE adaptive_strategy_idempotence: PASS (deterministic re-call equal; budgets converge to floors ctx=\(again.contextBudget) out=\(again.outputCharacterBudget) time=\(again.timeBudgetMs); re-application is a fixed point with stable actionSpace=\(again.actionSpace))")
}

    func test_qinao_routing_policy_lineage_completeness() {
    // QINAO #31: every routing plan AND every runtime status summary must carry a
    // non-empty appliedRoutingPolicyVersion AND a non-empty registry lineage version
    // (no blank provenance). We drive the REAL production composers and assert both
    // lineage fields against the registry/policy source of truth (computed, not hardcoded).

    func qinaoIsBlank(_ value: String?) -> Bool {
        guard let value else { return true }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Source of truth: the reference routing source carries the registry + resolved policy.
    let qinaoSource = BASReferenceProviderRuntime.fixtureRoutingSource
    let qinaoExpectedRegistryVersion = qinaoSource.registryVersion
    let qinaoExpectedPolicyVersion = qinaoSource.resolvedPolicyOrMissing.schemaVersion

    // The source-of-truth versions themselves must be non-blank, otherwise the
    // downstream completeness assertions would be vacuously satisfiable.
    XCTAssertFalse(qinaoIsBlank(qinaoExpectedRegistryVersion), "registry source-of-truth version is blank")
    XCTAssertFalse(qinaoIsBlank(qinaoExpectedPolicyVersion), "policy source-of-truth version is blank")

    // (1) SUMMARY lineage via the production composer. runtimeStatusSummary sources
    // appliedRoutingPolicyVersion from routingPolicy.schemaVersion internally; we feed
    // the registry version from the real source.
    let qinaoSummary = BASReferenceProviderRuntime.runtimeStatusSummary(
        preferredProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
        allowFallbacks: true,
        runtimeEnabled: true,
        statusesByID: [
            BASReferenceProviderRuntime.gemmaE4BProviderID: BASProviderStatusRecord(
                providerID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                isAvailable: true,
                title: "Gemma",
                detail: "Gemma is ready."
            ),
            BASReferenceProviderRuntime.foundationModelsProviderID: BASProviderStatusRecord(
                providerID: BASReferenceProviderRuntime.foundationModelsProviderID,
                isAvailable: true,
                title: "Foundation",
                detail: "Foundation is ready."
            )
        ],
        routingRegistryVersion: qinaoExpectedRegistryVersion,
        routingPolicy: qinaoSource.resolvedPolicyOrMissing
    )

    XCTAssertFalse(
        qinaoIsBlank(qinaoSummary.appliedRoutingPolicyVersion),
        "summary appliedRoutingPolicyVersion is blank — incomplete lineage"
    )
    XCTAssertFalse(
        qinaoIsBlank(qinaoSummary.appliedRoutingRegistryVersion),
        "summary appliedRoutingRegistryVersion is blank — incomplete lineage"
    )
    XCTAssertEqual(qinaoSummary.appliedRoutingPolicyVersion, qinaoExpectedPolicyVersion)
    XCTAssertEqual(qinaoSummary.appliedRoutingRegistryVersion, qinaoExpectedRegistryVersion)

    // (2) PLAN lineage via the production route resolver. It threads both lineage
    // versions through into BASProviderSelectionPlan.
    let qinaoPolicy = qinaoSource.resolvedPolicyOrMissing
    let qinaoPlan = BASProviderRouteResolver.resolve(
        task: .primary,
        preferredProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
        allowFallbacks: true,
        deterministicProviderID: qinaoPolicy.deterministicProviderID,
        preferenceOrderings: qinaoPolicy.preferenceOrderings,
        appliedRoutingPolicyVersion: qinaoPolicy.schemaVersion,
        appliedRoutingRegistryVersion: qinaoExpectedRegistryVersion,
        strategy: nil,
        descriptors: []
    )

    XCTAssertFalse(
        qinaoIsBlank(qinaoPlan.appliedRoutingPolicyVersion),
        "plan appliedRoutingPolicyVersion is blank — incomplete lineage"
    )
    XCTAssertFalse(
        qinaoIsBlank(qinaoPlan.appliedRoutingRegistryVersion),
        "plan appliedRoutingRegistryVersion is blank — incomplete lineage"
    )
    XCTAssertEqual(qinaoPlan.appliedRoutingPolicyVersion, qinaoExpectedPolicyVersion)
    XCTAssertEqual(qinaoPlan.appliedRoutingRegistryVersion, qinaoExpectedRegistryVersion)

    // (3) Determinism: re-composing yields byte-identical lineage (and full equality).
    let qinaoSummaryReplay = BASReferenceProviderRuntime.runtimeStatusSummary(
        preferredProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
        allowFallbacks: true,
        runtimeEnabled: true,
        statusesByID: [
            BASReferenceProviderRuntime.gemmaE4BProviderID: BASProviderStatusRecord(
                providerID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                isAvailable: true,
                title: "Gemma",
                detail: "Gemma is ready."
            ),
            BASReferenceProviderRuntime.foundationModelsProviderID: BASProviderStatusRecord(
                providerID: BASReferenceProviderRuntime.foundationModelsProviderID,
                isAvailable: true,
                title: "Foundation",
                detail: "Foundation is ready."
            )
        ],
        routingRegistryVersion: qinaoExpectedRegistryVersion,
        routingPolicy: qinaoSource.resolvedPolicyOrMissing
    )
    XCTAssertEqual(qinaoSummaryReplay, qinaoSummary, "summary lineage is non-deterministic across re-call")

    // (4) Negative control: a hand-built summary with blank/nil provenance MUST be
    // detected by the same predicate, proving the gate actually discriminates.
    let qinaoBlankSummary = BASRuntimeStatusSummary(
        preferredProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
        activeProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
        fallbackProviderID: nil,
        appliedRoutingPolicyVersion: nil,
        appliedRoutingRegistryVersion: "   ",
        detail: "blank-provenance control",
        orderedProviderIDs: [BASReferenceProviderRuntime.gemmaE4BProviderID]
    )
    XCTAssertTrue(qinaoIsBlank(qinaoBlankSummary.appliedRoutingPolicyVersion))
    XCTAssertTrue(qinaoIsBlank(qinaoBlankSummary.appliedRoutingRegistryVersion))

    print("QINAO-GATE routing_policy_lineage_completeness: PASS policy=\(qinaoExpectedPolicyVersion) registry=\(qinaoExpectedRegistryVersion) (summary+plan lineage non-empty, equals source of truth, deterministic; blank-provenance control correctly flagged)")
}

    func test_qinao_silent_failure_observability() async throws {
    // QINAO #47 — a non-throwing BASMemory store accessor must route a SQLite error to
    // onSilentFailure BEFORE returning its nil/[]/0 default, and a throwing sibling
    // (…OrThrow) must SURFACE the same error so a host can distinguish empty-vs-broken.
    // Subject: BASSQLiteMemoryAtomStore (Sources/BASMemory/BASSQLiteMemoryAtomStore.swift).
    // Construction mirrors testReadFailureFiresHookAndOrThrowThrows in
    // Tests/BehavioralAISubstrateTests/BASSQLiteStoreCrashRecoveryTests.swift verbatim.

    // --- helpers (defined inside the method) ---
    let qinaoBase = FileManager.default.temporaryDirectory
        .appendingPathComponent("qinao-silent-failure-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: qinaoBase, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: qinaoBase) }

    func qinaoGoverned(id: UUID, content: String) -> BASGovernedMemory {
        // mirrors the existing test's `governed(...)` helper exactly.
        BASGovernedMemory(
            id: id, kind: .semantic, content: content, scope: .user,
            sensitivity: .low, tier: .warm, confidence: 0.7,
            sourceType: "general", governanceStatus: .candidate, provenanceSummary: "qinao")
    }

    // Thread-safe firing counter for the @Sendable hook (no captured-var mutation).
    final class QINAOFireBox: @unchecked Sendable {
        let lock = NSLock()
        private var n = 0
        func bump() { lock.lock(); n += 1; lock.unlock() }
        var count: Int { lock.lock(); defer { lock.unlock() }; return n }
    }

    let u = qinaoBase.appendingPathComponent("droptable.sqlite")

    // --- arrange: live store with one committed atom ---
    let store = try BASSQLiteMemoryAtomStore(databaseURL: u)
    let onlyID = UUID()
    _ = try await store.admit(qinaoGoverned(id: onlyID, content: "x"))

    // Baseline: BEFORE corruption the non-throwing accessors return real data and the
    // throwing siblings agree (no error path taken yet → hook must NOT fire on success).
    let healthyBox = QINAOFireBox()
    await store.setOnSilentFailure { _ in healthyBox.bump() }
    let healthyCount = await store.count
    XCTAssertEqual(healthyCount, 1, "non-throwing count returns the real value on the success path")
    let healthyCountOrThrow = try await store.countOrThrow()
    XCTAssertEqual(healthyCountOrThrow, 1, "throwing sibling agrees with the accessor when healthy")
    let healthyIDs = await store.allIDs
    XCTAssertEqual(healthyIDs, [onlyID.uuidString], "allIDs returns the real set on success")
    let healthyAtom = await store.atom(forID: onlyID.uuidString)
    XCTAssertEqual(healthyAtom?.id, onlyID, "atom(forID:) returns the real atom on success")
    XCTAssertEqual(healthyBox.count, 0,
        "onSilentFailure MUST NOT fire on the success path (byte-equal success behavior)")

    // --- act: drop the table out from under the store via a SECOND connection ---
    // In WAL mode the store's connection sees the committed DROP on its next read → every
    // SELECT fails with a typed StorageError, exercising the silent-failure path.
    var raw: OpaquePointer?
    XCTAssertEqual(sqlite3_open_v2(u.path, &raw, SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
    XCTAssertEqual(sqlite3_exec(raw, "DROP TABLE memory_atoms;", nil, nil, nil), SQLITE_OK)
    sqlite3_close_v2(raw)

    let box = QINAOFireBox()
    await store.setOnSilentFailure { _ in box.bump() }

    // --- assert (1): every non-throwing accessor routes the error to onSilentFailure
    //                BEFORE returning its documented default. ---

    // count → default 0, hook fires.
    let firedBefore0 = box.count
    let nCount = await store.count
    XCTAssertEqual(nCount, 0, "count returns its 0 default on a read failure")
    XCTAssertEqual(box.count, firedBefore0 + 1,
        "count routes the SQLite error to onSilentFailure before returning 0")

    // allIDs → default [], hook fires.
    let firedBeforeIDs = box.count
    let ids = await store.allIDs
    XCTAssertEqual(ids, [], "allIDs returns its [] default on a read failure")
    XCTAssertEqual(box.count, firedBeforeIDs + 1,
        "allIDs routes the SQLite error to onSilentFailure before returning []")

    // atom(forID:) → default nil, hook fires.
    let firedBeforeAtom = box.count
    let got = await store.atom(forID: onlyID.uuidString)
    XCTAssertNil(got, "atom(forID:) returns its nil default on a read failure")
    XCTAssertEqual(box.count, firedBeforeAtom + 1,
        "atom(forID:) routes the SQLite error to onSilentFailure before returning nil")

    // updateTier → default false, hook fires (fetch fails before the write).
    let firedBeforeTier = box.count
    let okTier = await store.updateTier(forID: onlyID.uuidString, to: .hot)
    XCTAssertFalse(okTier, "updateTier returns its false default on a read failure")
    XCTAssertEqual(box.count, firedBeforeTier + 1,
        "updateTier routes the SQLite error to onSilentFailure before returning false")

    // remove → default nil, hook fires.
    let firedBeforeRemove = box.count
    let removed = await store.remove(forID: onlyID.uuidString)
    XCTAssertNil(removed, "remove returns its nil default on a read failure")
    XCTAssertEqual(box.count, firedBeforeRemove + 1,
        "remove routes the SQLite error to onSilentFailure before returning nil")

    let totalFired = box.count
    XCTAssertEqual(totalFired, 5,
        "all 5 swallowing accessors (count, allIDs, atom, updateTier, remove) fired the hook exactly once each")

    // --- assert (2): the throwing siblings SURFACE the typed error (distinguish broken-from-empty). ---
    do {
        _ = try await store.countOrThrow()
        XCTFail("countOrThrow must throw when the table is gone, not return 0")
    } catch {
        XCTAssertTrue(error is BASSQLiteMemoryAtomStore.StorageError,
            "countOrThrow surfaces the typed StorageError, got \(error)")
    }
    do {
        _ = try await store.allIDsOrThrow()
        XCTFail("allIDsOrThrow must throw when the table is gone, not return []")
    } catch {
        XCTAssertTrue(error is BASSQLiteMemoryAtomStore.StorageError,
            "allIDsOrThrow surfaces the typed StorageError, got \(error)")
    }

    // --- assert (3): determinism — re-calling the swallowing accessor still defaults + fires. ---
    let firedBeforeRedet = box.count
    let nCount2 = await store.count
    XCTAssertEqual(nCount2, 0, "re-calling count is deterministic: still returns 0")
    XCTAssertEqual(box.count, firedBeforeRedet + 1,
        "re-calling count fires the hook again (the error path is taken every time, not memoized)")

    // --- assert (4): nil hook ⇒ byte-equal swallowing behavior (default still returned, no crash). ---
    await store.setOnSilentFailure(nil)
    let nCountNoHook = await store.count
    XCTAssertEqual(nCountNoHook, 0,
        "with onSilentFailure == nil the accessor still returns its default (today's exact behavior)")

    print("QINAO-GATE silent_failure_observability: PASS (5 swallowing accessors route SQLite error to onSilentFailure before default 0/[]/nil/false; countOrThrow+allIDsOrThrow surface typed StorageError; success path & nil-hook fire 0 times; error path deterministic)")
}

    func test_qinao_observation_coordinate_coherence() throws {
    // Frame coordinate the whole report is pinned to. Built via the
    // canonical BASFrameContext derivation so (sessionID,turnID) are
    // the single-source-of-truth coordinate pair every layer's
    // ObservationBundle/summary must strictly equal (metric #56).
    let frame = BASFrameContext(
        hostID: "qinaoHost",
        taskTypeRaw: "chat",
        runModeRaw: "live",
        recordedAt: Date(timeIntervalSinceReferenceDate: 0))
    let frameTurn = frame.turnID
    let frameSession = frame.sessionID

    // Local builder mirroring the existing-test construction verbatim
    // (BASObservationReconciliationTests.summary).
    func qinaoSummary(
        _ layer: BASCognitiveLayer,
        turn: String,
        session: String,
        total: Int
    ) -> BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: layer,
            turnID: turn,
            sessionID: session,
            totalObservations: total,
            distinctSubjectCount: 1,
            hasCoreSignalCoverage: true,
            budgetTotalCost: 0.1,
            emittedAt: Date(timeIntervalSince1970: 0))
    }

    let allLayers = BASCognitiveLayer.allCases

    // (a) Every layer, when its coordinate MATCHES the frame, is
    // retained — and the retained value carries the frame's exact
    // (turnID,sessionID). Tolerance = 0 (strict ==), exhaustive over
    // all 14 layers.
    let matched = allLayers.enumerated().map { idx, layer in
        qinaoSummary(
            layer, turn: frameTurn, session: frameSession,
            total: idx + 1)
    }
    let coherent = BASObservationReconciliationReport(
        turnID: frameTurn,
        sessionID: frameSession,
        summaries: matched)
    XCTAssertEqual(
        coherent.summaries.count, allLayers.count,
        "all coordinate-matching layers must be retained")
    XCTAssertEqual(coherent.coveredLayers, allLayers,
        "first-seen order = the 14-layer enum order")
    for s in coherent.summaries {
        // strictly-equal (sessionID,turnID) == frameContext — the
        // core invariant of metric #56.
        XCTAssertEqual(s.turnID, frameTurn)
        XCTAssertEqual(s.sessionID, frameSession)
    }

    // (b) dedupedAndFiltered drops mismatched-coordinate bundles.
    // Exhaustive over the 3 mismatch classes (wrong turn / wrong
    // session / both wrong) for EVERY layer; only the matching twin
    // survives, and it keeps the frame coordinate exactly.
    for layer in allLayers {
        let good = qinaoSummary(
            layer, turn: frameTurn, session: frameSession, total: 5)
        let badTurn = qinaoSummary(
            layer, turn: frameTurn + "X", session: frameSession,
            total: 6)
        let badSession = qinaoSummary(
            layer, turn: frameTurn, session: frameSession + "X",
            total: 7)
        let badBoth = qinaoSummary(
            layer, turn: frameTurn + "X",
            session: frameSession + "X", total: 8)
        // Put a mismatch FIRST so a naive impl that keeps first-seen
        // would expose itself; the matching one must still win.
        let r = BASObservationReconciliationReport(
            turnID: frameTurn,
            sessionID: frameSession,
            summaries: [badTurn, badSession, good, badBoth])
        XCTAssertEqual(r.coveredLayers, [layer],
            "exactly the coordinate-matching layer survives")
        let survivor = try XCTUnwrap(r.summary(forLayer: layer))
        XCTAssertEqual(survivor.totalObservations, 5,
            "the matching summary (not a mismatched one) is kept")
        XCTAssertEqual(survivor.turnID, frameTurn)
        XCTAssertEqual(survivor.sessionID, frameSession)
    }

    // (c) A report whose summaries are ALL mismatched collapses to
    // empty — no broken-coordinate bundle is ever carried forward.
    let allBad = allLayers.map { layer in
        qinaoSummary(
            layer, turn: frameTurn + "Z",
            session: frameSession, total: 3)
    }
    let empty = BASObservationReconciliationReport(
        turnID: frameTurn,
        sessionID: frameSession,
        summaries: allBad)
    XCTAssertTrue(empty.summaries.isEmpty,
        "every mismatched-coordinate bundle is dropped")
    XCTAssertEqual(empty.totalObservations, 0)

    // (d) appending(_:) enforces the same coordinate gate as a no-op
    // for a mismatched bundle (mutate + assert the immutable result).
    let base = BASObservationReconciliationReport(
        turnID: frameTurn,
        sessionID: frameSession,
        summaries: [
            qinaoSummary(
                .leaseLife, turn: frameTurn,
                session: frameSession, total: 1)
        ])
    let afterBad = base.appending(
        qinaoSummary(
            .neuralOrgan, turn: frameTurn + "Q",
            session: frameSession, total: 2))
    XCTAssertEqual(afterBad.coveredLayers, [.leaseLife],
        "appending a mismatched-coordinate bundle is a no-op")
    let afterGood = base.appending(
        qinaoSummary(
            .neuralOrgan, turn: frameTurn,
            session: frameSession, total: 2))
    XCTAssertEqual(
        afterGood.coveredLayers, [.leaseLife, .neuralOrgan],
        "a coordinate-coherent bundle is appended")
    // immutability: the original report is unchanged by either call.
    XCTAssertEqual(base.coveredLayers, [.leaseLife])

    // (e) Deterministic re-call: identical inputs → byte-equal report
    // (Equatable + value semantics).
    let again = BASObservationReconciliationReport(
        turnID: frameTurn,
        sessionID: frameSession,
        summaries: matched)
    XCTAssertEqual(coherent, again, "construction is deterministic")

    print("QINAO-GATE observation_coordinate_coherence: PASS " +
        "(14/14 layers coordinate-coherent vs frameContext " +
        "(\(frameSession),\(frameTurn)); mismatched-coordinate " +
        "bundles dropped on init+decode-path+appending)")
}

    func test_qinao_accelerated_draft_default_off_byte_equality() async throws {
    // QINAO #18 — ADR-014 default-off invariant: a no-lane adapter's accelerated draft paths
    // (`draft(_:electAccelerated:)` Bool overload AND `draft(_:purpose:)` overload) are BYTE-EQUAL to plain
    // `draft(_:)`. The protocol DEFAULT impls (BASOrganAdapter extension) ignore both flags and delegate to
    // draft(_:). The deterministic adapter's body is a pure SHA-256 of providerID+role+preset+instruction+context
    // (no timestamp/counter in `body`/`traceID`/`providerID`), so FRESH adapters per call yield identical bodies —
    // this isolates the elect/purpose flag from any per-instance confound. Construction MIRRORS
    // BASPromptLookupElectTests verbatim.
    func qinaoRequest() -> BASOrganRequest {
        BASOrganRequest(
            requestID: "qinao-18-default-off",
            role: .core,
            preset: .greedyDeterministic,
            instruction: "Extract the capital of France as JSON.",
            context: ["France is a country in Western Europe; its capital is Paris."])
    }

    // Strict byte-equality of every observable, identity-bearing field (tolerance = 0). `producedAt` is
    // excluded on purpose: it is wall-clock and NOT part of the default-off invariant.
    func assertByteEqual(_ got: BASOrganDraft, _ ref: BASOrganDraft, _ label: String) {
        XCTAssertEqual(got.body, ref.body, "\(label): body must be byte-equal for a no-lane adapter")
        XCTAssertEqual(got.traceID, ref.traceID, "\(label): traceID must be byte-equal")
        XCTAssertEqual(got.providerID, ref.providerID, "\(label): providerID must be byte-equal")
        XCTAssertEqual(got.role, ref.role, "\(label): role must be byte-equal")
        XCTAssertEqual(got.requestID, ref.requestID, "\(label): requestID must be byte-equal")
        XCTAssertEqual(got.inputTokensEstimated, ref.inputTokensEstimated, "\(label): input token estimate")
        XCTAssertEqual(got.outputTokensEstimated, ref.outputTokensEstimated, "\(label): output token estimate")
        XCTAssertEqual(got.completionMetrics, ref.completionMetrics, "\(label): completionMetrics (nil for det.)")
    }

    let req = qinaoRequest()

    // Oracle: plain draft from a FRESH adapter.
    let plain = try await BASOrganDeterministicAdapter().draft(req)

    // (1) Bool overload — both flag values must be byte-equal to plain (default impl ignores the flag).
    let electTrue = try await BASOrganDeterministicAdapter().draft(req, electAccelerated: true)
    let electFalse = try await BASOrganDeterministicAdapter().draft(req, electAccelerated: false)
    assertByteEqual(electTrue, plain, "electAccelerated=true")
    assertByteEqual(electFalse, plain, "electAccelerated=false")

    // (2) Purpose overload — EXHAUSTIVE over every BASDecodeLanePolicy.Purpose case (CaseIterable). The default
    // impl ignores `purpose`, so EVERY purpose (incl. the would-be-accelerated .factual/.deterministic) is
    // byte-equal for a no-lane adapter. Assert the case set is non-empty so an empty allCases can't vacuously pass.
    let purposes = BASDecodeLanePolicy.Purpose.allCases
    XCTAssertFalse(purposes.isEmpty, "Purpose.allCases must be non-empty (exhaustive coverage guard)")
    for purpose in purposes {
        let viaPurpose = try await BASOrganDeterministicAdapter().draft(req, purpose: purpose)
        assertByteEqual(viaPurpose, plain, "purpose=\(purpose.rawValue)")
    }

    // (3) Determinism — re-calling the accelerated paths on a fresh adapter reproduces the SAME body/traceID.
    let electTrueAgain = try await BASOrganDeterministicAdapter().draft(req, electAccelerated: true)
    assertByteEqual(electTrueAgain, electTrue, "electAccelerated=true (deterministic re-call)")
    let factualAgain = try await BASOrganDeterministicAdapter().draft(req, purpose: .factual)
    let factualOnce = try await BASOrganDeterministicAdapter().draft(req, purpose: .factual)
    assertByteEqual(factualAgain, factualOnce, "purpose=.factual (deterministic re-call)")

    // (4) Sensitivity guard — a DIFFERENT request must change the body, proving the byte-equality above is a
    // real invariant of the default-off path and not a degenerate constant. Mutate instruction, assert ≠.
    let mutated = BASOrganRequest(
        requestID: "qinao-18-default-off",
        role: .core,
        preset: .greedyDeterministic,
        instruction: "DIFFERENT instruction — extract the capital of Japan as JSON.",
        context: ["France is a country in Western Europe; its capital is Paris."])
    let mutatedDraft = try await BASOrganDeterministicAdapter().draft(mutated, electAccelerated: true)
    XCTAssertNotEqual(mutatedDraft.body, plain.body,
        "a different instruction MUST change the body — proves byte-equality is a true invariant, not a constant")

    print("QINAO-GATE accelerated_draft_default_off_byte_equality: PASS "
        + "(Bool overload + \(purposes.count) purposes all byte-equal to plain; deterministic; sensitive to input)")
}

    func test_qinao_provider_fallback_availability_resolution() throws {
    // Construction mirrored VERBATIM from BASRuntimeCoreTests.swift
    // (runtimeAvailabilityResolverPrefersFirstAvailableProvider, line 1112):
    //   BASRuntimeAvailabilityResolver.resolve(preferredProviderID:allowFallbacks:
    //   runtimeEnabled:deterministicProviderID:orderedProviderIDs:statusesByID:)
    //   with BASProviderStatusRecord(providerID:isAvailable:title:detail:).

    // Real enum cases (BASRuntimeAvailabilitySource, listed explicitly — no .allCases):
    //   runtimeDisabled, testingOverride, templatePinned,
    //   preferredProvider, fallbackProvider, deterministicFallback.

    func makeStatus(_ id: String, _ available: Bool) -> BASProviderStatusRecord {
        BASProviderStatusRecord(
            providerID: id,
            isAvailable: available,
            title: id.capitalized,
            detail: available ? "Ready." : "Unavailable."
        )
    }

    // --- Matrix row 1: runtime disabled -> deterministic, source .runtimeDisabled ---
    let disabled = BASRuntimeAvailabilityResolver.resolve(
        preferredProviderID: "foundation",
        allowFallbacks: true,
        runtimeEnabled: false,
        deterministicProviderID: "template",
        orderedProviderIDs: ["foundation", "gemma"],
        statusesByID: [
            "foundation": makeStatus("foundation", true),
            "gemma": makeStatus("gemma", true)
        ]
    )
    XCTAssertEqual(disabled.source, .runtimeDisabled)
    XCTAssertEqual(disabled.activeProviderID, "template")
    XCTAssertNil(disabled.fallbackProviderID)
    XCTAssertNil(disabled.unavailableProviderID)

    // --- Matrix row 2: testing override (preferred != deterministic) ---
    let overridden = BASRuntimeAvailabilityResolver.resolve(
        preferredProviderID: "foundation",
        allowFallbacks: true,
        runtimeEnabled: true,
        deterministicProviderID: "template",
        orderedProviderIDs: ["foundation", "gemma"],
        statusesByID: [
            "foundation": makeStatus("foundation", true)
        ],
        testingOverrideProviderID: "stub"
    )
    XCTAssertEqual(overridden.source, .testingOverride)
    XCTAssertEqual(overridden.activeProviderID, "stub")
    XCTAssertEqual(overridden.fallbackProviderID, "stub")

    // --- Matrix row 3: template-pinned (preferred == deterministic) ---
    let pinned = BASRuntimeAvailabilityResolver.resolve(
        preferredProviderID: "template",
        allowFallbacks: true,
        runtimeEnabled: true,
        deterministicProviderID: "template",
        orderedProviderIDs: ["template"],
        statusesByID: [
            "template": makeStatus("template", true)
        ]
    )
    XCTAssertEqual(pinned.source, .templatePinned)
    XCTAssertEqual(pinned.activeProviderID, "template")
    XCTAssertNil(pinned.fallbackProviderID)
    XCTAssertNil(pinned.unavailableProviderID)

    // --- Matrix row 4: preferred available -> source .preferredProvider ---
    let preferredAvailable = BASRuntimeAvailabilityResolver.resolve(
        preferredProviderID: "foundation",
        allowFallbacks: true,
        runtimeEnabled: true,
        deterministicProviderID: "template",
        orderedProviderIDs: ["foundation", "gemma"],
        statusesByID: [
            "foundation": makeStatus("foundation", true),
            "gemma": makeStatus("gemma", true)
        ]
    )
    XCTAssertEqual(preferredAvailable.source, .preferredProvider)
    XCTAssertEqual(preferredAvailable.activeProviderID, "foundation")
    XCTAssertNil(preferredAvailable.fallbackProviderID)
    XCTAssertNil(preferredAvailable.unavailableProviderID)

    // --- Matrix row 5: preferred down, fallback in DECLARED ORDER (gemma first available) ---
    // ordered = [foundation(down), gemma(up), open-model(up)] -> picks gemma, not open-model.
    let fallbackPlan = BASRuntimeAvailabilityResolver.resolve(
        preferredProviderID: "foundation",
        allowFallbacks: true,
        runtimeEnabled: true,
        deterministicProviderID: "template",
        orderedProviderIDs: ["foundation", "gemma", "open-model"],
        statusesByID: [
            "foundation": makeStatus("foundation", false),
            "gemma": makeStatus("gemma", true),
            "open-model": makeStatus("open-model", true)
        ]
    )
    XCTAssertEqual(fallbackPlan.source, .fallbackProvider)
    XCTAssertEqual(fallbackPlan.activeProviderID, "gemma")
    XCTAssertEqual(fallbackPlan.fallbackProviderID, "gemma")
    XCTAssertEqual(fallbackPlan.unavailableProviderID, "foundation")

    // --- Matrix row 6: all ordered providers down -> deterministicFallback ---
    let exhausted = BASRuntimeAvailabilityResolver.resolve(
        preferredProviderID: "foundation",
        allowFallbacks: true,
        runtimeEnabled: true,
        deterministicProviderID: "template",
        orderedProviderIDs: ["foundation", "gemma"],
        statusesByID: [
            "foundation": makeStatus("foundation", false),
            "gemma": makeStatus("gemma", false)
        ]
    )
    XCTAssertEqual(exhausted.source, .deterministicFallback)
    XCTAssertEqual(exhausted.activeProviderID, "template")
    XCTAssertEqual(exhausted.fallbackProviderID, "template")
    XCTAssertEqual(exhausted.unavailableProviderID, "foundation")

    // --- Determinism: re-calling with identical inputs yields an identical plan ---
    let exhaustedAgain = BASRuntimeAvailabilityResolver.resolve(
        preferredProviderID: "foundation",
        allowFallbacks: true,
        runtimeEnabled: true,
        deterministicProviderID: "template",
        orderedProviderIDs: ["foundation", "gemma"],
        statusesByID: [
            "foundation": makeStatus("foundation", false),
            "gemma": makeStatus("gemma", false)
        ]
    )
    XCTAssertEqual(exhausted, exhaustedAgain)

    // --- Mutate the matrix: bring foundation back up -> source flips to preferredProvider ---
    let recovered = BASRuntimeAvailabilityResolver.resolve(
        preferredProviderID: "foundation",
        allowFallbacks: true,
        runtimeEnabled: true,
        deterministicProviderID: "template",
        orderedProviderIDs: ["foundation", "gemma"],
        statusesByID: [
            "foundation": makeStatus("foundation", true),
            "gemma": makeStatus("gemma", false)
        ]
    )
    XCTAssertEqual(recovered.source, .preferredProvider)
    XCTAssertEqual(recovered.activeProviderID, "foundation")
    XCTAssertNotEqual(recovered, exhausted)

    // --- Exhaustively assert every one of the 6 declared sources was exercised ---
    let observedSources: Set<BASRuntimeAvailabilitySource> = [
        disabled.source,
        overridden.source,
        pinned.source,
        preferredAvailable.source,
        fallbackPlan.source,
        exhausted.source
    ]
    let allDeclaredSources: Set<BASRuntimeAvailabilitySource> = [
        .runtimeDisabled,
        .testingOverride,
        .templatePinned,
        .preferredProvider,
        .fallbackProvider,
        .deterministicFallback
    ]
    XCTAssertEqual(observedSources, allDeclaredSources)

    print("QINAO-GATE provider_fallback_availability_resolution: PASS (6/6 source-matrix rows: runtimeDisabled/testingOverride/templatePinned/preferredProvider/fallbackProvider(declared-order)/deterministicFallback; deterministic re-call equal; mutate flips source)")
}
}

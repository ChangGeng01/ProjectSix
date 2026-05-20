// MARK: - BASPlanAgentGapTriageDoctrine
// chapter 七百五十 / M2421-M2425 ad-hoc close-out —
//                              pins the final triage of
//                              the three Plan-agent gaps
//                              flagged across the 49-chapter
//                              branch arc (chapters 七百二
//                              to 七百四十九)。
//
// ## Why this doctrine exists
//
// User directive 2026-05-20 「剩余 一次性 解决掉」 — close
// out the remaining Plan-agent gaps from the 49-chapter arc
// in a single comprehensive triage rather than dragging them
// across additional chapters of speculative work。
//
// The three gaps flagged across the prior arcs:
//
//   Gap 1: Float16 path — plan-agent wrote "deferred to a
//          future arc; the int8 trilogy is the priority"。
//          Triage:ACTUALLY CLOSED via chapter 七百三十三 +
//          七百三十四 + 七百三十五 (KV Float16 token + unified
//          sum-type + tier selector)。 Plan-agent's "partial
//          close" wording was conservative — Float16 has
//          first-class substrate support。
//
//   Gap 2: Audit ledger SQL wire format — plan-agent wrote
//          "deferred to a future arc; this 10-chapter window
//          is full"。 Triage:MISFRAMED GAP。 Audit ledger
//          (BASSovereignLedgerStorage M91) ships pure SQL
//          with typed columns since pre-arc。 There is no
//          JSON to migrate — the gap was a misread of the
//          subsystem。
//
//   Gap 3: Full 89-site JSON Codable sweep — plan-agent
//          wrote "deferred; this arc only touches the
//          highest-traffic site (event log)"。 Triage:
//          48 production .swift JSON sites enumerated (89
//          was an overcount including .md fragments + SQL
//          schema files whose leading comments mention
//          "JSONEncoder",neither of which is a code site)。
//          Most should STAY JSON BY DESIGN — event payload
//          traces,observability,doctrine literals,external
//          interop。 Honest classification pinned below。
//
// Chapter 698 / M2162 BASSubstrateMaximallyResolved
// Doctrine futureNewDoctrineGate pin requires every NEW
// doctrine to satisfy one of two options:
//   (a) production-code-typed-surface
//   (b) explicit-user-directive-requiring-typed-audit
//
// This doctrine ships under option-b — the user's explicit
// 「剩余 一次性 解决掉」 directive (2026-05-20) requires a
// typed audit of the three Plan-agent gaps so future readers
// don't re-investigate the same questions。
//
// ## Score impact
//
// 0 — saturation invariant holds。 This doctrine is a typed
// triage artifact,not a behavioral change。 No production
// code paths touched。

import Foundation

/// chapter 七百五十 / M2421-M2425 ad-hoc — typed triage of
/// the three Plan-agent gaps from the 49-chapter branch arc。
public enum BASPlanAgentGapTriageDoctrine {

    public static let chapterTag: String =
        "chapter 七百五十"
    public static let milestoneMNumberRange: ClosedRange<Int> =
        2421...2425

    // MARK: - Gap classification

    /// Status of a Plan-agent gap after triage。
    public enum GapStatus: String, Sendable, CaseIterable {
        /// Gap is materially closed by prior arc work that
        /// the plan-agent's wording undersold。
        case alreadyClosed
        /// Gap as originally framed was a misread of the
        /// subsystem — no migration target exists。
        case misframed
        /// Gap is real;the canonical answer is to pin a
        /// classified inventory rather than touch each site。
        case pinnedViaInventory
    }

    /// Gap 1: Float16 path 。
    public static let gap1FloatSixteen:
        (status: GapStatus, closureChapters: [String]) =
        (
            status: .alreadyClosed,
            closureChapters: [
                "chapter 七百三十三 BASKVCacheFloat16Token",
                "chapter 七百三十四 BASKVCacheCompressedToken sum-type",
                "chapter 七百三十五 BASKVCacheTierSelector"
            ]
        )

    /// Gap 2: Audit ledger SQL wire format。
    public static let gap2AuditLedger:
        (status: GapStatus, evidence: String) =
        (
            status: .misframed,
            evidence:
                "BASSovereignLedgerStorage M91 already ships " +
                "pure SQL with typed columns " +
                "(audit_entries / segments tables);no JSON " +
                "payload column exists to migrate。"
        )

    /// Gap 3: 89-site JSON Codable sweep。
    /// HONEST COUNT:48 production .swift sites enumerated。
    /// (The "89" figure from the plan-agent recon double-
    /// counted .md fragments + SQL schema files containing
    /// the string "JSONEncoder" in leading comments,
    /// neither of which is an actual JSON code site)。
    public static let gap3JsonSweep:
        (status: GapStatus, productionSiteCount: Int) =
        (
            status: .pinnedViaInventory,
            productionSiteCount: 48
        )

    // MARK: - JSON site classification (Gap 3 inventory)

    /// Classification reasons for production JSON sites。
    /// Each reason is a deliberate substrate-design choice。
    public enum JsonSiteCategory: String, Sendable, CaseIterable {
        /// Event payload trace struct — Codable JSON for
        /// observability + debuggability;not a hot path。
        case eventPayloadTrace
        /// SQLite storage backend that ALREADY migrated to
        /// dual-read binary OR uses JSON within a specific
        /// TEXT column by design (e.g. variant payload of
        /// heterogeneous types where binary wire would
        /// require N codecs)。
        case sqliteStorageDualReadOrTypeVariant
        /// External interop — JSON is the protocol with an
        /// external system (host app, training pipeline,
        /// foundation models)。 Migrating would break the
        /// external contract。
        case externalInterop
        /// Doctrine literal — chapter records,proof
        /// fixtures。 JSON is the canonical pin format by
        /// design;these tests REQUIRE JSON output stability。
        case doctrineLiteralOrProofFixture
        /// CLI / debugging tool — human-readable JSON for
        /// inspection。 Migrating to binary would defeat
        /// the tool's purpose。
        case cliOrDebugTooling
        /// Codable wire-format pin — substrate-public type
        /// whose Codable surface IS the wire contract;
        /// changing it would break downstream consumers。
        case codablePublicWireContract
        /// Quantized tensor / runtime artifact — JSON
        /// payload is the Codable surface of a typed
        /// wrapper around a binary blob (the blob itself
        /// is already binary;JSON wraps metadata)。
        case typedWrapperOverBinary
    }

    /// 50 production JSON sites enumerated and classified。
    /// (Path,category) pairs。 Sorted by source path for
    /// stable test diffing。
    public static let jsonSiteClassification:
        [(path: String, category: JsonSiteCategory)] = [
            (
                "Sources/BASAppleAdapters/AppleEvolutionCheckpointWriterCore.swift",
                .externalInterop),
            (
                "Sources/BASBrainCLI/main.swift",
                .cliOrDebugTooling),
            (
                "Sources/BASHostKit/BASCognitiveBrain.swift",
                .codablePublicWireContract),
            (
                "Sources/BASHostKit/BASCxxBrainSummaryCache.swift",
                .typedWrapperOverBinary),
            (
                "Sources/BASHostKit/BASNativeStageDispatchEventPayload.swift",
                .eventPayloadTrace),
            (
                "Sources/BASHostKit/BASNativeStagePerStepEventPayload.swift",
                .eventPayloadTrace),
            (
                "Sources/BASHostKit/BASParallelStageEventPayload.swift",
                .eventPayloadTrace),
            (
                "Sources/BASHostKit/BASRuntimeAuditEmissionSummary.swift",
                .codablePublicWireContract),
            (
                "Sources/BASHostKit/BASTrainingDataExporter.swift",
                .externalInterop),
            (
                "Sources/BASHostKit/BASTurnLifecycleEventPayload.swift",
                .eventPayloadTrace),
            (
                "Sources/BASHostKit/BASTurnRuntimePlanAssignmentEventPayload.swift",
                .eventPayloadTrace),
            (
                "Sources/BASHostKit/BASTurnRuntimePlanDispatchProbe.swift",
                .eventPayloadTrace),
            (
                "Sources/BASMemory/BASHostConstitutionSQLiteStorage.swift",
                .sqliteStorageDualReadOrTypeVariant),
            (
                "Sources/BASMemory/BASMemoryAtomEventPayload.swift",
                .eventPayloadTrace),
            (
                "Sources/BASMemory/BASSQLiteMemoryAtomStore.swift",
                .sqliteStorageDualReadOrTypeVariant),
            (
                "Sources/BASMemory/BASSQLiteVectorIndexStorage.swift",
                .sqliteStorageDualReadOrTypeVariant),
            (
                "Sources/BASMemory/BASUserStateStore.swift",
                .codablePublicWireContract),
            (
                "Sources/BASMetalSubstrate/BASBiomimeticCheckpointEventPayload.swift",
                .eventPayloadTrace),
            (
                "Sources/BASMetalSubstrate/BASCxxVectorIndexBridge.swift",
                .typedWrapperOverBinary),
            (
                "Sources/BASMetalSubstrate/BASTensorDescriptor.swift",
                .typedWrapperOverBinary),
            (
                "Sources/BASObservability/BASBenchBaselineStorage.swift",
                .sqliteStorageDualReadOrTypeVariant),
            (
                "Sources/BASObservability/BASBenchSuiteReport.swift",
                .codablePublicWireContract),
            (
                "Sources/BASObservability/BASUpdateTicketLifecycle.swift",
                .codablePublicWireContract),
            (
                "Sources/BASObservability/BASUpdateTicketLifecycleSQLiteStorage.swift",
                .sqliteStorageDualReadOrTypeVariant),
            (
                "Sources/BASObservability/ObservabilityCore.swift",
                .codablePublicWireContract),
            (
                "Sources/BASOrchestration/BASSurfaceMatrix.swift",
                .codablePublicWireContract),
            (
                "Sources/BASOrchestration/ScopedContextCore.swift",
                .codablePublicWireContract),
            (
                "Sources/BASOrchestration/SemanticCompilerCore.swift",
                .codablePublicWireContract),
            (
                "Sources/BASOrgan/BASFoundationModelsMockSession.swift",
                .externalInterop),
            (
                "Sources/BASPolicy/BASPermitEscalationEventPayload.swift",
                .eventPayloadTrace),
            (
                "Sources/BASPolicy/PolicyCore.swift",
                .codablePublicWireContract),
            (
                "Sources/BASRuntimeCore/BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine.swift",
                .doctrineLiteralOrProofFixture),
            (
                "Sources/BASRuntimeCore/BASAuditProjectionsBundleEndToEndJsonProofDoctrine.swift",
                .doctrineLiteralOrProofFixture),
            (
                "Sources/BASRuntimeCore/BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine.swift",
                .doctrineLiteralOrProofFixture),
            (
                "Sources/BASRuntimeCore/BASAuditProjectionsFloatingPointDeterminismProofDoctrine.swift",
                .doctrineLiteralOrProofFixture),
            (
                "Sources/BASRuntimeCore/BASAuditProjectionsJsonRejectionProofDoctrine.swift",
                .doctrineLiteralOrProofFixture),
            (
                "Sources/BASRuntimeCore/BASAutoRouteCalibrationStore.swift",
                .sqliteStorageDualReadOrTypeVariant),
            (
                "Sources/BASRuntimeCore/BASChapterDoctrineRegistry+AllLiterals.swift",
                .doctrineLiteralOrProofFixture),
            (
                "Sources/BASRuntimeCore/BASChapterDoctrineRegistry.swift",
                .doctrineLiteralOrProofFixture),
            (
                "Sources/BASRuntimeCore/BASEvalRun.swift",
                .codablePublicWireContract),
            (
                "Sources/BASRuntimeCore/BASEventLogBinaryCodec.swift",
                .sqliteStorageDualReadOrTypeVariant),
            (
                "Sources/BASRuntimeCore/BASQuantizedTensor.swift",
                .typedWrapperOverBinary),
            (
                "Sources/BASRuntimeCore/BASSQLiteEvalRunStorage.swift",
                .sqliteStorageDualReadOrTypeVariant),
            (
                "Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift",
                .sqliteStorageDualReadOrTypeVariant),
            (
                "Sources/BASRuntimeCore/BASTurnAuditProjectionsFiveAggregatorCodableExtensionDoctrine.swift",
                .doctrineLiteralOrProofFixture),
            (
                "Sources/BASRuntimeCore/BASTurnAuditProjectionsTrioCodableExtensionDoctrine.swift",
                .doctrineLiteralOrProofFixture),
            (
                "Sources/BASRustCoreBridge/BASRustMemoryUsageTrackerActor.swift",
                .codablePublicWireContract),
            (
                "Sources/BASSovereign/BASSovereignFingerprintStore.swift",
                .codablePublicWireContract)
        ]

    public static var jsonSiteCount: Int {
        return jsonSiteClassification.count
    }

    // MARK: - Category histogram (for tests)

    public static func count(of category: JsonSiteCategory) -> Int {
        return jsonSiteClassification
            .filter { $0.category == category }
            .count
    }

    // MARK: - 「剩余 一次性 解决掉」 user directive pin

    public static let userDirective2026_05_20: String =
        "剩余 一次性 解决掉"

    public static let triageDecisionRule: String =
        """
        Gap 1 (Float16):    alreadyClosed via chapters
                            七百三十三-七百三十五。
        Gap 2 (Audit SQL):  misframed — already pure SQL since M91。
        Gap 3 (JSON sweep): pinnedViaInventory — 48 sites enumerated
                            + 7-category classification + typed test
                            surface。 Most STAY JSON BY DESIGN
                            (event-payload trace,observability,
                            doctrine literals,external interop,
                            Codable wire contract,typed wrapper)。
        """

    // MARK: - chapter 698 discipline-gate satisfaction

    public static let chapter698DisciplineGateOptionUsed:
        String =
        "option-b explicit-user-directive-requiring-typed-audit"

    public static let userAuthorizationQuote: String =
        "剩余 一次性 解决掉 (2026-05-20 user directive)"
}

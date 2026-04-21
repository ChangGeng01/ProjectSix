import XCTest
@testable import BASRuntimeCore
@testable import BASSovereign

/// Tests for `BR-05` VerdictEngine.
///
/// One test per BR hard rule, plus lex-order soft-signal tests, plus
/// evidence-insufficient upgrade, plus BR-012 fail-closed on ledger
/// failure. These are the tests that prove "神经不掌权" isn't just a
/// slogan — each rejection path here corresponds to a specific
/// sovereign guarantee that would otherwise be a promise with no
/// enforcement.
final class BASSovereignVerdictEngineTests: XCTestCase {
    private func makeEngine(seed: String = "verdict-engine-test") -> (engine: BASSovereignVerdictEngine, ledger: BASSovereignAuditLedger) {
        let ledger = BASSovereignAuditLedger.withSeed(seed)
        let engine = BASSovereignVerdictEngine(ledger: ledger)
        return (engine, ledger)
    }

    private func ctx(
        operation: BASSovereignVerdictEngine.OperationDomain = .pureInference,
        hard: BASSovereignVerdictEngine.HardObservations = .clean,
        soft: BASSovereignVerdictEngine.SoftSignals = .calm,
        evidence: Bool = true
    ) -> BASSovereignVerdictEngine.VerdictContext {
        BASSovereignVerdictEngine.VerdictContext(
            sessionID: "S1",
            turnID: "T1",
            operation: operation,
            hardObservations: hard,
            softSignals: soft,
            evidenceSufficient: evidence,
            snapshotRef: "snap-1"
        )
    }

    // MARK: - Happy path

    func testCleanObservationsProducePassVerdict() async throws {
        let (engine, ledger) = makeEngine()
        let verdict = try await engine.evaluate(ctx())

        XCTAssertEqual(verdict.verdictLevel, .pass)
        XCTAssertFalse(verdict.latched)
        XCTAssertNil(verdict.forcedMode)
        XCTAssertEqual(verdict.reasonCodes, [])
        XCTAssertEqual(verdict.userStubMode, .none)
        XCTAssertNotNil(verdict.auditRef)

        let auditCount = await ledger.count()
        XCTAssertEqual(auditCount, 1, "every verdict must append exactly one audit entry")
    }

    // MARK: - Hard rules BR-001..BR-012

    func testBR001ArtifactSignatureInvalidEmitsDeadStop() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            hard: .init(artifactSignatureInvalid: true)
        ))
        XCTAssertEqual(verdict.verdictLevel, .deadStop)
        XCTAssertTrue(verdict.reasonCodes.contains("BR-001"))
        XCTAssertTrue(verdict.latched)
        XCTAssertEqual(verdict.forcedMode, .lockdown)
        XCTAssertEqual(verdict.userStubMode, .refusalOnly)
        XCTAssertEqual(Set(verdict.revokedPermissions), Set(BASSovereignPermission.allCases))
    }

    func testBR002ThoughtFoldChecksumBrokenEmitsRollback() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            hard: .init(thoughtFoldChecksumBroken: true)
        ))
        XCTAssertEqual(verdict.verdictLevel, .rollback)
        XCTAssertTrue(verdict.reasonCodes.contains("BR-002"))
        XCTAssertTrue(verdict.revokedPermissions.contains(.memoryWriteHot))
    }

    func testBR003ExternalSideEffectWithoutSCTEmitsDeadStop() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            operation: .toolWrite,
            hard: .init(externalSideEffectWithoutSCT: true)
        ))
        XCTAssertEqual(verdict.verdictLevel, .deadStop)
        XCTAssertTrue(verdict.reasonCodes.contains("BR-003"))
        XCTAssertTrue(verdict.revokedPermissions.contains(.toolWrite))
        XCTAssertTrue(verdict.revokedPermissions.contains(.externalActuation))
    }

    func testBR004MemoryOrHostWriteBypassEmitsMemoryFreeze() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            hard: .init(memoryOrHostWriteBypass: true)
        ))
        XCTAssertEqual(verdict.verdictLevel, .memoryFreeze)
        XCTAssertTrue(verdict.reasonCodes.contains("BR-004"))
        XCTAssertTrue(verdict.revokedPermissions.contains(.hostMutation))
    }

    func testBR005HostRemovalBypassedEmitsQuarantine() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            hard: .init(hostRemovalBypassed: true)
        ))
        XCTAssertEqual(verdict.verdictLevel, .quarantine)
        XCTAssertTrue(verdict.reasonCodes.contains("BR-005"))
    }

    func testBR006PolicyBundleTamperedEmitsDeadStop() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            hard: .init(policyBundleTampered: true)
        ))
        XCTAssertEqual(verdict.verdictLevel, .deadStop)
        XCTAssertTrue(verdict.reasonCodes.contains("BR-006"))
    }

    func testBR007UnauthorizedSelfMutationEmitsDeadStop() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            hard: .init(unauthorizedSelfMutation: true)
        ))
        XCTAssertEqual(verdict.verdictLevel, .deadStop)
        XCTAssertTrue(verdict.reasonCodes.contains("BR-007"))
    }

    func testBR008IrreversibleHighGSINoEvidenceEmitsToolCut() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            operation: .toolWrite,
            hard: .init(irreversibleHighGSIWithoutEvidence: true),
            evidence: false
        ))
        XCTAssertEqual(verdict.verdictLevel, .toolCut)
        XCTAssertTrue(verdict.reasonCodes.contains("BR-008"))
        XCTAssertTrue(verdict.revokedPermissions.contains(.toolWrite))
    }

    func testBR009RuntimeUnstableInHighRiskEmitsShadowLock() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            hard: .init(runtimeUnstableInHighRisk: true)
        ))
        XCTAssertEqual(verdict.verdictLevel, .shadowLock)
        XCTAssertTrue(verdict.reasonCodes.contains("BR-009"))
    }

    func testBR010RiskPermitConflictEmitsThrottle() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            hard: .init(riskPermitHeadConflict: true)
        ))
        XCTAssertEqual(verdict.verdictLevel, .throttle)
        XCTAssertTrue(verdict.reasonCodes.contains("BR-010"))
        XCTAssertTrue(verdict.revokedPermissions.contains(.checkpointCommit))
    }

    func testBR011HostAttemptsBaseBoundaryOverrideEmitsQuarantine() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            hard: .init(hostAttemptsBaseBoundaryOverride: true)
        ))
        XCTAssertEqual(verdict.verdictLevel, .quarantine)
        XCTAssertTrue(verdict.reasonCodes.contains("BR-011"))
    }

    func testBR012AuditAppendFailedEmitsDeadStop() async throws {
        // BR-012 as observed by a *prior* layer: the sentinel has
        // reported that a previous append failed and this turn should
        // dead-stop.
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            hard: .init(auditAppendFailed: true)
        ))
        XCTAssertEqual(verdict.verdictLevel, .deadStop)
        XCTAssertTrue(verdict.reasonCodes.contains("BR-012"))
    }

    // MARK: - Multiple rules fire: max level wins

    func testMultipleRulesTakeMaximumLevel() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            hard: .init(
                memoryOrHostWriteBypass: true,   // min = memoryFreeze (4)
                runtimeUnstableInHighRisk: true  // min = shadowLock (2)
            )
        ))
        // Both fire; max wins.
        XCTAssertEqual(verdict.verdictLevel, .memoryFreeze)
        XCTAssertTrue(verdict.reasonCodes.contains("BR-004"))
        XCTAssertTrue(verdict.reasonCodes.contains("BR-009"))
    }

    // MARK: - Soft-signal lex order

    func testHighPrivilegeViolationPinsQuarantineIgnoringMildSignals() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            soft: .init(
                integrity: 0.2,
                privilegeViolation: 0.85,  // high
                memoryContamination: 0.9   // high, but lower priority — ignored
            )
        ))
        // Privilege violation wins because it's earlier in the lex order.
        XCTAssertEqual(verdict.verdictLevel, .quarantine)
        XCTAssertTrue(verdict.reasonCodes.contains(where: { $0.hasPrefix("LEX_ORDER:privilegeViolation") }))
    }

    func testHighIntegrityPinsDeadStopOverEverythingElse() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            soft: .init(
                integrity: 0.95,
                privilegeViolation: 0.95,
                selfMod: 0.95
            )
        ))
        XCTAssertEqual(verdict.verdictLevel, .deadStop)
    }

    func testAllMidSignalsAccumulateHighestMidLevel() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            soft: .init(
                integrity: 0.5,              // mid → rollback
                privilegeViolation: 0.5,     // mid → shadowLock
                manipulationIntrusion: 0.5   // mid → throttle
            )
        ))
        // Max of {rollback, shadowLock, throttle} = rollback.
        XCTAssertEqual(verdict.verdictLevel, .rollback)
    }

    func testCalmSoftSignalsProducePass() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            soft: .init(integrity: 0.1, privilegeViolation: 0.1)
        ))
        XCTAssertEqual(verdict.verdictLevel, .pass)
    }

    // MARK: - Evidence-insufficient upgrade

    func testIrreversibleOperationWithoutEvidenceUpgradesToToolCut() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            operation: .hostMutate,
            evidence: false
        ))
        XCTAssertEqual(verdict.verdictLevel, .toolCut)
        XCTAssertTrue(verdict.reasonCodes.contains(where: { $0.hasPrefix("EVIDENCE_INSUFFICIENT:hostMutate") }))
    }

    func testIrreversibleOperationWithEvidenceDoesNotUpgrade() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            operation: .hostMutate,
            evidence: true
        ))
        XCTAssertEqual(verdict.verdictLevel, .pass)
    }

    func testPureInferenceWithoutEvidenceDoesNotUpgrade() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            operation: .pureInference,
            evidence: false
        ))
        XCTAssertEqual(verdict.verdictLevel, .pass)
    }

    func testEvidenceUpgradeDoesNotDowngradeHigherVerdict() async throws {
        let (engine, _) = makeEngine()
        let verdict = try await engine.evaluate(ctx(
            operation: .hostMutate,
            hard: .init(memoryOrHostWriteBypass: true), // memoryFreeze (4)
            evidence: false                              // would upgrade to toolCut (3) — but 3 < 4
        ))
        XCTAssertEqual(verdict.verdictLevel, .memoryFreeze)
    }

    // MARK: - Fail-closed on ledger append

    func testLedgerAppendFailureIsReThrownAsEngineError() async throws {
        // Pre-populate an AUDIT ID collision: if a caller-sealed entry
        // with the same audit ID already exists the ledger will refuse
        // the second because its caller-signature won't match. We
        // simulate this more directly by injecting a ledger that has
        // been "closed" via a draft with empty audit_id that the
        // engine can't produce. Simpler path: wrap a failing ledger.
        //
        // Easiest deterministic failure: pass an empty sessionID so
        // the ledger's validation throws `invalidEntry`.
        let (engine, _) = makeEngine()
        let bad = BASSovereignVerdictEngine.VerdictContext(
            sessionID: "",
            turnID: "T1",
            operation: .pureInference,
            hardObservations: .clean,
            softSignals: .calm,
            evidenceSufficient: true
        )
        do {
            _ = try await engine.evaluate(bad)
            XCTFail("empty sessionID should cause ledger to reject the audit entry")
        } catch BASSovereignVerdictEngine.EngineError.auditAppendFailed(let msg) {
            XCTAssertFalse(msg.isEmpty)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Integration: every verdict appends exactly one audit entry

    func testEveryVerdictWritesExactlyOneAuditEntryInOrder() async throws {
        let (engine, ledger) = makeEngine()

        _ = try await engine.evaluate(ctx())
        _ = try await engine.evaluate(ctx(hard: .init(runtimeUnstableInHighRisk: true)))
        _ = try await engine.evaluate(ctx(hard: .init(policyBundleTampered: true)))

        let count = await ledger.count()
        XCTAssertEqual(count, 3)

        try await ledger.verifyChainIntegrity()
    }
}

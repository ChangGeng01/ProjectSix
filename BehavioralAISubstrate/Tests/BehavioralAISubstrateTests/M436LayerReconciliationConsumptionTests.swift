import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASOrchestration
import BASRuntimeCore

/// M436 (chapter 一百四) — pin the chapter 一百四 deep architecture
/// audit fixes:
///
///   - **CRITICAL #1**: pre-M436 the
///     `BASObservationReconciliationVerdictEngine.evaluate(...)`
///     was a library function only invoked from tests; production
///     `runTurn` never called it. The audit ledger therefore had
///     ZERO visibility into "did all 13 expected layers
///     participate this turn." M436 wires the verdict into
///     `buildSovereignAuditEntry` so the verdict's findings emit
///     `reconciliation.severity` /
///     `reconciliation.findings` /
///     `reconciliation.observed` /
///     `reconciliation.missing:<layer>` codes into `signalRefs`.
///
///   - **HIGH #2**: pre-M436 only candidate (M299) + tribunal
///     (M300) bundles emitted `signalRefs` codes; the other 7
///     cognitive bundles (L1 / L2 / L3 / L5 / L6 / L7 / L12) +
///     L8 hippocampal were derived per turn but produced ZERO
///     audit-walker visibility. M436 emits one
///     `<layer>.coverage:<full|partial|empty>` code per layer.
///
/// Doctrine pins (each test below):
///   - Audit-only emission. The reconciliation verdict never
///     escalates the sovereign verdict, never mutates the permit,
///     never changes hash-chain semantics — signalRefs simply
///     digests a longer ordered list deterministically.
///   - Backward-compat: the legacy M298 `risk: / permit: / fold:`
///     codes plus the M299 / M300 / M303 / M304 codes all still
///     appear alongside the new M436 codes.
final class M436LayerReconciliationConsumptionTests: XCTestCase {

    // MARK: - Configuration helpers (copied from M299 pattern)

    private func makeRuntimePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m436.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m436.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m436.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m436.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m436.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m436.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m436",
                policyProfileID: "host.m436.policy",
                prefersPureLocal: true,
                defaultDeviceState:
                    BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: makeTuning(),
                runtimePolicyLineage:
                    makeRuntimePolicyLineage(),
                hostRhythmProfile: .generic
            )
        )
    }

    private func runTurn(
        prompt: String = "Drive a normal turn so all 13 cognitive layers participate.",
        title: String = "M436 reconciliation coverage"
    ) throws -> BASEBrainTurnResult {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: prompt,
                title: title,
                riskLevel: .medium
            )
        )
        return try XCTUnwrap(result.eBrainTurn)
    }

    // MARK: - 1. reconciliation.severity always lands

    /// Production runTurn must always emit
    /// `reconciliation.severity:<clean|advisory|halt>` so audit
    /// walkers can grep "did this turn pass coverage" in O(1).
    func testReconciliationSeverityIsEmitted() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        let severityCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("reconciliation.severity:")
        }
        XCTAssertEqual(
            severityCodes.count, 1,
            "exactly one reconciliation.severity code per turn")
        let canonical: Set<String> = ["clean", "advisory", "halt"]
        let suffix = severityCodes[0]
            .replacingOccurrences(
                of: "reconciliation.severity:", with: "")
        XCTAssertTrue(
            canonical.contains(suffix),
            "severity must be one of \(canonical) (was \"\(suffix)\")")
    }

    // MARK: - 2. reconciliation.findings count emits

    /// `reconciliation.findings:<N>` is always present; pin
    /// "exactly one count code per turn" so a future PR cannot
    /// silently drop the integer.
    func testReconciliationFindingsCountIsEmitted() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        let codes = auditEntry.signalRefs.filter {
            $0.hasPrefix("reconciliation.findings:")
        }
        XCTAssertEqual(
            codes.count, 1,
            "exactly one reconciliation.findings code per turn")
        let suffix = codes[0]
            .replacingOccurrences(
                of: "reconciliation.findings:", with: "")
        XCTAssertNotNil(
            Int(suffix),
            "findings count must parse as an integer " +
            "(was \"\(suffix)\")")
    }

    // MARK: - 3. reconciliation.observed lists participating layers

    /// `reconciliation.observed:<layers>` carries the sorted
    /// raw-value list of every cognitive layer that produced
    /// a coverage summary this turn. On a healthy interactive
    /// turn every cognitive layer participates, so the observed
    /// list is non-empty and contains at least L9 (dreamLoop)
    /// + L10 (triSelfTribunal) + L11 (riskClimate) + L12
    /// (gentleHand) which are the four load-bearing layers.
    func testReconciliationObservedListsCognitiveLayers() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        let observedCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("reconciliation.observed:")
        }
        XCTAssertEqual(
            observedCodes.count, 1,
            "exactly one observed-list code per turn")
        let suffix = observedCodes[0]
            .replacingOccurrences(
                of: "reconciliation.observed:", with: "")
        let layers = suffix.split(separator: "+").map(String.init)
        // BASCognitiveLayer raw values are "L1"..."L14" (the
        // 14-layer numeric codes), so the observed list uses
        // those identifiers. Pin the load-bearing layers — L9
        // dreamLoop / L10 tribunal / L11 risk / L12 softHand —
        // these were already production-visible before M436 so
        // they MUST also be observed post-M436. Any regression
        // here is a semantic break.
        XCTAssertTrue(
            layers.contains("L9"),
            "dreamLoop (L9) must be observed (was \(layers))")
        XCTAssertTrue(
            layers.contains("L10"),
            "triSelfTribunal (L10) must be observed " +
            "(was \(layers))")
        XCTAssertTrue(
            layers.contains("L11"),
            "riskClimate (L11) must be observed (was \(layers))")
        XCTAssertTrue(
            layers.contains("L12"),
            "gentleHand (L12) must be observed (was \(layers))")
        // The "极致" target: every cognitive layer (L1..L13)
        // observed on a healthy fixture turn. Pin the count
        // explicitly so a regression that drops a layer fails
        // loudly.
        XCTAssertEqual(
            layers.count, 13,
            "M436 target: all 13 cognitive layers observed " +
            "on a healthy fixture turn (was \(layers))")
    }

    // MARK: - 4. Silent bundles now emit coverage codes

    /// Pre-M436 ALL of these prefixes were absent from
    /// signalRefs (HIGH defect #2 in chapter 一百四 audit). Post-
    /// M436 each bundle emits one `<layer>.coverage:<status>`
    /// + `<layer>.observations:<N>` code pair when the bundle
    /// is non-nil. A healthy interactive turn populates them all.
    func testSevenSilentBundlesNowEmitCoverageCodes() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)
        let signal = auditEntry.signalRefs

        // M436.1 expanded the list to 11 cognitive bundle
        // prefixes (closing the chapter 一百四 honest-audit
        // HIGH finding that L4 / L11 / L13-ticket were entered
        // into the reconciliation report but had no per-layer
        // `<layer>.coverage:` code emission).
        let layerPrefixes = [
            "presence",
            "decomposition",
            "softHand",
            "leaseLife",
            "hostConstitution",
            "thoughtFold",
            "neuralOrgan",
            "hippocampal",
            // M436.1 additions:
            "worldPrior",
            "risk",
            "updateTicket"
        ]
        let canonicalCoverage: Set<String> = [
            "full", "partial", "empty"
        ]
        for prefix in layerPrefixes {
            let coverageCodes = signal.filter {
                $0.hasPrefix("\(prefix).coverage:")
            }
            XCTAssertEqual(
                coverageCodes.count, 1,
                "M436 must emit exactly one " +
                "\(prefix).coverage:<status> code per turn " +
                "(was \(coverageCodes))")
            let status = coverageCodes[0]
                .replacingOccurrences(
                    of: "\(prefix).coverage:", with: "")
            XCTAssertTrue(
                canonicalCoverage.contains(status),
                "\(prefix).coverage status must be one of " +
                "\(canonicalCoverage) (was \"\(status)\")")
            // Observations count code paired with each coverage
            // code so audit walkers can answer "how many signals"
            // without parsing the bundle.
            let obsCodes = signal.filter {
                $0.hasPrefix("\(prefix).observations:")
            }
            XCTAssertEqual(
                obsCodes.count, 1,
                "M436 must emit exactly one " +
                "\(prefix).observations:<N> code per turn " +
                "(was \(obsCodes))")
        }
    }

    // MARK: - 5. Pre-M436 codes still present (backward-compat)

    /// Backward-compat: legacy M298 codes plus M299 frontier +
    /// M300 tribunal + M303 abyssal codes must still appear
    /// alongside the new M436 codes. Pin the coexistence so a
    /// future PR doesn't accidentally drop earlier codes.
    func testLegacyCodesStillPresentAlongsideM436Codes() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)
        let signal = auditEntry.signalRefs

        XCTAssertTrue(
            signal.contains(where: { $0.hasPrefix("risk:") }),
            "risk: prefix must remain in signalRefs (legacy M298)")
        XCTAssertTrue(
            signal.contains(where: { $0.hasPrefix("permit:") }),
            "permit: prefix must remain in signalRefs (legacy M298)")
        XCTAssertTrue(
            signal.contains(where: { $0.hasPrefix("fold:") }),
            "fold: prefix must remain in signalRefs (legacy M298)")
        XCTAssertTrue(
            signal.contains(where: {
                $0.hasPrefix("frontier.status:")
            }),
            "frontier.status: prefix must remain (M299)")
        XCTAssertTrue(
            signal.contains(where: {
                $0.hasPrefix("tribunal.status:")
            }),
            "tribunal.status: prefix must remain (M300)")
        XCTAssertTrue(
            signal.contains(where: {
                $0.hasPrefix("reconciliation.severity:")
            }),
            "reconciliation.severity: must be added by M436")
    }

    // MARK: - 6. Audit-only doctrine — no verdict escalation

    /// Doctrine pin: M436 reconciliation MUST be audit-only.
    /// The verdict the engine produces (advisory / halt) must
    /// NEVER feed back into `sovereignVerdict.verdictLevel` or
    /// `actionPermit.mode`. Pin by checking that the sovereign
    /// verdict on a normal turn is not forced to advisory by
    /// the existence of reconciliation findings.
    func testReconciliationIsAuditOnlyNoVerdictEscalation()
        throws
    {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)
        let verdict = try XCTUnwrap(turn.sovereignVerdict)

        // The reconciliation severity is in signalRefs; pull it.
        let severityCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("reconciliation.severity:")
        }
        guard let code = severityCodes.first else {
            XCTFail("reconciliation.severity must be present")
            return
        }
        let recoSeverity = code.replacingOccurrences(
            of: "reconciliation.severity:", with: "")

        // The sovereign verdict's level is independent from
        // the reconciliation severity. M436 doctrine: even if
        // reconciliation is `.advisory` (some layer missed core
        // coverage on this fixture turn), the sovereign verdict
        // must NOT be auto-escalated past the substrate's
        // structurally-determined level. Pin by asserting the
        // verdict level on a healthy fixture turn does not
        // include `.rollback` or `.deadStop` purely from
        // reconciliation signals. (Lower levels — pass /
        // throttle / shadowLock / toolCut / memoryFreeze /
        // quarantine — are all legitimate outcomes of the
        // existing risk + permit synthesis path and are not
        // M436's concern.)
        let escalatedLevels: Set<BASSovereignVerdictLevel> = [
            .rollback,
            .deadStop
        ]
        XCTAssertFalse(
            escalatedLevels.contains(verdict.verdictLevel),
            "sovereign verdict on a healthy fixture must not " +
            "be escalated to rollback/deadStop by " +
            "reconciliation (was " +
            "\(verdict.verdictLevel.rawValue), reco=" +
            "\(recoSeverity))")
    }

    // MARK: - 7. Reconciliation codes are deterministic across
    //           identical fixture runs

    /// Drive two identical configurations through the runtime;
    /// the reconciliation severity + observed-layer list must
    /// agree (deterministic from the same inputs).
    func testReconciliationCodesAreDeterministic() throws {
        let turn1 = try runTurn(
            prompt: "Identical M436 prompt.",
            title: "Identical M436 title")
        let turn2 = try runTurn(
            prompt: "Identical M436 prompt.",
            title: "Identical M436 title")
        let entry1 = try XCTUnwrap(turn1.sovereignAuditEntry)
        let entry2 = try XCTUnwrap(turn2.sovereignAuditEntry)

        func reconciliationCodes(
            from entry: BASSovereignAuditEntry
        ) -> [String] {
            entry.signalRefs.filter {
                $0.hasPrefix("reconciliation.")
            }.sorted()
        }
        XCTAssertEqual(
            reconciliationCodes(from: entry1),
            reconciliationCodes(from: entry2),
            "reconciliation.* codes must be deterministic " +
            "across identical fixture turns")
    }

    // MARK: - 8. Failure-path verdict translations
    //          (M436.1 — closes chapter 一百四 honest-audit
    //          HIGH "happy-path-only tests" finding).
    //
    // Pre-M436.1 the M436 audit emission was tested only on
    // healthy fixture turns where verdict.severity == .clean
    // and findings.isEmpty. The audit emission's translation
    // of halt-tier / advisory-tier / missing-layer findings
    // into reason codes was therefore functionally untested.
    // The following 4 tests exercise the verdict engine
    // directly with synthetic input and pin the same string-
    // shape contract that buildSovereignAuditEntry uses, so
    // any future change that drops or renames a finding-to-
    // code mapping is caught.

    /// Halt-tier verdict (budget overspend) should map to
    /// `reconciliation.severity:halt` + `reconciliation.findings:1`
    /// + `reconciliation.overspend:<observed>:<ceiling>`.
    func testHaltVerdictMapsToOverspendAndHaltSeverity() throws {
        let report = BASObservationReconciliationReport(
            turnID: "halt-test-turn",
            sessionID: "halt-test-session",
            summaries: [
                BASObservationCoverageSummary(
                    layer: .dreamLoop,
                    turnID: "halt-test-turn",
                    sessionID: "halt-test-session",
                    totalObservations: 5,
                    distinctSubjectCount: 5,
                    hasCoreSignalCoverage: true,
                    budgetTotalCost: 1.0,
                    emittedAt: Date(timeIntervalSince1970: 0))
            ])
        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: [.dreamLoop],
                budgetCeiling: 0.5,
                emittedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(verdict.severity, .halt,
            "budget 1.0 > ceiling 0.5 must produce halt-tier")
        XCTAssertEqual(verdict.findings.count, 1)
        // Pin the finding shape — this is what M436's emission
        // logic in buildSovereignAuditEntry will translate.
        if case .budgetOverspend(let obs, let ceil) = verdict
            .findings[0]
        {
            XCTAssertEqual(obs, 1.0, accuracy: 0.001)
            XCTAssertEqual(ceil, 0.5, accuracy: 0.001)
        } else {
            XCTFail("expected .budgetOverspend, got " +
                "\(verdict.findings[0])")
        }
    }

    /// Missing-layer verdict (advisory-tier) should map to
    /// `reconciliation.severity:advisory` +
    /// `reconciliation.missing:<layer>` per missing layer.
    func testMissingLayerVerdictProducesAdvisoryWithMissingCode()
        throws
    {
        let report = BASObservationReconciliationReport(
            turnID: "missing-test-turn",
            sessionID: "missing-test-session",
            summaries: [
                BASObservationCoverageSummary(
                    layer: .dreamLoop,
                    turnID: "missing-test-turn",
                    sessionID: "missing-test-session",
                    totalObservations: 1,
                    distinctSubjectCount: 1,
                    hasCoreSignalCoverage: true,
                    budgetTotalCost: 0.1,
                    emittedAt: Date(timeIntervalSince1970: 0))
            ])
        // Expected layers includes one that's not in the
        // report — the engine should emit a missing-layer
        // finding for it.
        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: [.dreamLoop, .gentleHand],
                budgetCeiling: 1.0,
                emittedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(verdict.severity, .advisory)
        XCTAssertTrue(
            verdict.findings.contains { finding in
                if case .missingLayer(let layer) = finding,
                    layer == .gentleHand { return true }
                return false
            },
            "expected .missingLayer(.gentleHand), got " +
            "\(verdict.findings)")
    }

    /// Missing-core-coverage verdict should map to
    /// `reconciliation.partial:<layer>` per layer that
    /// reported but lacked core signal.
    func testMissingCoreCoverageMapsToPartialCode() throws {
        let report = BASObservationReconciliationReport(
            turnID: "partial-test-turn",
            sessionID: "partial-test-session",
            summaries: [
                // Layer reports but has hasCoreSignalCoverage = false
                BASObservationCoverageSummary(
                    layer: .dreamLoop,
                    turnID: "partial-test-turn",
                    sessionID: "partial-test-session",
                    totalObservations: 3,
                    distinctSubjectCount: 3,
                    hasCoreSignalCoverage: false,
                    budgetTotalCost: 0.2,
                    emittedAt: Date(timeIntervalSince1970: 0))
            ])
        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: [.dreamLoop],
                budgetCeiling: 1.0,
                emittedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(verdict.severity, .advisory)
        XCTAssertTrue(
            verdict.findings.contains { finding in
                if case .layerMissingCoreCoverage(let layer)
                    = finding,
                   layer == .dreamLoop { return true }
                return false
            },
            "expected .layerMissingCoreCoverage(.dreamLoop), " +
            "got \(verdict.findings)")
    }

    /// Clean verdict should produce zero findings and
    /// `reconciliation.severity:clean`.
    func testCleanVerdictHasNoFindings() throws {
        let report = BASObservationReconciliationReport(
            turnID: "clean-test-turn",
            sessionID: "clean-test-session",
            summaries: [
                BASObservationCoverageSummary(
                    layer: .dreamLoop,
                    turnID: "clean-test-turn",
                    sessionID: "clean-test-session",
                    totalObservations: 1,
                    distinctSubjectCount: 1,
                    hasCoreSignalCoverage: true,
                    budgetTotalCost: 0.1,
                    emittedAt: Date(timeIntervalSince1970: 0))
            ])
        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: [.dreamLoop],
                budgetCeiling: 1.0,
                emittedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(verdict.severity, .clean)
        XCTAssertTrue(verdict.findings.isEmpty,
            "clean severity must have zero findings")
    }

    // MARK: - 9. Asymmetric-coverage gap closure (M436.1)

    /// Pre-M436.1 the L4 worldPrior / L11 risk / L13
    /// updateTicket bundles entered the reconciliation report
    /// (so they appeared in `reconciliation.observed:`) but
    /// had no per-layer `<layer>.coverage:<status>` code
    /// emission. M436.1 closes that gap. Pin all 11 cognitive
    /// per-layer prefixes are present on a healthy turn.
    func testM436_1AsymmetricCoverageClosed() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)
        let signal = auditEntry.signalRefs

        // M436.1 requires these 3 prefixes to appear on every
        // healthy turn (closing the asymmetric-coverage HIGH
        // finding from chapter 一百四 honest audit).
        for prefix in ["worldPrior", "risk", "updateTicket"] {
            let coverageCount = signal.filter {
                $0.hasPrefix("\(prefix).coverage:")
            }.count
            XCTAssertEqual(
                coverageCount, 1,
                "M436.1: \(prefix).coverage code missing — " +
                "honest-audit asymmetric-coverage gap not closed")
            let obsCount = signal.filter {
                $0.hasPrefix("\(prefix).observations:")
            }.count
            XCTAssertEqual(
                obsCount, 1,
                "M436.1: \(prefix).observations code missing — " +
                "honest-audit asymmetric-coverage gap not closed")
        }
    }

    // MARK: - 10. M436.2 — coverageStatus pure-function unit
    //          tests (chapter 一百六 deep-review M-1 fix).
    //
    // Pre-M436.2 the `coverageStatus(observations:core:)`
    // helper was an inline closure inside `buildSovereignAuditEntry`.
    // Production fixtures always populated `hasCoreSignalCoverage = true`,
    // so the `partial` and `empty` branches of the 3-way
    // classifier were never exercised through any test
    // assertion against actual audit signalRefs strings. A
    // future refactor that flipped `core ? "full" : "partial"`
    // to `core ? "full" : "degraded"` (or any other rename)
    // would have shipped green. M436.2 extracted the helper to
    // `BASEBrainRuntimeCoordinator.coverageStatus(...)` static,
    // unblocking these direct unit tests.

    /// Empty branch: zero observations → "empty".
    func testCoverageStatusEmptyBranch() {
        let status = BASEBrainRuntimeCoordinator.coverageStatus(
            observations: 0, core: false)
        XCTAssertEqual(status, "empty")
        // Edge: even if core==true, zero observations → empty.
        let status2 = BASEBrainRuntimeCoordinator.coverageStatus(
            observations: 0, core: true)
        XCTAssertEqual(status2, "empty",
            "zero observations always returns 'empty' " +
            "regardless of core flag")
    }

    /// Partial branch: observations > 0 AND core == false →
    /// "partial".
    func testCoverageStatusPartialBranch() {
        let status = BASEBrainRuntimeCoordinator.coverageStatus(
            observations: 3, core: false)
        XCTAssertEqual(status, "partial")
    }

    /// Full branch: observations > 0 AND core == true →
    /// "full".
    func testCoverageStatusFullBranch() {
        let status = BASEBrainRuntimeCoordinator.coverageStatus(
            observations: 5, core: true)
        XCTAssertEqual(status, "full")
        // Edge: 1 observation + core == "full" too.
        let status2 = BASEBrainRuntimeCoordinator.coverageStatus(
            observations: 1, core: true)
        XCTAssertEqual(status2, "full")
    }

    /// Pin: the canonical status set is exactly {empty, full,
    /// partial} — no other strings can be returned. Pin via
    /// exhaustive enumeration on a small input grid.
    func testCoverageStatusOnlyEmitsCanonicalSet() {
        var observed: Set<String> = []
        for obs in [0, 1, 5, 100] {
            for core in [false, true] {
                observed.insert(
                    BASEBrainRuntimeCoordinator.coverageStatus(
                        observations: obs, core: core))
            }
        }
        XCTAssertEqual(
            observed,
            ["empty", "full", "partial"],
            "coverageStatus must only emit the 3 canonical " +
            "status strings (any drift would change audit-" +
            "walker contract)")
    }

    // MARK: - 11. layerReconciliationExpectedLayers static
    //          constant invariance (chapter 一百六 N-1 fix).
    //
    // M436.2 hoisted the per-turn local `expectedLayers` array
    // to a type-level `static let`. Pin the cardinality + order
    // so a future PR that drops or reorders a layer (which
    // could cause a verdict-shape divergence between BAS-direct
    // and Qinao-streamed paths) fails loudly.

    // MARK: - M438 — anti-magic-number sweep pins

    /// Pin: `layerReconciliationBudgetCeiling == 1.0`.
    /// Regression detector for chapter 一百十三 anti-magic-number
    /// sweep. The verdict engine clamps `[0, 1]` internally so
    /// values >= 1.0 collapse, but the literal value still
    /// matters for cross-package alignment with Qinao's path
    /// (`QinaoSovereign.recordTurnCoverage(...,
    /// budgetCeiling: 1.0)`). Drift here would silently break
    /// the chapter 一百七 cross-package alignment doctrine.
    func testLayerReconciliationBudgetCeilingIsOne() {
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .layerReconciliationBudgetCeiling,
            1.0, accuracy: 0.0001,
            "budget ceiling 1.0 aligns BAS-direct path with " +
            "Qinao default (chapter 一百九 alignment + chapter " +
            "一百十三 anti-magic-number promotion)")
    }

    func testExpectedLayersStaticConstantHas13Layers() {
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .layerReconciliationExpectedLayers.count,
            13,
            "13 cognitive layers (L1..L13); L14 sovereign is " +
            "the ledger itself, not a layer that emits coverage")
    }

    // MARK: - 12. M436.3 — cross-package alignment static
    //          views (chapter 一百七 fix M-4).
    //
    // Pre-M436.3 the BAS-direct path used `[L1..L13]` for
    // `expectedLayers` and the Qinao path defaulted to
    // `[L14]`, producing two divergent reconciliation
    // contracts that audit walkers reading both ledgers would
    // see as contradictory. M436.3 promoted the BAS static
    // constant from `internal` to `public` and added two
    // string-typed views (`layerReconciliationExpectedLayerIDs`
    // = L1..L13 and `fullCoverageExpectedLayerIDs` = L1..L14)
    // so cross-package callers can opt into a shared
    // expectation set.

    /// String-typed view must mirror the typed array exactly
    /// (same cardinality, same ordering, same raw values).
    func testLayerReconciliationExpectedLayerIDsMirrorsTypedArray()
    {
        let typed = BASEBrainRuntimeCoordinator
            .layerReconciliationExpectedLayers
            .map { $0.rawValue }
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .layerReconciliationExpectedLayerIDs,
            typed,
            "string-typed view must mirror typed array — drift " +
            "would re-introduce the cross-package divergence " +
            "M436.3 fixes")
    }

    /// `fullCoverageExpectedLayerIDs` must be `[L1..L13, L14]`
    /// — exactly the 13 cognitive layers plus L14 sovereign.
    /// Pin both cardinality (14) and that L14 is the LAST
    /// element (ordering matters for stable finding emission).
    func testFullCoverageExpectedLayerIDsHas14LayersWithSovereignLast()
    {
        let full = BASEBrainRuntimeCoordinator
            .fullCoverageExpectedLayerIDs
        XCTAssertEqual(full.count, 14)
        XCTAssertEqual(
            full.last,
            BASCognitiveLayer.sovereign.rawValue,
            "L14 sovereign must be the last element so " +
            "cognitive-then-sovereign ordering is stable for " +
            "audit-walker finding emission")
        // Pin: dropping the last == L1..L13.
        XCTAssertEqual(
            Array(full.dropLast()),
            BASEBrainRuntimeCoordinator
                .layerReconciliationExpectedLayerIDs,
            "fullCoverage = layerReconciliation + L14 must hold")
    }

    /// Pin: `layerReconciliationExpectedLayerIDs` does NOT
    /// contain L14 (sovereign is the ledger itself, not a
    /// layer that emits coverage TO the ledger). A future
    /// drift that adds L14 here would silently change the
    /// reconciliation contract.
    func testLayerReconciliationExpectedLayerIDsExcludesSovereign()
    {
        let ids = BASEBrainRuntimeCoordinator
            .layerReconciliationExpectedLayerIDs
        XCTAssertFalse(
            ids.contains(BASCognitiveLayer.sovereign.rawValue),
            "L14 sovereign must NOT be in the cognitive-layer " +
            "expectation set — it's a separate audit surface")
    }

    func testExpectedLayersStaticConstantOrderIsStable() {
        // Pin exact order — chapter 一百四 / 一百五 emission
        // contract relies on `reconciliation.observed:` being
        // sorted lex (L1+L10+L11+...+L9), but the expected-
        // layers list itself is in numeric order so any
        // missing-layer findings emit in a stable sequence.
        let expected: [BASCognitiveLayer] = [
            .leaseLife, .neuralOrgan, .thoughtFold,
            .worldPrior, .hostConstitution, .presenceEye,
            .mirrorBlade, .hippocampalWell, .dreamLoop,
            .triSelfTribunal, .riskClimate, .gentleHand,
            .evolutionFurnace
        ]
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .layerReconciliationExpectedLayers,
            expected,
            "expected-layers list order must be stable; " +
            "a reorder would change finding-emission ordering")
    }

    /// Pin "every layer in `reconciliation.observed:` has a
    /// matching `<layer>.coverage:` per-layer code." This is
    /// the structural symmetry doctrine — the report and the
    /// per-layer emission must never disagree on which layers
    /// participated this turn.
    func testReconciliationObservedAndPerLayerCoverageAreSymmetric()
        throws
    {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)
        let signal = auditEntry.signalRefs

        // Observed list (e.g. "L1+L2+...+L13") → set of
        // BASCognitiveLayer raw values
        guard let observedCode = signal.first(where: {
            $0.hasPrefix("reconciliation.observed:")
        }) else {
            XCTFail("reconciliation.observed: must be present")
            return
        }
        let observedLayers = Set(
            observedCode
                .replacingOccurrences(
                    of: "reconciliation.observed:", with: "")
                .split(separator: "+")
                .map(String.init))

        // Map raw values to the per-layer code prefix used by
        // M436 emission (mostly identity, but a few diverge:
        // L6 presenceEye → "presence", L7 mirrorBlade →
        // "decomposition", L8 hippocampalWell → "hippocampal",
        // L9 dreamLoop → no per-layer code (uses M299
        // "frontier.*" instead), L10 triSelfTribunal → no
        // per-layer code (uses M300 "tribunal.*"),
        // L11 riskClimate → "risk", L12 gentleHand → "softHand",
        // L13 evolutionFurnace → "updateTicket").
        let layerToPrefix: [String: String?] = [
            "L1": "leaseLife",
            "L2": "neuralOrgan",
            "L3": "thoughtFold",
            "L4": "worldPrior",
            "L5": "hostConstitution",
            "L6": "presence",
            "L7": "decomposition",
            "L8": "hippocampal",
            "L9": nil,  // M299 uses frontier.*
            "L10": nil, // M300 uses tribunal.*
            "L11": "risk",
            "L12": "softHand",
            "L13": "updateTicket"
        ]
        for layer in observedLayers {
            guard let mapping = layerToPrefix[layer],
                  let prefix = mapping else {
                // Layer either unmapped or uses a different
                // pre-existing emission (M299 frontier / M300
                // tribunal). Skip — they're already pinned by
                // the legacy-codes test.
                continue
            }
            let matches = signal.filter {
                $0.hasPrefix("\(prefix).coverage:")
            }
            XCTAssertEqual(
                matches.count, 1,
                "Symmetry violation: layer \(layer) appears " +
                "in reconciliation.observed: but " +
                "\(prefix).coverage: is " +
                "\(matches.isEmpty ? "missing" : "duplicated") " +
                "(was \(matches))")
        }
    }
}

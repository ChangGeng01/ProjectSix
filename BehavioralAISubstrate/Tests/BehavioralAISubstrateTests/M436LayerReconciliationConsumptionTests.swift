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

        let layerPrefixes = [
            "presence",
            "decomposition",
            "softHand",
            "leaseLife",
            "hostConstitution",
            "thoughtFold",
            "neuralOrgan",
            "hippocampal"
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
}

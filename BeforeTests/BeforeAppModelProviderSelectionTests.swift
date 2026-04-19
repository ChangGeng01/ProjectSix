import XCTest
import SwiftData
import BASHostKit
@testable import Before

private actor CapturedQuickRefinementInputBox {
    private var turnPolicyID: String?
    private var resolutionPolicyID: String?

    func store(turnPolicyID: String?, resolutionPolicyID: String) {
        self.turnPolicyID = turnPolicyID
        self.resolutionPolicyID = resolutionPolicyID
    }

    func load() -> (turnPolicyID: String?, resolutionPolicyID: String?) {
        (turnPolicyID, resolutionPolicyID)
    }
}

final class BeforeAppModelProviderSelectionTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        BeforeRuntimePolicyStore.clearOverride()
        await DecisionIntelligenceCoordinator.resetTestingRefinementHandlers()
    }

    override func tearDown() async throws {
        BeforeRuntimePolicyStore.clearOverride()
        await DecisionIntelligenceCoordinator.resetTestingRefinementHandlers()
        try await super.tearDown()
    }

    func testRuntimePolicyResolutionUsesBundledJSONWhenOverrideMissing() throws {
        let key = runtimePolicyOverrideKey()
        let bundled = makeRuntimePolicyBundle(bundleVersion: "bundled.v1")
        BeforeRuntimePolicyStore.clearOverride(key: key)
        defer { BeforeRuntimePolicyStore.clearOverride(key: key) }

        let resolution = BeforeRuntimePolicyStore.resolve(
            overrideKey: key,
            bundledData: try JSONEncoder().encode(bundled)
        )

        XCTAssertEqual(resolution.lineage.bundleVersion, "bundled.v1")
        XCTAssertEqual(resolution.lineage.source, .bundledDefault)
        XCTAssertEqual(resolution.lineage.providerRoutingPolicyID, bundled.providerRoutingPolicyID)
        XCTAssertEqual(resolution.lineage.runtimeTuningPolicyID, bundled.runtimeTuningPolicyID)
        XCTAssertTrue(resolution.issues.isEmpty)
    }

    func testRuntimePolicyResolutionPrefersProtectedLocalOverride() throws {
        let key = runtimePolicyOverrideKey()
        let bundled = makeRuntimePolicyBundle(bundleVersion: "bundled.v1")
        let override = makeRuntimePolicyBundle(
            bundleVersion: "override.v2",
            providerRoutingPolicyID: "override.provider-routing.v2",
            runtimeTuningPolicyID: "override.runtime-tuning.v2"
        )
        BeforeRuntimePolicyStore.clearOverride(key: key)
        defer { BeforeRuntimePolicyStore.clearOverride(key: key) }
        XCTAssertTrue(BeforeRuntimePolicyStore.saveOverride(override, key: key))

        let resolution = BeforeRuntimePolicyStore.resolve(
            overrideKey: key,
            bundledData: try JSONEncoder().encode(bundled)
        )

        XCTAssertEqual(resolution.lineage.bundleVersion, "override.v2")
        XCTAssertEqual(resolution.lineage.source, .localOverride)
        XCTAssertEqual(
            resolution.lineage.providerRoutingPolicyID,
            "override.provider-routing.v2"
        )
        XCTAssertEqual(
            resolution.lineage.runtimeTuningPolicyID,
            "override.runtime-tuning.v2"
        )
        XCTAssertTrue(resolution.issues.isEmpty)
    }

    func testRuntimePolicyResolutionQuarantinesInvalidOverrideAndFallsBackToBundledJSON() throws {
        let key = runtimePolicyOverrideKey()
        let bundled = makeRuntimePolicyBundle(bundleVersion: "bundled.v1")
        BeforeRuntimePolicyStore.clearOverride(key: key)
        defer { BeforeRuntimePolicyStore.clearOverride(key: key) }
        XCTAssertTrue(
            ProtectedLocalStateStore.saveData(
                Data("{\"bundleVersion\":".utf8),
                key: key
            )
        )

        let resolution = BeforeRuntimePolicyStore.resolve(
            overrideKey: key,
            bundledData: try JSONEncoder().encode(bundled)
        )

        XCTAssertEqual(resolution.lineage.bundleVersion, "bundled.v1")
        XCTAssertEqual(resolution.lineage.source, .bundledDefault)
        XCTAssertTrue(
            resolution.issues.contains(where: { $0.kind == .overrideDecodeFailed })
        )
        XCTAssertNotNil(ProtectedLocalStateStore.quarantinedData(key: key))
    }

    func testRuntimePolicyResolutionRejectsBundledSourceWhenRequestedPolicyIdentifiersAreUnknown() throws {
        let key = runtimePolicyOverrideKey()
        var bundled = makeRuntimePolicyBundle(bundleVersion: "bundled.v1")
        bundled.providerRoutingPolicyID = "missing.provider"
        bundled.runtimeTuningPolicyID = "missing.runtime"
        BeforeRuntimePolicyStore.clearOverride(key: key)
        defer { BeforeRuntimePolicyStore.clearOverride(key: key) }

        let resolution = BeforeRuntimePolicyStore.resolve(
            overrideKey: key,
            bundledData: try JSONEncoder().encode(bundled)
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertEqual(
            resolution.lineage.providerRoutingPolicyID,
            BeforeRuntimePolicyFallbacks.providerRoutingPolicyID
        )
        XCTAssertEqual(
            resolution.lineage.runtimeTuningPolicyID,
            BeforeRuntimePolicyFallbacks.runtimeTuningPolicyID
        )
        XCTAssertTrue(
            resolution.issues.contains(where: { $0.kind == .unknownProviderRoutingPolicyID })
        )
        XCTAssertTrue(
            resolution.issues.contains(where: { $0.kind == .unknownRuntimeTuningPolicyID })
        )
    }

    @MainActor
    func testRuntimeSnapshotKeepsProviderSurfacesAndCapabilityAligned() throws {
        let app = BeforeAppModel(modelContainer: try makeModelContainer(), startupNotice: nil)

        let snapshot = app.runtimeSnapshot

        XCTAssertEqual(app.intelligenceRuntimeStatus, snapshot.runtimeStatus)
        XCTAssertEqual(app.foundationModelStatus, snapshot.foundationStatus)
        XCTAssertEqual(app.gemmaModelStatus, snapshot.gemmaProviderStatus)
        XCTAssertEqual(app.openModelStatus, snapshot.openModelProviderStatus)
        XCTAssertEqual(app.registeredProviderDescriptors, snapshot.registeredProviders)
        XCTAssertEqual(app.localModelLibrarySnapshot, snapshot.localModelLibrary)
        XCTAssertEqual(app.preferredProviderDescriptor?.kind, app.preferences.preferredIntelligenceProvider.kind)
        if snapshot.registeredProviders.contains(where: { $0.kind == snapshot.runtimeStatus.active }) {
            XCTAssertEqual(app.activeProviderDescriptor?.kind, snapshot.runtimeStatus.active)
        } else {
            XCTAssertNil(app.activeProviderDescriptor)
        }
        XCTAssertEqual(snapshot.executionCapabilityFrame.activeProvider, app.intelligenceRuntimeStatus.active)
    }

    @MainActor
    func testRuntimeSnapshotCarriesResolvedRuntimePolicyLineage() throws {
        let app = BeforeAppModel(modelContainer: try makeModelContainer(), startupNotice: nil)

        let snapshot = app.runtimeSnapshot

        XCTAssertEqual(
            snapshot.runtimePolicyLineage.providerRoutingPolicyID,
            app.intelligenceRuntimeStatus.policyLineage.providerRoutingPolicyID
        )
        XCTAssertEqual(
            snapshot.runtimePolicyLineage.runtimeTuningPolicyID,
            app.intelligenceRuntimeStatus.policyLineage.runtimeTuningPolicyID
        )
        XCTAssertEqual(snapshot.runtimePolicyLineage.source, .bundledDefault)
        XCTAssertFalse(snapshot.runtimePolicyLineage.bundleVersion.isEmpty)
    }

    @MainActor
    func testCurrentLiveEBrainTurnRefreshesHostRuntimeAfterRuntimePolicyOverrideChanges() throws {
        BeforeRuntimePolicyStore.clearOverride()
        defer { BeforeRuntimePolicyStore.clearOverride() }

        let app = BeforeAppModel(modelContainer: try makeModelContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this tonight?")

        let initialTurn = try XCTUnwrap(
            app.currentLiveEBrainTurn(now: Date(timeIntervalSince1970: 1_713_715_200))
        )
        XCTAssertEqual(
            app.runtimeSnapshot.runtimePolicyLineage.runtimeTuningPolicyID,
            "before.host.runtime-synthesis.v1"
        )
        XCTAssertEqual(initialTurn.budgetFrame.runMode, .sentinel)
        XCTAssertEqual(initialTurn.budgetFrame.maxDecodeTokens, 160)

        let override = makeRuntimePolicyBundle(
            bundleVersion: "override.v2",
            runtimeTuningPolicyID: "override.runtime-tuning.v2"
        )
        XCTAssertTrue(BeforeRuntimePolicyStore.saveOverride(override))

        let updatedTurn = try XCTUnwrap(
            app.currentLiveEBrainTurn(now: Date(timeIntervalSince1970: 1_713_715_260))
        )
        XCTAssertEqual(
            app.runtimeSnapshot.runtimePolicyLineage.runtimeTuningPolicyID,
            "override.runtime-tuning.v2"
        )
        XCTAssertEqual(updatedTurn.policyLineage?.runtimeTuningPolicyID, "override.runtime-tuning.v2")
        XCTAssertEqual(updatedTurn.budgetFrame.runMode, .sentinel)
        XCTAssertEqual(updatedTurn.budgetFrame.maxDecodeTokens, 180)
    }

    @MainActor
    func testCurrentLiveEBrainTurnHonorsProvidedRuntimeSnapshotPolicyResolution() throws {
        BeforeRuntimePolicyStore.clearOverride()
        defer { BeforeRuntimePolicyStore.clearOverride() }

        let app = BeforeAppModel(modelContainer: try makeModelContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this tonight?")

        let baselineSnapshot = app.runtimeSnapshot
        XCTAssertEqual(
            baselineSnapshot.runtimePolicyLineage.runtimeTuningPolicyID,
            "before.host.runtime-synthesis.v1"
        )

        let override = makeRuntimePolicyBundle(
            bundleVersion: "override.v2",
            runtimeTuningPolicyID: "override.runtime-tuning.v2"
        )
        XCTAssertTrue(BeforeRuntimePolicyStore.saveOverride(override))
        XCTAssertEqual(
            app.runtimeSnapshot.runtimePolicyLineage.runtimeTuningPolicyID,
            "override.runtime-tuning.v2"
        )

        let turn = try XCTUnwrap(
            app.currentLiveEBrainTurn(
                runtimeSnapshot: baselineSnapshot,
                now: Date(timeIntervalSince1970: 1_713_715_320)
            )
        )

        XCTAssertEqual(
            turn.policyLineage?.runtimeTuningPolicyID,
            baselineSnapshot.runtimePolicyLineage.runtimeTuningPolicyID
        )
        XCTAssertEqual(turn.budgetFrame.runMode, .sentinel)
        XCTAssertEqual(turn.budgetFrame.maxDecodeTokens, 160)
    }

    @MainActor
    func testEvaluateQuickSessionWithIntelligencePassesTurnPolicyResolutionIntoRefinement() async throws {
        BeforeRuntimePolicyStore.clearOverride()
        defer { BeforeRuntimePolicyStore.clearOverride() }

        let app = BeforeAppModel(modelContainer: try makeModelContainer(), startupNotice: nil)
        app.updatePreferences {
            $0.onDeviceIntelligenceMode = .assistive
            $0.preferredIntelligenceProvider = .gemmaE4B
            $0.allowModelFallbacks = true
        }
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this tonight?")
        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .buy
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe
        session.note = "I want relief from a hard day."

        let override = makeRuntimePolicyBundle(
            bundleVersion: "override.v2",
            providerRoutingPolicyID: "override.provider-routing.v2"
        )
        XCTAssertTrue(BeforeRuntimePolicyStore.saveOverride(override))
        XCTAssertEqual(
            app.runtimeSnapshot.runtimePolicyLineage.providerRoutingPolicyID,
            "override.provider-routing.v2"
        )

        let capturedInput = CapturedQuickRefinementInputBox()
        await DecisionIntelligenceCoordinator.setTestingQuickRefinementHandler {
            base,
            _,
            _,
            _,
            _,
            eBrainTurn,
            _,
            runtimePolicyResolution in
            await capturedInput.store(
                turnPolicyID: eBrainTurn?.policyLineage?.providerRoutingPolicyID,
                resolutionPolicyID: runtimePolicyResolution.lineage.providerRoutingPolicyID
            )
            return base
        }

        await app.evaluateQuickSessionWithIntelligence(session)

        let recorded = await capturedInput.load()
        XCTAssertEqual(recorded.turnPolicyID, "override.provider-routing.v2")
        XCTAssertEqual(recorded.resolutionPolicyID, "override.provider-routing.v2")
        XCTAssertEqual(recorded.turnPolicyID, recorded.resolutionPolicyID)
    }

    @MainActor
    func testSetPreferredIntelligenceProviderPublishesNotice() throws {
        let app = BeforeAppModel(modelContainer: try makeModelContainer(), startupNotice: nil)
        app.updatePreferences { $0.preferredIntelligenceProvider = .template }
        app.dismissStartupNotice()

        app.setPreferredIntelligenceProvider(.openModel)

        XCTAssertEqual(app.preferences.preferredIntelligenceProvider, .openModel)
        XCTAssertTrue(app.startupNotice?.contains("Preferred provider set to Open model runtime.") == true)
    }

    @MainActor
    func testSetAllowModelFallbacksPublishesNotice() throws {
        let app = BeforeAppModel(modelContainer: try makeModelContainer(), startupNotice: nil)
        app.updatePreferences { $0.allowModelFallbacks = false }
        app.dismissStartupNotice()

        app.setAllowModelFallbacks(true)

        XCTAssertTrue(app.preferences.allowModelFallbacks)
        XCTAssertTrue(app.startupNotice?.contains("Provider fallbacks are now enabled.") == true)
    }

    @MainActor
    func testImportOpenModelSelectsAssetAndRegistersConfiguredPreviewAdapter() throws {
        let app = BeforeAppModel(modelContainer: try makeModelContainer(), startupNotice: nil)
        let sourceURL = try makeTemporaryOpenModelFile(named: "mistral-\(UUID().uuidString).gguf")

        let imported = try app.importOpenModel(from: sourceURL)
        defer { try? app.removeImportedOpenModel(named: imported.fileName) }

        XCTAssertEqual(app.preferences.preferredOpenModelAssetID, imported.assetID)
        XCTAssertEqual(app.openModelPreferredAsset?.assetID, imported.assetID)
        XCTAssertTrue(app.openModelImportedAssets.contains(where: { $0.assetID == imported.assetID }))
        XCTAssertEqual(
            DecisionIntelligenceProviderRegistry.shared.descriptor(for: .openModel)?.openModel?.stableID,
            imported.generatedStableID
        )
        XCTAssertTrue(app.startupNotice?.contains("Imported \(imported.fileName) into the open-model library slot.") == true)
    }

    @MainActor
    func testSetPreferredOpenModelAssetIDPublishesSelectionAndAutomaticNotices() throws {
        let app = BeforeAppModel(modelContainer: try makeModelContainer(), startupNotice: nil)
        let firstSourceURL = try makeTemporaryOpenModelFile(named: "phi-\(UUID().uuidString).gguf")
        let secondSourceURL = try makeTemporaryOpenModelFile(named: "qwen-\(UUID().uuidString).gguf")

        let firstAsset = try app.importOpenModel(from: firstSourceURL)
        let secondAsset = try app.importOpenModel(from: secondSourceURL)
        defer {
            try? app.removeImportedOpenModel(named: firstAsset.fileName)
            try? app.removeImportedOpenModel(named: secondAsset.fileName)
        }

        app.dismissStartupNotice()
        app.setPreferredOpenModelAssetID(firstAsset.assetID)

        XCTAssertEqual(app.preferences.preferredOpenModelAssetID, firstAsset.assetID)
        XCTAssertTrue(app.startupNotice?.contains("Open model runtime will now prefer imported asset \(firstAsset.fileName).") == true)

        app.dismissStartupNotice()
        app.setPreferredOpenModelAssetID(nil)

        XCTAssertNil(app.preferences.preferredOpenModelAssetID)
        XCTAssertTrue(app.startupNotice?.contains("Open-model asset selection returned to automatic mode.") == true)
    }

    @MainActor
    func testRemoveImportedOpenModelClearsPreferenceAndRestoresReservedSlot() throws {
        let app = BeforeAppModel(modelContainer: try makeModelContainer(), startupNotice: nil)
        let sourceURL = try makeTemporaryOpenModelFile(named: "llama-\(UUID().uuidString).gguf")
        let imported = try app.importOpenModel(from: sourceURL)

        app.dismissStartupNotice()
        try app.removeImportedOpenModel(named: imported.fileName)

        XCTAssertNil(app.preferences.preferredOpenModelAssetID)
        XCTAssertFalse(app.openModelImportedAssets.contains(where: { $0.assetID == imported.assetID }))
        XCTAssertEqual(
            DecisionIntelligenceProviderRegistry.shared.descriptor(for: .openModel)?.openModel?.stableID,
            "before/open-model-slot"
        )
        XCTAssertTrue(app.startupNotice?.contains("Removed \(imported.fileName) from the open-model library slot.") == true)
    }

    private func makeModelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: DecisionEvolutionCheckpoint.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeTemporaryOpenModelFile(named fileName: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeforeAppModelProviderSelectionTests", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let url = directory.appendingPathComponent(fileName, isDirectory: false)
        try Data("open-model".utf8).write(to: url)
        return url
    }

    private func runtimePolicyOverrideKey() -> String {
        "before.runtime-policy.tests.\(UUID().uuidString)"
    }

    private func makeRuntimePolicyBundle(
        bundleVersion: String,
        providerRoutingPolicyID: String = "before.provider-routing.v1",
        runtimeTuningPolicyID: String = "before.host.runtime-synthesis.v1"
    ) -> BeforeRuntimePolicyBundle {
        let baselineRuntimePolicy = BeforeProductCompatibility.resolvedRuntimePolicyBundle
            .runtimeTuningRegistry
            .policiesByID["before.host.runtime-synthesis.v1"]!
        var overrideBudget = baselineRuntimePolicy.budget
        overrideBudget.standardDecodeTokens = 180
        overrideBudget.unstableDecodeTokens = 210
        overrideBudget.guardedDecodeTokens = 240
        overrideBudget.maintenanceBatteryFloor = 0.4
        overrideBudget.runModeProfilesByID = nil
        overrideBudget.runModeProfilesByID = overrideBudget.resolvedRunModeProfilesByID(
            maintenance: baselineRuntimePolicy.maintenance
        )
        let providerRegistry = BASProviderRoutingPolicyRegistry(
            schemaVersion: "before.provider-routing-registry.test.v1",
            defaultPolicyID: "before.provider-routing.v1",
            policiesByID: [
                "before.provider-routing.v1": BASProviderRoutingPolicy(
                    schemaVersion: "before.provider-routing.v1",
                    deterministicProviderID: BASReferenceProviderRuntime.templateProviderID,
                    testingOverrideProviderID: BASReferenceProviderRuntime.testingStubProviderID,
                    preferenceOrderings: [
                        BASProviderPreferenceOrdering(
                            preferredProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                            orderedProviderIDs: [
                                BASReferenceProviderRuntime.gemmaE4BProviderID,
                                BASReferenceProviderRuntime.foundationModelsProviderID
                            ]
                        )
                    ]
                ),
                "override.provider-routing.v2": BASProviderRoutingPolicy(
                    schemaVersion: "override.provider-routing.v2",
                    deterministicProviderID: BASReferenceProviderRuntime.templateProviderID,
                    testingOverrideProviderID: BASReferenceProviderRuntime.testingStubProviderID,
                    preferenceOrderings: [
                        BASProviderPreferenceOrdering(
                            preferredProviderID: BASReferenceProviderRuntime.openModelProviderID,
                            orderedProviderIDs: [
                                BASReferenceProviderRuntime.openModelProviderID,
                                BASReferenceProviderRuntime.gemmaE4BProviderID
                            ]
                        )
                    ]
                )
            ]
        )
        let runtimeRegistry = BASEBrainRuntimeSynthesisPolicyRegistry(
            schemaVersion: "before.runtime-tuning-registry.test.v1",
            defaultPolicyID: "before.host.runtime-synthesis.v1",
            policiesByID: [
                "before.host.runtime-synthesis.v1": baselineRuntimePolicy,
                "override.runtime-tuning.v2": BASEBrainRuntimeSynthesisPolicy(
                    schemaVersion: "override.runtime-tuning.v2",
                    guardrailPressure: .init(
                        protectiveBoundaryIncrement: 0.21,
                        calibrationWatchIncrement: 0.11,
                        calibrationDriftingIncrement: 0.19,
                        boundaryConstraintUnit: 0.04,
                        boundaryConstraintCap: 0.20,
                        calibrationAlertUnit: 0.04,
                        calibrationAlertCap: 0.16,
                        failureGuardUnit: 0.03,
                        failureGuardCap: 0.13,
                        riskFlagUnit: 0.04,
                        riskFlagCap: 0.15,
                        maximumPressure: 0.68
                    ),
                    budget: overrideBudget,
                    wakeIntent: baselineRuntimePolicy.wakeIntent,
                    stateTransitions: baselineRuntimePolicy.stateTransitions,
                    lease: baselineRuntimePolicy.lease,
                    maintenance: baselineRuntimePolicy.maintenance,
                    sovereignExecution: baselineRuntimePolicy.sovereignExecution,
                    hostThresholds: .init(
                        caution: 0.48,
                        protective: 0.75,
                        block: 0.95
                    ),
                    context: baselineRuntimePolicy.context,
                    triSelf: baselineRuntimePolicy.triSelf,
                    risk: baselineRuntimePolicy.risk
                )
            ]
        )

        return BeforeRuntimePolicyBundle(
            schemaVersion: "before.runtime-policy-bundle.v1",
            bundleVersion: bundleVersion,
            providerRoutingRegistry: providerRegistry,
            providerRoutingPolicyID: providerRoutingPolicyID,
            runtimeTuningRegistry: runtimeRegistry,
            runtimeTuningPolicyID: runtimeTuningPolicyID,
            updatedAt: Date(timeIntervalSince1970: 1_713_715_200),
            hostProfile: BeforeProductCompatibility.resolvedRuntimePolicyBundle.hostProfile,
            brainBootstrapRecovery: BeforeProductCompatibility.resolvedRuntimePolicyBundle.brainBootstrapRecovery
        )
    }
}

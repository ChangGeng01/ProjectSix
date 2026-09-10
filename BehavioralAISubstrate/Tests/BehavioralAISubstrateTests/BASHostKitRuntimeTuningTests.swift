// MARK: - BASHostKitRuntimeTuningTests — chapter 二百九十七 / M784
//
// Phase Alpha 第二十三刀(BASHostKitTests god file 2nd cut):从
// `BASHostKitTests.swift` 抽出 runtime tuning + decoding test
// cluster — Phase Alpha 第五个 god file 第二次拆分。
//
// 抽出 15 个 test methods (Swift extension on BASHostKitTests):
//   Runtime tuning source tests:
//   - testRuntimeTuningSourceResolvesConfiguredPolicy
//   - testRuntimeTuningSourceExposesUnavailablePolicyWithoutSilentlyFallingBackToGeneric
//   - testRuntimeTuningSourceTreatsUnknownExplicitPolicyAsMissingInsteadOfPromotingRegistryDefault
//
//   Host configuration policy lineage tests:
//   - testGenericHostConfigurationSurfacesCompiledControlPlaneFallbackIssues
//   - testHostConfigurationWithExplicitPolicyLineageDoesNotFlagBundleOwnedControlPlaneValues
//   - testHostConfigurationWithExplicitPolicyLineageFlagsCompiledGenericRuntimeTuning
//   - testHostConfigurationWithExplicitPolicyLineageFlagsSchemaDistinctRuntimeTuningThatStillUsesCompiledGenericFamilies
//   - testSchemaDistinctRuntimeTuningUsesCompiledFallbackEnvelopeWhenGenericFamilyRemains
//   - testSchemaDistinctRuntimeTuningUsesCompiledFallbackEnvelopeWhenPlannerProfilesOrRulesNeedSynthesis
//   - testSchemaDistinctRuntimeTuningUsesCompiledFallbackEnvelopeWhenRunModeProfileOmitsExplicitRiskOrThermalPlannerInputs
//
//   Decoding tests:
//   - testDecodingRejectsPolicyOwnedHostConfigurationMissingDefaultDeviceState
//   - testDecodingRejectsPolicyOwnedHostConfigurationMissingRuntimeTuning
//   - testDecodingRejectsPolicyOwnedHostConfigurationMissingHostRhythmProfile
//   - testDecodingLegacyHostConfigurationWithoutPolicyLineageRejectsMissingDefaultDeviceState
//   - testDecodingNonLegacyHostConfigurationWithoutPolicyLineageRejectsMissingDefaultDeviceState
//   - testDecodingNonLegacyHostConfigurationWithoutPolicyLineageRejectsMissingRuntimeTuning
//   - testDecodingNonLegacyHostConfigurationWithoutPolicyLineageRejectsMissingHostRhythmProfile
//
// **0 behavior change**:test methods literal-identical to
// pre-extraction versions,只是改成了 `extension BASHostKitTests`
// in a new file。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保
//   - chapter 二百一一 single-source-of-truth
//   - chapter 一百三 schemaVersion bump-back-compat 行为不变

import XCTest
@testable import BASAdmin
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

extension BASHostKitTests {
    func testRuntimeTuningSourceResolvesConfiguredPolicy() {
        let registry = BASEBrainRuntimeSynthesisPolicyRegistry(
            schemaVersion: "host.runtime-tuning-registry.v2",
            defaultPolicyID: "baseline",
            policiesByID: [
                "baseline": .generic,
                "field-rollout": BASEBrainRuntimeSynthesisPolicy(
                    schemaVersion: "host.runtime-synthesis.field-rollout.v2",
                    guardrailPressure: .init(
                        protectiveBoundaryIncrement: 0.08,
                        calibrationWatchIncrement: 0.05,
                        calibrationDriftingIncrement: 0.09,
                        boundaryConstraintUnit: 0.02,
                        boundaryConstraintCap: 0.10,
                        calibrationAlertUnit: 0.02,
                        calibrationAlertCap: 0.08,
                        failureGuardUnit: 0.01,
                        failureGuardCap: 0.06,
                        riskFlagUnit: 0.02,
                        riskFlagCap: 0.09,
                        maximumPressure: 0.44
                    ),
                    budget: .init(
                        standardDecodeTokens: 160,
                        unstableDecodeTokens: 192,
                        guardedDecodeTokens: 220,
                        maintenanceBatteryFloor: 0.35
                    ),
                    hostThresholds: .init(
                        caution: 0.45,
                        protective: 0.72,
                        block: 0.92
                    )
                )
            ]
        )

        let source = BASEBrainRuntimeSynthesisPolicySource(
            registry: registry,
            policyID: "field-rollout"
        )

        XCTAssertEqual(source.registryVersion, "host.runtime-tuning-registry.v2")
        XCTAssertEqual(source.policyID, "field-rollout")
        XCTAssertEqual(
            source.resolvedPolicy.schemaVersion,
            "host.runtime-synthesis.field-rollout.v2"
        )
    }

    func testRuntimeTuningSourceExposesUnavailablePolicyWithoutSilentlyFallingBackToGeneric() {
        let registry = BASEBrainRuntimeSynthesisPolicyRegistry(
            schemaVersion: "host.runtime-tuning-registry.v2",
            defaultPolicyID: "baseline",
            policiesByID: [:]
        )

        let source = BASEBrainRuntimeSynthesisPolicySource(
            registry: registry,
            policyID: "field-rollout"
        )

        XCTAssertNil(source.resolvedPolicyIfAvailable)
        XCTAssertEqual(
            source.resolvedPolicy.schemaVersion,
            "host.runtime-synthesis.missing.v1"
        )
    }

    func testRuntimeTuningSourceTreatsUnknownExplicitPolicyAsMissingInsteadOfPromotingRegistryDefault() {
        let registry = BASEBrainRuntimeSynthesisPolicyRegistry(
            schemaVersion: "host.runtime-tuning-registry.v2",
            defaultPolicyID: "baseline",
            policiesByID: [
                "baseline": .generic
            ]
        )

        let source = BASEBrainRuntimeSynthesisPolicySource(
            registry: registry,
            policyID: "field-rollout"
        )

        XCTAssertNil(source.resolvedPolicyIfAvailable)
        XCTAssertEqual(
            source.resolvedPolicy.schemaVersion,
            "host.runtime-synthesis.missing.v1"
        )
    }

    func testGenericHostConfigurationSurfacesCompiledControlPlaneFallbackIssues() {
        let configuration = BASHostConfiguration.fixtureGeneric

        XCTAssertEqual(
            configuration.controlPlaneIssues,
            [
                .missingRuntimePolicyLineage,
                .compiledDefaultDeviceState,
                .compiledRuntimeTuning,
                .compiledHostRhythmProfile
            ]
        )
    }

    func testHostConfigurationWithExplicitPolicyLineageDoesNotFlagBundleOwnedControlPlaneValues() {
        let configuration = BASHostConfiguration(
            runtimeProfileID: "before.local-cognition",
            policyProfileID: "before.product-policy",
            prefersPureLocal: true,
            defaultDeviceState: BASHostConfiguration.fixtureDefaultDeviceState,
            console: .generic,
            lifecycleBehavior: .generic,
            workflowBehavior: .generic,
            cognitionBehavior: .generic,
            presentation: .generic,
            runtimeTuning: makePolicyOwnedRuntimeTuning(),
            runtimePolicyLineage: BASRuntimePolicyLineage(
                bundleVersion: "before.runtime-policy-bundle.v1",
                providerRoutingRegistryVersion: "before.provider-routing-registry.v1",
                providerRoutingPolicyID: "before.provider-routing.v1",
                runtimeTuningRegistryVersion: "before.host.runtime-synthesis-registry.v1",
                runtimeTuningPolicyID: "before.host.runtime-synthesis.v1",
                resolutionSourceID: "bundled_default"
            ),
            hostRhythmProfile: .generic
        )

        XCTAssertTrue(configuration.controlPlaneIssues.isEmpty)
    }

    func testHostConfigurationWithExplicitPolicyLineageFlagsCompiledGenericRuntimeTuning() {
        let configuration = BASHostConfiguration(
            runtimeProfileID: "before.local-cognition",
            policyProfileID: "before.product-policy",
            prefersPureLocal: true,
            defaultDeviceState: BASHostConfiguration.fixtureDefaultDeviceState,
            console: .generic,
            lifecycleBehavior: .generic,
            workflowBehavior: .generic,
            cognitionBehavior: .generic,
            presentation: .generic,
            runtimeTuning: .generic,
            runtimePolicyLineage: BASRuntimePolicyLineage(
                bundleVersion: "before.runtime-policy-bundle.v1",
                providerRoutingRegistryVersion: "before.provider-routing-registry.v1",
                providerRoutingPolicyID: "before.provider-routing.v1",
                runtimeTuningRegistryVersion: "before.host.runtime-synthesis-registry.v1",
                runtimeTuningPolicyID: "before.host.runtime-synthesis.v1",
                resolutionSourceID: "bundled_default"
            ),
            hostRhythmProfile: .generic
        )

        XCTAssertEqual(configuration.controlPlaneIssues, [.compiledRuntimeTuning])
        XCTAssertEqual(configuration.controlPlaneExecutionDisposition, .quarantine)
    }

    func testHostConfigurationWithExplicitPolicyLineageFlagsSchemaDistinctRuntimeTuningThatStillUsesCompiledGenericFamilies() {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.partial-generic.v1"
        )
        tuning.wakeIntent = .generic

        let configuration = BASHostConfiguration(
            runtimeProfileID: "before.local-cognition",
            policyProfileID: "before.product-policy",
            prefersPureLocal: true,
            defaultDeviceState: BASHostConfiguration.fixtureDefaultDeviceState,
            console: .generic,
            lifecycleBehavior: .generic,
            workflowBehavior: .generic,
            cognitionBehavior: .generic,
            presentation: .generic,
            runtimeTuning: tuning,
            runtimePolicyLineage: BASRuntimePolicyLineage(
                bundleVersion: "before.runtime-policy-bundle.v1",
                providerRoutingRegistryVersion: "before.provider-routing-registry.v1",
                providerRoutingPolicyID: "before.provider-routing.v1",
                runtimeTuningRegistryVersion: "before.host.runtime-synthesis-registry.v1",
                runtimeTuningPolicyID: "before.host.runtime-synthesis.v1",
                resolutionSourceID: "bundled_default"
            ),
            hostRhythmProfile: .generic
        )

        XCTAssertEqual(configuration.controlPlaneIssues, [.compiledRuntimeTuning])
        XCTAssertEqual(configuration.controlPlaneExecutionDisposition, .quarantine)
    }

    func testSchemaDistinctRuntimeTuningUsesCompiledFallbackEnvelopeWhenGenericFamilyRemains() {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.partial-generic.v1"
        )
        tuning.wakeIntent = .generic

        XCTAssertTrue(tuning.usesCompiledFallbackEnvelope)
        XCTAssertEqual(tuning.compiledFallbackComponentIDs, ["wakeIntent"])
    }

    func testSchemaDistinctRuntimeTuningUsesCompiledFallbackEnvelopeWhenPlannerProfilesOrRulesNeedSynthesis() {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.partial-planner.v1"
        )
        tuning.budget.runModeProfilesByID = nil
        tuning.stateTransitions.runModeRules = nil

        XCTAssertTrue(tuning.usesCompiledFallbackEnvelope)
        XCTAssertEqual(
            tuning.compiledFallbackComponentIDs,
            [
                "budget.runModeProfilesByID",
                "stateTransitions.runModeRules"
            ]
        )
    }

    func testSchemaDistinctRuntimeTuningUsesCompiledFallbackEnvelopeWhenRunModeProfileOmitsExplicitRiskOrThermalPlannerInputs() {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.partial-profile-inputs.v1"
        )
        var engageProfile = tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue]
        engageProfile?.unstableLoopIncrementRiskLevels = nil
        engageProfile?.throttlePenaltyThermalLevels = nil
        tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue] = engageProfile

        XCTAssertTrue(tuning.usesCompiledFallbackEnvelope)
        XCTAssertEqual(
            tuning.compiledFallbackComponentIDs,
            ["budget.runModeProfilesByID.engage"]
        )
    }

    func testDecodingRejectsPolicyOwnedHostConfigurationMissingDefaultDeviceState() throws {
        let encoded = try JSONEncoder().encode(
            BASHostConfiguration(
                runtimeProfileID: "before.local-cognition",
                policyProfileID: "before.product-policy",
                prefersPureLocal: true,
                defaultDeviceState: BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: .generic,
                runtimePolicyLineage: BASRuntimePolicyLineage(
                    bundleVersion: "before.runtime-policy-bundle.v1",
                    providerRoutingRegistryVersion: "before.provider-routing-registry.v1",
                    providerRoutingPolicyID: "before.provider-routing.v1",
                    runtimeTuningRegistryVersion: "before.host.runtime-synthesis-registry.v1",
                    runtimeTuningPolicyID: "before.host.runtime-synthesis.v1",
                    resolutionSourceID: "bundled_default"
                ),
                hostRhythmProfile: .generic
            )
        )
        let mutated = try removingKey("defaultDeviceState", fromEncodedJSONObject: encoded)

        XCTAssertThrowsError(
            try JSONDecoder().decode(BASHostConfiguration.self, from: mutated)
        ) { error in
            guard case let DecodingError.keyNotFound(key, _) = error else {
                return XCTFail("Expected missing policy-owned defaultDeviceState to fail decoding, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "defaultDeviceState")
        }
    }

    func testDecodingRejectsPolicyOwnedHostConfigurationMissingRuntimeTuning() throws {
        let encoded = try JSONEncoder().encode(
            BASHostConfiguration(
                runtimeProfileID: "before.local-cognition",
                policyProfileID: "before.product-policy",
                prefersPureLocal: true,
                defaultDeviceState: BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: .generic,
                runtimePolicyLineage: BASRuntimePolicyLineage(
                    bundleVersion: "before.runtime-policy-bundle.v1",
                    providerRoutingRegistryVersion: "before.provider-routing-registry.v1",
                    providerRoutingPolicyID: "before.provider-routing.v1",
                    runtimeTuningRegistryVersion: "before.host.runtime-synthesis-registry.v1",
                    runtimeTuningPolicyID: "before.host.runtime-synthesis.v1",
                    resolutionSourceID: "bundled_default"
                ),
                hostRhythmProfile: .generic
            )
        )
        let mutated = try removingKey("runtimeTuning", fromEncodedJSONObject: encoded)

        XCTAssertThrowsError(
            try JSONDecoder().decode(BASHostConfiguration.self, from: mutated)
        ) { error in
            guard case let DecodingError.keyNotFound(key, _) = error else {
                return XCTFail("Expected missing policy-owned runtimeTuning to fail decoding, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "runtimeTuning")
        }
    }

    func testDecodingRejectsPolicyOwnedHostConfigurationMissingHostRhythmProfile() throws {
        let encoded = try JSONEncoder().encode(
            BASHostConfiguration(
                runtimeProfileID: "before.local-cognition",
                policyProfileID: "before.product-policy",
                prefersPureLocal: true,
                defaultDeviceState: BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: .generic,
                runtimePolicyLineage: BASRuntimePolicyLineage(
                    bundleVersion: "before.runtime-policy-bundle.v1",
                    providerRoutingRegistryVersion: "before.provider-routing-registry.v1",
                    providerRoutingPolicyID: "before.provider-routing.v1",
                    runtimeTuningRegistryVersion: "before.host.runtime-synthesis-registry.v1",
                    runtimeTuningPolicyID: "before.host.runtime-synthesis.v1",
                    resolutionSourceID: "bundled_default"
                ),
                hostRhythmProfile: .generic
            )
        )
        let mutated = try removingKey("hostRhythmProfile", fromEncodedJSONObject: encoded)

        XCTAssertThrowsError(
            try JSONDecoder().decode(BASHostConfiguration.self, from: mutated)
        ) { error in
            guard case let DecodingError.keyNotFound(key, _) = error else {
                return XCTFail("Expected missing policy-owned hostRhythmProfile to fail decoding, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "hostRhythmProfile")
        }
    }

    func testDecodingLegacyHostConfigurationWithoutPolicyLineageRejectsMissingDefaultDeviceState() throws {
        let encoded = try JSONEncoder().encode(BASHostConfiguration.fixtureGeneric)
        let withoutDeviceState = try removingKey("defaultDeviceState", fromEncodedJSONObject: encoded)
        let withoutRuntimeTuning = try removingKey("runtimeTuning", fromEncodedJSONObject: withoutDeviceState)
        let legacyData = try removingKey("hostRhythmProfile", fromEncodedJSONObject: withoutRuntimeTuning)

        XCTAssertThrowsError(
            try JSONDecoder().decode(BASHostConfiguration.self, from: legacyData)
        ) { error in
            guard case let DecodingError.keyNotFound(key, _) = error else {
                return XCTFail("Expected legacy host configuration missing control-plane fields to fail decoding, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "defaultDeviceState")
        }
    }

    func testDecodingNonLegacyHostConfigurationWithoutPolicyLineageRejectsMissingDefaultDeviceState() throws {
        let encoded = try JSONEncoder().encode(
            BASHostConfiguration(
                runtimeProfileID: "before.local-cognition.v2",
                policyProfileID: "before.product-policy.v2",
                prefersPureLocal: true,
                defaultDeviceState: BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: .generic,
                runtimePolicyLineage: nil,
                hostRhythmProfile: .generic
            )
        )
        let mutated = try removingKey("defaultDeviceState", fromEncodedJSONObject: encoded)

        XCTAssertThrowsError(
            try JSONDecoder().decode(BASHostConfiguration.self, from: mutated)
        ) { error in
            guard case let DecodingError.keyNotFound(key, _) = error else {
                return XCTFail("Expected missing non-legacy defaultDeviceState to fail decoding, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "defaultDeviceState")
        }
    }

    func testDecodingNonLegacyHostConfigurationWithoutPolicyLineageRejectsMissingRuntimeTuning() throws {
        let encoded = try JSONEncoder().encode(
            BASHostConfiguration(
                runtimeProfileID: "before.local-cognition.v2",
                policyProfileID: "before.product-policy.v2",
                prefersPureLocal: true,
                defaultDeviceState: BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: .generic,
                runtimePolicyLineage: nil,
                hostRhythmProfile: .generic
            )
        )
        let mutated = try removingKey("runtimeTuning", fromEncodedJSONObject: encoded)

        XCTAssertThrowsError(
            try JSONDecoder().decode(BASHostConfiguration.self, from: mutated)
        ) { error in
            guard case let DecodingError.keyNotFound(key, _) = error else {
                return XCTFail("Expected missing non-legacy runtimeTuning to fail decoding, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "runtimeTuning")
        }
    }

    func testDecodingNonLegacyHostConfigurationWithoutPolicyLineageRejectsMissingHostRhythmProfile() throws {
        let encoded = try JSONEncoder().encode(
            BASHostConfiguration(
                runtimeProfileID: "before.local-cognition.v2",
                policyProfileID: "before.product-policy.v2",
                prefersPureLocal: true,
                defaultDeviceState: BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: .generic,
                runtimePolicyLineage: nil,
                hostRhythmProfile: .generic
            )
        )
        let mutated = try removingKey("hostRhythmProfile", fromEncodedJSONObject: encoded)

        XCTAssertThrowsError(
            try JSONDecoder().decode(BASHostConfiguration.self, from: mutated)
        ) { error in
            guard case let DecodingError.keyNotFound(key, _) = error else {
                return XCTFail("Expected missing non-legacy hostRhythmProfile to fail decoding, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "hostRhythmProfile")
        }
    }

    private func removingKey(_ key: String, fromEncodedJSONObject data: Data) throws -> Data {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object.removeValue(forKey: key)
        return try JSONSerialization.data(withJSONObject: object)
    }

}

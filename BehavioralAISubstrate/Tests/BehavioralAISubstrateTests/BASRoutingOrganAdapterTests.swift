import XCTest
@testable import BASOrgan
@testable import BASObservability

/// M255 — coverage for `BASRoutingOrganAdapter`.
///
/// Uses two stub `BASOrganAdapter` implementations: one configurable
/// to throw any error / return any draft, another always returning
/// a fixed draft. Exercises strategy dispatch, fallback triggers,
/// and the synthesized descriptor.
final class BASRoutingOrganAdapterTests: XCTestCase {

    // MARK: - Strategy dispatch

    func testUnavailablePrimaryNeverInvokesRemoteFallback() async {
        let primary = StubAdapter(
            providerID: "local",
            response: .draftThrows(
                .providerUnavailable(
                    reason: "selected-local-unavailable")))
        let remote = StubAdapter(
            providerID: "remote",
            runsOnDevice: false,
            response: .draftSucceeds(body: "must-not-run"))
        let router = BASRoutingOrganAdapter(
            primary: primary,
            secondary: remote,
            strategy: .primaryWithFallback)

        do {
            _ = try await router.draft(makeRequest())
            XCTFail("a local outage must not invoke a remote provider")
        } catch BASOrganError.providerUnavailable(let reason) {
            XCTAssertEqual(reason, "selected-local-unavailable")
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let remoteCalls = await remote.plainDraftCount
        XCTAssertEqual(remoteCalls, 0)
    }

    func testDefaultUsesPrimaryWhenHealthy() async
    throws {
        let primary = StubAdapter(
            providerID: "primary",
            response: .draftSucceeds(body: "from-primary"))
        let secondary = StubAdapter(
            providerID: "secondary",
            response: .draftSucceeds(body: "from-secondary"))
        let router = BASRoutingOrganAdapter(
            primary: primary, secondary: secondary)

        let draft = try await router.draft(makeRequest())
        XCTAssertEqual(draft.body, "from-primary")
        XCTAssertEqual(draft.providerID, "primary")
    }

    func testPrimaryWithFallbackFallsThroughOnUnavailable() async
    throws {
        let primary = StubAdapter(
            providerID: "primary",
            response: .draftThrows(
                BASOrganError.providerUnavailable(
                    reason: "test-unavail")))
        let secondary = StubAdapter(
            providerID: "secondary",
            response: .draftSucceeds(body: "from-secondary"))
        let router = BASRoutingOrganAdapter(
            primary: primary, secondary: secondary,
            strategy: .primaryWithFallback)

        let draft = try await router.draft(makeRequest())
        XCTAssertEqual(draft.body, "from-secondary")
        XCTAssertEqual(draft.providerID, "secondary")
    }

    func testPrimaryWithFallbackFallsThroughOnPressureRefusal()
    async throws {
        let primary = StubAdapter(
            providerID: "primary",
            response: .draftThrows(
                BASOrganError.pressureRefusal(
                    reason: "thermal")))
        let secondary = StubAdapter(
            providerID: "secondary",
            response: .draftSucceeds(body: "from-secondary"))
        let router = BASRoutingOrganAdapter(
            primary: primary, secondary: secondary,
            strategy: .primaryWithFallback)

        let draft = try await router.draft(makeRequest())
        XCTAssertEqual(draft.providerID, "secondary")
    }

    func testPrimaryWithFallbackPropagatesUnsupportedRole() async
    {
        // Both adapters claim only .scout. Caller asks for .core.
        // Router rejects up-front — fallback would also fail.
        let primary = StubAdapter(
            providerID: "primary",
            supportedRoles: [.scout],
            response: .draftSucceeds(body: "x"))
        let secondary = StubAdapter(
            providerID: "secondary",
            supportedRoles: [.scout],
            response: .draftSucceeds(body: "x"))
        let router = BASRoutingOrganAdapter(
            primary: primary, secondary: secondary,
            strategy: .primaryWithFallback)

        do {
            _ = try await router.draft(makeRequest(role: .core))
            XCTFail("expected unsupportedRole")
        } catch BASOrganError.unsupportedRole(let role) {
            XCTAssertEqual(role, .core)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testPrimaryWithFallbackPropagatesInputTooLong() async {
        // input-too-long is a hard limit, not infra failure;
        // secondary wouldn't accept the larger input either.
        let primary = StubAdapter(
            providerID: "primary",
            response: .draftThrows(
                BASOrganError.inputTooLong(
                    limit: 100, actual: 200)))
        let secondary = StubAdapter(
            providerID: "secondary",
            response: .draftSucceeds(body: "from-secondary"))
        let router = BASRoutingOrganAdapter(
            primary: primary, secondary: secondary,
            strategy: .primaryWithFallback)

        do {
            _ = try await router.draft(makeRequest())
            XCTFail("expected inputTooLong to propagate")
        } catch BASOrganError.inputTooLong(let limit, let actual) {
            XCTAssertEqual(limit, 100)
            XCTAssertEqual(actual, 200)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testPrimaryWithFallbackPropagatesDeadlineExpired() async
    {
        let primary = StubAdapter(
            providerID: "primary",
            response: .draftThrows(
                BASOrganError.deadlineExpired))
        let secondary = StubAdapter(
            providerID: "secondary",
            response: .draftSucceeds(body: "from-secondary"))
        let router = BASRoutingOrganAdapter(
            primary: primary, secondary: secondary,
            strategy: .primaryWithFallback)

        do {
            _ = try await router.draft(makeRequest())
            XCTFail("expected deadlineExpired to propagate")
        } catch BASOrganError.deadlineExpired {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testPrimaryOnlyNeverInvokesSecondary() async throws {
        let primary = StubAdapter(
            providerID: "primary",
            response: .draftSucceeds(body: "from-primary"))
        let secondary = StubAdapter(
            providerID: "secondary",
            response: .draftSucceeds(body: "from-secondary"))
        let router = BASRoutingOrganAdapter(
            primary: primary,
            secondary: secondary,
            strategy: .primaryOnly)

        let draft = try await router.draft(makeRequest())
        XCTAssertEqual(draft.providerID, "primary")
    }

    func testPrimaryOnlyPropagatesProviderUnavailable() async {
        // Even infra failures don't fall through under
        // .primaryOnly — the strategy says secondary is held but
        // never invoked.
        let primary = StubAdapter(
            providerID: "primary",
            response: .draftThrows(
                BASOrganError.providerUnavailable(
                    reason: "primary-down")))
        let secondary = StubAdapter(
            providerID: "secondary",
            response: .draftSucceeds(body: "from-secondary"))
        let router = BASRoutingOrganAdapter(
            primary: primary,
            secondary: secondary,
            strategy: .primaryOnly)

        do {
            _ = try await router.draft(makeRequest())
            XCTFail("expected providerUnavailable to propagate")
        } catch BASOrganError.providerUnavailable(let reason) {
            XCTAssertEqual(reason, "primary-down")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testSecondaryOnlyNeverInvokesPrimary() async throws {
        let primary = StubAdapter(
            providerID: "primary",
            response: .draftSucceeds(body: "from-primary"))
        let secondary = StubAdapter(
            providerID: "secondary",
            response: .draftSucceeds(body: "from-secondary"))
        let router = BASRoutingOrganAdapter(
            primary: primary,
            secondary: secondary,
            strategy: .secondaryOnly)

        let draft = try await router.draft(makeRequest())
        XCTAssertEqual(draft.providerID, "secondary")
    }

    // MARK: - Descriptor synthesis

    func testDescriptorComposesProviderIDFromBoth() {
        let p = StubAdapter(
            providerID: "p1",
            response: .draftSucceeds(body: ""))
        let s = StubAdapter(
            providerID: "s1",
            response: .draftSucceeds(body: ""))
        let router = BASRoutingOrganAdapter(
            primary: p, secondary: s,
            strategy: .primaryWithFallback)
        XCTAssertEqual(
            router.descriptor.providerID, "routing.p1+s1")
    }

    func testDescriptorOverridesUseExplicitValues() {
        let p = StubAdapter(
            providerID: "p1",
            response: .draftSucceeds(body: ""))
        let s = StubAdapter(
            providerID: "s1",
            response: .draftSucceeds(body: ""))
        let router = BASRoutingOrganAdapter(
            primary: p, secondary: s,
            providerID: "host.custom.id",
            providerName: "Host Custom Name")
        XCTAssertEqual(
            router.descriptor.providerID, "host.custom.id")
        XCTAssertEqual(
            router.descriptor.providerName, "Host Custom Name")
    }

    func testDescriptorSupportedRolesIsIntersection() {
        let p = StubAdapter(
            providerID: "p", supportedRoles: [.scout, .core],
            response: .draftSucceeds(body: ""))
        let s = StubAdapter(
            providerID: "s", supportedRoles: [.scout],
            response: .draftSucceeds(body: ""))
        let router = BASRoutingOrganAdapter(
            primary: p, secondary: s,
            strategy: .primaryWithFallback)
        XCTAssertEqual(router.descriptor.supportedRoles, [.scout])
    }

    func testDescriptorMaxTokensIsMin() {
        let p = StubAdapter(
            providerID: "p",
            maxInputTokens: 4096, maxOutputTokens: 4096,
            response: .draftSucceeds(body: ""))
        let s = StubAdapter(
            providerID: "s",
            maxInputTokens: 1024, maxOutputTokens: 512,
            response: .draftSucceeds(body: ""))
        let fallbackRouter = BASRoutingOrganAdapter(
            primary: p, secondary: s,
            strategy: .primaryWithFallback)
        XCTAssertEqual(fallbackRouter.descriptor.maxInputTokens, 1024)
        XCTAssertEqual(fallbackRouter.descriptor.maxOutputTokens, 512)
    }

    func testDescriptorStreamingIsAndOfBoth() {
        let pYes = StubAdapter(
            providerID: "p",
            supportsStreaming: true,
            response: .draftSucceeds(body: ""))
        let sNo = StubAdapter(
            providerID: "s",
            supportsStreaming: false,
            response: .draftSucceeds(body: ""))
        let router = BASRoutingOrganAdapter(
            primary: pYes, secondary: sNo,
            strategy: .primaryWithFallback)
        XCTAssertFalse(
            router.descriptor.supportsStreaming,
            "streaming AND'd: false if either side is false")
    }

    // MARK: - Capacity

    func testCapacityReportsPrimaryWhenPrimaryHealthy() async {
        let p = StubAdapter(
            providerID: "p",
            response: .draftSucceeds(body: ""),
            capacity: BASOrganCapacity(
                availableInputTokens: 4096,
                availableOutputTokens: 1024,
                underPressure: false))
        let s = StubAdapter(
            providerID: "s",
            response: .draftSucceeds(body: ""),
            capacity: BASOrganCapacity(
                availableInputTokens: 100,
                availableOutputTokens: 100,
                underPressure: false))
        let router = BASRoutingOrganAdapter(
            primary: p, secondary: s,
            strategy: .primaryWithFallback)
        let cap = await router.currentCapacity()
        XCTAssertEqual(cap.availableInputTokens, 4096)
        XCTAssertEqual(cap.availableOutputTokens, 1024)
    }

    func testCapacityReportsSecondaryWhenPrimaryUnderPressure()
    async {
        let p = StubAdapter(
            providerID: "p",
            response: .draftSucceeds(body: ""),
            capacity: BASOrganCapacity(
                availableInputTokens: 0,
                availableOutputTokens: 0,
                underPressure: true,
                reasonCodes: ["thermal"]))
        let s = StubAdapter(
            providerID: "s",
            response: .draftSucceeds(body: ""),
            capacity: BASOrganCapacity(
                availableInputTokens: 1024,
                availableOutputTokens: 256,
                underPressure: false))
        let router = BASRoutingOrganAdapter(
            primary: p, secondary: s,
            strategy: .primaryWithFallback)
        let cap = await router.currentCapacity()
        XCTAssertEqual(cap.availableInputTokens, 1024)
        XCTAssertFalse(cap.underPressure)
    }

    // MARK: - On-device automatic-fallback boundary

    func testRemoteSecondaryNeverReceivesInfrastructureFallbackAcrossDraftPaths()
    async {
        let failures: [BASOrganError] = [
            .providerUnavailable(reason: "selected-local-unavailable"),
            .pressureRefusal(reason: "selected-local-pressure")
        ]

        for failure in failures {
            for path in InvocationPath.allCases {
                let primary = StubAdapter(
                    providerID: "local",
                    response: .draftThrows(failure))
                let remote = StubAdapter(
                    providerID: "remote",
                    runsOnDevice: false,
                    response: .draftSucceeds(body: "must-not-run"))
                let router = BASRoutingOrganAdapter(
                    primary: primary,
                    secondary: remote,
                    strategy: .primaryWithFallback)

                do {
                    _ = try await invoke(
                        router, path: path, request: makeFixedRequest())
                    XCTFail("expected original \(failure) on \(path)")
                } catch let actual as BASOrganError {
                    XCTAssertEqual(actual, failure, "path=\(path)")
                } catch {
                    XCTFail("unexpected error on \(path): \(error)")
                }

                await assertTotalDraftCount(
                    primary, expected: 1,
                    "primary must be called once on \(path)")
                await assertTotalDraftCount(
                    remote, expected: 0,
                    "remote must not be called on \(path)")
            }
        }
    }

    func testDefaultStrategyDoesNotSwapToLocalSecondary() async {
        let primary = StubAdapter(
            providerID: "selected-local",
            response: .draftThrows(
                .providerUnavailable(reason: "selected-local-down")))
        let secondary = StubAdapter(
            providerID: "other-local",
            response: .draftSucceeds(body: "must-not-run"))
        let router = BASRoutingOrganAdapter(
            primary: primary,
            secondary: secondary)

        do {
            _ = try await router.draft(makeFixedRequest())
            XCTFail("default routing must preserve the selected provider")
        } catch let actual as BASOrganError {
            XCTAssertEqual(
                actual,
                .providerUnavailable(reason: "selected-local-down"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        await assertTotalDraftCount(primary, expected: 1)
        await assertTotalDraftCount(secondary, expected: 0)
    }

    func testCancellationNeverInvokesSecondaryAcrossDraftPaths() async {
        for path in InvocationPath.allCases {
            let primary = StubAdapter(
                providerID: "local",
                response: .cancellation)
            let secondary = StubAdapter(
                providerID: "local-secondary",
                response: .draftSucceeds(body: "must-not-run"))
            let router = BASRoutingOrganAdapter(
                primary: primary,
                secondary: secondary,
                strategy: .primaryWithFallback)

            do {
                _ = try await invoke(
                    router, path: path, request: makeFixedRequest())
                XCTFail("expected cancellation on \(path)")
            } catch is CancellationError {
                // Exact non-BAS cancellation type preserved.
            } catch {
                XCTFail("unexpected error on \(path): \(error)")
            }

            await assertTotalDraftCount(primary, expected: 1)
            await assertTotalDraftCount(secondary, expected: 0)
        }
    }

    func testNonInfrastructureFailuresNeverInvokeSecondaryAcrossDraftPaths()
    async {
        let failures: [BASOrganError] = [
            .inputTooLong(limit: 12, actual: 13),
            .deadlineExpired
        ]
        for failure in failures {
            for path in InvocationPath.allCases {
                let primary = StubAdapter(
                    providerID: "local",
                    response: .draftThrows(failure))
                let secondary = StubAdapter(
                    providerID: "local-secondary",
                    response: .draftSucceeds(body: "must-not-run"))
                let router = BASRoutingOrganAdapter(
                    primary: primary,
                    secondary: secondary,
                    strategy: .primaryWithFallback)

                do {
                    _ = try await invoke(
                        router, path: path, request: makeFixedRequest())
                    XCTFail("expected \(failure) on \(path)")
                } catch let actual as BASOrganError {
                    XCTAssertEqual(actual, failure, "path=\(path)")
                } catch {
                    XCTFail("unexpected error on \(path): \(error)")
                }

                await assertTotalDraftCount(primary, expected: 1)
                await assertTotalDraftCount(secondary, expected: 0)
            }
        }
    }

    func testUnsupportedRoleNeverInvokesEitherProviderAcrossDraftPaths()
    async {
        for path in InvocationPath.allCases {
            let primary = StubAdapter(
                providerID: "local",
                supportedRoles: [.scout],
                response: .draftSucceeds(body: "must-not-run"))
            let secondary = StubAdapter(
                providerID: "local-secondary",
                supportedRoles: [.scout],
                response: .draftSucceeds(body: "must-not-run"))
            let router = BASRoutingOrganAdapter(
                primary: primary,
                secondary: secondary,
                strategy: .primaryWithFallback)

            do {
                _ = try await invoke(
                    router,
                    path: path,
                    request: makeFixedRequest(role: .core))
                XCTFail("expected unsupported role on \(path)")
            } catch let actual as BASOrganError {
                XCTAssertEqual(actual, .unsupportedRole(.core))
            } catch {
                XCTFail("unexpected error on \(path): \(error)")
            }

            await assertTotalDraftCount(primary, expected: 0)
            await assertTotalDraftCount(secondary, expected: 0)
        }
    }

    func testEligibleLocalFallbackForwardsEveryDraftPathExactly() async
    throws {
        for path in InvocationPath.allCases {
            let failure: BASOrganError = path == .elect
                ? .pressureRefusal(reason: "local-pressure")
                : .providerUnavailable(reason: "local-down")
            let primary = StubAdapter(
                providerID: "local-primary",
                response: .draftThrows(failure))
            let secondary = StubAdapter(
                providerID: "local-secondary",
                response: .draftSucceeds(body: "local-fallback"))
            let router = BASRoutingOrganAdapter(
                primary: primary,
                secondary: secondary,
                strategy: .primaryWithFallback)
            let request = makeFixedRequest()

            let draft = try await invoke(
                router, path: path, request: request)
            XCTAssertEqual(draft.providerID, "local-secondary")
            XCTAssertEqual(draft.requestID, request.requestID)
            await assertTotalDraftCount(primary, expected: 1)
            await assertTotalDraftCount(secondary, expected: 1)

            switch path {
            case .plain:
                let forwarded = await secondary.lastPlainRequest
                XCTAssertEqual(forwarded, request)
            case .elect:
                let forwarded = await secondary.lastElectRequest
                let elect = await secondary.lastElect
                XCTAssertEqual(forwarded, request)
                XCTAssertEqual(elect, true)
            case .purpose:
                let forwarded = await secondary.lastPurposeRequest
                let purpose = await secondary.lastPurpose
                XCTAssertEqual(forwarded, request)
                XCTAssertEqual(purpose, .creative)
            }
        }
    }

    func testExclusiveStrategiesSelectOnlyConfiguredProviderAcrossDraftPaths()
    async throws {
        for path in InvocationPath.allCases {
            let primary = StubAdapter(
                providerID: "primary",
                response: .draftSucceeds(body: "primary"))
            let heldSecondary = StubAdapter(
                providerID: "held-secondary",
                runsOnDevice: false,
                response: .draftSucceeds(body: "held"))
            let primaryOnly = BASRoutingOrganAdapter(
                primary: primary,
                secondary: heldSecondary,
                strategy: .primaryOnly)
            let primaryDraft = try await invoke(
                primaryOnly, path: path, request: makeFixedRequest())
            XCTAssertEqual(primaryDraft.providerID, "primary")
            await assertTotalDraftCount(primary, expected: 1)
            await assertTotalDraftCount(heldSecondary, expected: 0)

            let heldPrimary = StubAdapter(
                providerID: "held-primary",
                response: .draftSucceeds(body: "held"))
            let remote = StubAdapter(
                providerID: "selected-remote",
                runsOnDevice: false,
                response: .draftSucceeds(body: "remote"))
            let secondaryOnly = BASRoutingOrganAdapter(
                primary: heldPrimary,
                secondary: remote,
                strategy: .secondaryOnly)
            let secondaryDraft = try await invoke(
                secondaryOnly, path: path, request: makeFixedRequest())
            XCTAssertEqual(secondaryDraft.providerID, "selected-remote")
            await assertTotalDraftCount(heldPrimary, expected: 0)
            await assertTotalDraftCount(remote, expected: 1)
        }
    }

    func testRemoteFallbackCapacityReturnsExactPrimaryWithoutRemoteCall()
    async {
        let primaryCapacity = BASOrganCapacity(
            availableInputTokens: 17,
            availableOutputTokens: 9,
            underPressure: true,
            reasonCodes: ["thermal", "memory"])
        let primary = StubAdapter(
            providerID: "local",
            response: .draftSucceeds(body: ""),
            capacity: primaryCapacity)
        let remote = StubAdapter(
            providerID: "remote",
            runsOnDevice: false,
            response: .draftSucceeds(body: ""),
            capacity: .unlimited)
        let router = BASRoutingOrganAdapter(
            primary: primary,
            secondary: remote,
            strategy: .primaryWithFallback)

        let actual = await router.currentCapacity()
        XCTAssertEqual(actual, primaryCapacity)
        let primaryCalls = await primary.capacityCount
        let remoteCalls = await remote.capacityCount
        XCTAssertEqual(primaryCalls, 1)
        XCTAssertEqual(remoteCalls, 0)
    }

    func testEligibleLocalFallbackCapacityUsesSecondaryUnderPressure()
    async {
        let primary = StubAdapter(
            providerID: "local-primary",
            response: .draftSucceeds(body: ""),
            capacity: BASOrganCapacity(
                availableInputTokens: 0,
                availableOutputTokens: 0,
                underPressure: true,
                reasonCodes: ["thermal"]))
        let secondaryCapacity = BASOrganCapacity(
            availableInputTokens: 31,
            availableOutputTokens: 15,
            underPressure: false,
            reasonCodes: ["secondary-ready"])
        let secondary = StubAdapter(
            providerID: "local-secondary",
            response: .draftSucceeds(body: ""),
            capacity: secondaryCapacity)
        let router = BASRoutingOrganAdapter(
            primary: primary,
            secondary: secondary,
            strategy: .primaryWithFallback)

        let actual = await router.currentCapacity()
        XCTAssertEqual(actual, secondaryCapacity)
        let primaryCalls = await primary.capacityCount
        let secondaryCalls = await secondary.capacityCount
        XCTAssertEqual(primaryCalls, 1)
        XCTAssertEqual(secondaryCalls, 1)
    }

    func testDescriptorCapabilitiesFollowReachableProvidersAndKeepIdentity()
    {
        let primary = StubAdapter(
            providerID: "p",
            supportsStreaming: true,
            maxInputTokens: 400,
            maxOutputTokens: 300,
            runsOnDevice: true,
            supportedRoles: [.scout, .core],
            response: .draftSucceeds(body: ""))
        let secondary = StubAdapter(
            providerID: "s",
            supportsStreaming: false,
            maxInputTokens: 100,
            maxOutputTokens: 80,
            runsOnDevice: false,
            supportedRoles: [.core],
            response: .draftSucceeds(body: ""))

        let defaultRouter = BASRoutingOrganAdapter(
            primary: primary, secondary: secondary)
        let remoteFallback = BASRoutingOrganAdapter(
            primary: primary, secondary: secondary,
            strategy: .primaryWithFallback)
        let secondaryOnly = BASRoutingOrganAdapter(
            primary: primary, secondary: secondary,
            strategy: .secondaryOnly)

        for router in [defaultRouter, remoteFallback, secondaryOnly] {
            XCTAssertEqual(router.descriptor.providerID, "routing.p+s")
            XCTAssertEqual(
                router.descriptor.providerName,
                "Routing(Stub: p + Stub: s)")
            XCTAssertNil(router.descriptor.providerKind)
            XCTAssertNil(router.descriptor.certificationTier)
            XCTAssertNil(router.descriptor.modelSizeHint)
        }

        for router in [defaultRouter, remoteFallback] {
            XCTAssertTrue(router.descriptor.supportsStreaming)
            XCTAssertEqual(router.descriptor.maxInputTokens, 400)
            XCTAssertEqual(router.descriptor.maxOutputTokens, 300)
            XCTAssertTrue(router.descriptor.runsOnDevice)
            XCTAssertEqual(
                router.descriptor.supportedRoles, [.scout, .core])
        }

        XCTAssertFalse(secondaryOnly.descriptor.supportsStreaming)
        XCTAssertEqual(secondaryOnly.descriptor.maxInputTokens, 100)
        XCTAssertEqual(secondaryOnly.descriptor.maxOutputTokens, 80)
        XCTAssertFalse(secondaryOnly.descriptor.runsOnDevice)
        XCTAssertEqual(secondaryOnly.descriptor.supportedRoles, [.core])
    }

    func testEligibleLocalFallbackDescriptorIsConservativeCombination()
    {
        let primary = StubAdapter(
            providerID: "p",
            supportsStreaming: true,
            maxInputTokens: 400,
            maxOutputTokens: 80,
            supportedRoles: [.scout, .core],
            response: .draftSucceeds(body: ""))
        let secondary = StubAdapter(
            providerID: "s",
            supportsStreaming: false,
            maxInputTokens: 100,
            maxOutputTokens: 300,
            supportedRoles: [.core],
            response: .draftSucceeds(body: ""))
        let router = BASRoutingOrganAdapter(
            primary: primary,
            secondary: secondary,
            strategy: .primaryWithFallback)

        XCTAssertFalse(router.descriptor.supportsStreaming)
        XCTAssertEqual(router.descriptor.maxInputTokens, 100)
        XCTAssertEqual(router.descriptor.maxOutputTokens, 80)
        XCTAssertTrue(router.descriptor.runsOnDevice)
        XCTAssertEqual(router.descriptor.supportedRoles, [.core])
    }

    func testNestedRouterAdvertisesAndExecutesOnlyReachableLocalPath()
    async throws {
        let outerPrimary = StubAdapter(
            providerID: "outer-local",
            response: .draftThrows(
                .providerUnavailable(reason: "outer-down")))
        let innerLocal = StubAdapter(
            providerID: "inner-local",
            response: .draftSucceeds(body: "inner-local"))
        let heldRemote = StubAdapter(
            providerID: "held-remote",
            runsOnDevice: false,
            response: .draftSucceeds(body: "must-not-run"))
        let inner = BASRoutingOrganAdapter(
            primary: innerLocal,
            secondary: heldRemote,
            strategy: .primaryWithFallback)
        XCTAssertTrue(inner.descriptor.runsOnDevice)
        let outer = BASRoutingOrganAdapter(
            primary: outerPrimary,
            secondary: inner,
            strategy: .primaryWithFallback)

        let draft = try await outer.draft(makeFixedRequest())
        XCTAssertEqual(draft.providerID, "inner-local")
        await assertTotalDraftCount(outerPrimary, expected: 1)
        await assertTotalDraftCount(innerLocal, expected: 1)
        await assertTotalDraftCount(heldRemote, expected: 0)
    }

    func testNestedLocalFailurePropagatesWithoutHeldRemoteRoute() async {
        let outerPrimary = StubAdapter(
            providerID: "outer-local",
            response: .draftThrows(
                .providerUnavailable(reason: "outer-down")))
        let innerLocal = StubAdapter(
            providerID: "inner-local",
            response: .draftThrows(
                .pressureRefusal(reason: "inner-pressure")))
        let heldRemote = StubAdapter(
            providerID: "held-remote",
            runsOnDevice: false,
            response: .draftSucceeds(body: "must-not-run"))
        let inner = BASRoutingOrganAdapter(
            primary: innerLocal,
            secondary: heldRemote,
            strategy: .primaryWithFallback)
        let outer = BASRoutingOrganAdapter(
            primary: outerPrimary,
            secondary: inner,
            strategy: .primaryWithFallback)

        do {
            _ = try await outer.draft(makeFixedRequest())
            XCTFail("expected exact inner failure")
        } catch let actual as BASOrganError {
            XCTAssertEqual(
                actual,
                .pressureRefusal(reason: "inner-pressure"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        await assertTotalDraftCount(outerPrimary, expected: 1)
        await assertTotalDraftCount(innerLocal, expected: 1)
        await assertTotalDraftCount(heldRemote, expected: 0)
    }

    func testNestedCapacityNeverConsultsHeldRemote() async {
        let outerPrimary = StubAdapter(
            providerID: "outer-local",
            response: .draftSucceeds(body: ""),
            capacity: BASOrganCapacity(
                availableInputTokens: 0,
                availableOutputTokens: 0,
                underPressure: true))
        let innerCapacity = BASOrganCapacity(
            availableInputTokens: 7,
            availableOutputTokens: 3,
            underPressure: true,
            reasonCodes: ["inner-pressure"])
        let innerLocal = StubAdapter(
            providerID: "inner-local",
            response: .draftSucceeds(body: ""),
            capacity: innerCapacity)
        let heldRemote = StubAdapter(
            providerID: "held-remote",
            runsOnDevice: false,
            response: .draftSucceeds(body: ""),
            capacity: .unlimited)
        let inner = BASRoutingOrganAdapter(
            primary: innerLocal,
            secondary: heldRemote,
            strategy: .primaryWithFallback)
        let outer = BASRoutingOrganAdapter(
            primary: outerPrimary,
            secondary: inner,
            strategy: .primaryWithFallback)

        let actual = await outer.currentCapacity()
        XCTAssertEqual(actual, innerCapacity)
        let outerCalls = await outerPrimary.capacityCount
        let innerCalls = await innerLocal.capacityCount
        let remoteCalls = await heldRemote.capacityCount
        XCTAssertEqual(outerCalls, 1)
        XCTAssertEqual(innerCalls, 1)
        XCTAssertEqual(remoteCalls, 0)
    }

    func testNestedExclusiveLocalityControlsWithoutExecution() async {
        let localPrimary = StubAdapter(
            providerID: "local-primary",
            supportsStreaming: false,
            maxInputTokens: 100,
            supportedRoles: [.core],
            response: .draftSucceeds(body: ""))
        let heldRemoteA = StubAdapter(
            providerID: "held-remote-a",
            runsOnDevice: false,
            response: .draftSucceeds(body: ""))
        let innerPrimaryOnly = BASRoutingOrganAdapter(
            primary: localPrimary,
            secondary: heldRemoteA,
            strategy: .primaryOnly)

        let heldLocal = StubAdapter(
            providerID: "held-local",
            response: .draftSucceeds(body: ""))
        let selectedRemote = StubAdapter(
            providerID: "selected-remote",
            maxInputTokens: 50,
            runsOnDevice: false,
            supportedRoles: [.scout],
            response: .draftSucceeds(body: ""))
        let innerSecondaryOnly = BASRoutingOrganAdapter(
            primary: heldLocal,
            secondary: selectedRemote,
            strategy: .secondaryOnly)

        XCTAssertTrue(innerPrimaryOnly.descriptor.runsOnDevice)
        XCTAssertFalse(innerSecondaryOnly.descriptor.runsOnDevice)

        let outerPrimaryA = StubAdapter(
            providerID: "outer-a",
            maxInputTokens: 400,
            supportedRoles: [.scout, .core],
            response: .draftSucceeds(body: ""))
        let eligibleOuter = BASRoutingOrganAdapter(
            primary: outerPrimaryA,
            secondary: innerPrimaryOnly,
            strategy: .primaryWithFallback)
        XCTAssertEqual(eligibleOuter.descriptor.maxInputTokens, 100)
        XCTAssertFalse(eligibleOuter.descriptor.supportsStreaming)
        XCTAssertEqual(eligibleOuter.descriptor.supportedRoles, [.core])

        let outerPrimaryB = StubAdapter(
            providerID: "outer-b",
            maxInputTokens: 400,
            supportedRoles: [.scout, .core],
            response: .draftSucceeds(body: ""))
        let ineligibleOuter = BASRoutingOrganAdapter(
            primary: outerPrimaryB,
            secondary: innerSecondaryOnly,
            strategy: .primaryWithFallback)
        XCTAssertEqual(ineligibleOuter.descriptor.maxInputTokens, 400)
        XCTAssertTrue(ineligibleOuter.descriptor.supportsStreaming)
        XCTAssertEqual(
            ineligibleOuter.descriptor.supportedRoles, [.scout, .core])

        await assertTotalDraftCount(localPrimary, expected: 0)
        await assertTotalDraftCount(heldRemoteA, expected: 0)
        await assertTotalDraftCount(heldLocal, expected: 0)
        await assertTotalDraftCount(selectedRemote, expected: 0)
        await assertTotalDraftCount(outerPrimaryA, expected: 0)
        await assertTotalDraftCount(outerPrimaryB, expected: 0)
    }

    func testTwoLocalNestedRoutersRetainConservativeCapabilities() {
        let localA = StubAdapter(
            providerID: "a",
            supportsStreaming: true,
            maxInputTokens: 500,
            maxOutputTokens: 400,
            supportedRoles: [.scout, .core],
            response: .draftSucceeds(body: ""))
        let localB = StubAdapter(
            providerID: "b",
            supportsStreaming: false,
            maxInputTokens: 300,
            maxOutputTokens: 200,
            supportedRoles: [.core],
            response: .draftSucceeds(body: ""))
        let inner = BASRoutingOrganAdapter(
            primary: localA,
            secondary: localB,
            strategy: .primaryWithFallback)
        let localC = StubAdapter(
            providerID: "c",
            supportsStreaming: true,
            maxInputTokens: 100,
            maxOutputTokens: 250,
            supportedRoles: [.scout, .core],
            response: .draftSucceeds(body: ""))
        let outer = BASRoutingOrganAdapter(
            primary: localC,
            secondary: inner,
            strategy: .primaryWithFallback)

        XCTAssertFalse(outer.descriptor.supportsStreaming)
        XCTAssertEqual(outer.descriptor.maxInputTokens, 100)
        XCTAssertEqual(outer.descriptor.maxOutputTokens, 200)
        XCTAssertTrue(outer.descriptor.runsOnDevice)
        XCTAssertEqual(outer.descriptor.supportedRoles, [.core])
    }

    // MARK: - M264 — end-to-end smoke

    /// Compose router + draft + L13 lifecycle in one flow: primary
    /// down, secondary answers, draft turns into a ticket, ticket
    /// walks through `proposed → trialing → trialPassed →
    /// queuedForDistillation → distilled`. Exercises the seams
    /// every M254-M262 milestone wired up.
    func testEndToEndRouterFallbackPlusLifecycleHappyPath() async
    throws {
        // -- Stage 1: routing adapter with primary down --
        let primary = StubAdapter(
            providerID: "primary-down",
            response: .draftThrows(
                BASOrganError.providerUnavailable(
                    reason: "simulated outage")))
        let secondary = StubAdapter(
            providerID: "secondary-up",
            response: .draftSucceeds(
                body: "[NEEDS_PERMIT] action: write profile " +
                "field"))
        let router = BASRoutingOrganAdapter(
            primary: primary,
            secondary: secondary,
            strategy: .primaryWithFallback)

        // -- Stage 2: draft through router (secondary serves) --
        let draft = try await router.draft(makeRequest())
        XCTAssertEqual(
            draft.providerID, "secondary-up",
            "fallback must land on secondary")
        XCTAssertTrue(
            draft.body.contains("[NEEDS_PERMIT]"),
            "draft body must contain the marker for L13 ticket " +
            "to carry forward")

        // -- Stage 3: synthesize a ticket from the draft --
        // Hosts construct tickets per turn; here we model that.
        let ticket = BASUpdateTicket(
            ticketID: "t-e2e-\(UUID().uuidString)",
            sessionRef: "session-e2e",
            summary: draft.body,
            confidence: 0.65)

        // -- Stage 4: ingest via the lifecycle auto-flow --
        let coord = BASUpdateTicketLifecycleCoordinator()
        let newCount = await coord.ingestTurn([ticket])
        XCTAssertEqual(newCount, 1)

        // -- Stage 5: walk through the full state machine --
        try await coord.startTrial(
            ticketID: ticket.ticketID,
            trialRecordRef: "shadow-e2e-1")
        try await coord.markTrialOutcome(
            ticketID: ticket.ticketID,
            outcome: .passed(reasonCodes: [
                "router-fallback-served",
                "marker-rewrite-not-needed"]))
        try await coord.approveForDistillation(
            ticketID: ticket.ticketID,
            sovereignVerdictRef: "vrdct-e2e-1")

        // -- Stage 6: queue gating + final distill --
        let queueBefore = await coord.distillationQueue()
        XCTAssertEqual(
            queueBefore.count, 1,
            "queue should expose the queued ticket")
        XCTAssertEqual(
            queueBefore.first?.ticket.ticketID,
            ticket.ticketID)

        try await coord.markDistilled(
            ticketID: ticket.ticketID,
            reasonCodes: ["pipeline-checkpoint:e2e"])

        // -- Stage 7: post-distill state ---
        let queueAfter = await coord.distillationQueue()
        XCTAssertEqual(
            queueAfter.count, 0,
            "distilled ticket must leave the queue")
        let entry = await coord.entry(
            ticketID: ticket.ticketID)
        XCTAssertEqual(entry?.state, .distilled)
        XCTAssertEqual(
            entry?.history.count, 4,
            "trialing → passed → queued → distilled")
        XCTAssertEqual(
            entry?.sovereignVerdictRef, "vrdct-e2e-1",
            "lineage to sovereign verdict preserved")
    }

    // MARK: - Helpers

    private enum InvocationPath: CaseIterable {
        case plain
        case elect
        case purpose
    }

    private func invoke(
        _ router: BASRoutingOrganAdapter,
        path: InvocationPath,
        request: BASOrganRequest
    ) async throws -> BASOrganDraft {
        switch path {
        case .plain:
            return try await router.draft(request)
        case .elect:
            return try await router.draft(
                request,
                electAccelerated: true)
        case .purpose:
            return try await router.draft(
                request,
                purpose: .creative)
        }
    }

    private func totalDraftCount(
        _ adapter: StubAdapter
    ) async -> Int {
        let plain = await adapter.plainDraftCount
        let elect = await adapter.electDraftCount
        let purpose = await adapter.purposeDraftCount
        return plain + elect + purpose
    }

    private func assertTotalDraftCount(
        _ adapter: StubAdapter,
        expected: Int,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let actual = await totalDraftCount(adapter)
        XCTAssertEqual(
            actual, expected, message,
            file: file, line: line)
    }

    private func makeFixedRequest(
        role: BASOrganRole = .scout
    ) -> BASOrganRequest {
        BASOrganRequest(
            requestID: "routing-fixed-request",
            role: role,
            preset: role == .scout ? .scout : .core,
            instruction: "fixed routing request",
            context: ["fixed-context"],
            maxOutputTokens: 11,
            stopSequences: ["stop"],
            deadline: Date(timeIntervalSince1970: 2_000_000_000),
            sessionID: "seat:routing-test",
            personaInstructions: "routing-test-persona")
    }

    private func makeRequest(
        role: BASOrganRole = .scout
    ) -> BASOrganRequest {
        BASOrganRequest(
            requestID: "test-\(UUID().uuidString)",
            role: role,
            preset: role == .scout ? .scout : .core,
            instruction: "test")
    }
}

/// Lightweight stub `BASOrganAdapter` for routing tests. Configured
/// with a fixed response (success or thrown error) and capacity.
private actor StubAdapter: BASOrganAdapter {
    enum Response: Sendable {
        case draftSucceeds(body: String)
        case draftThrows(BASOrganError)
        case cancellation
    }

    nonisolated let descriptor: BASOrganDescriptor
    private let response: Response
    private let _capacity: BASOrganCapacity
    private(set) var plainDraftCount = 0
    private(set) var electDraftCount = 0
    private(set) var purposeDraftCount = 0
    private(set) var capacityCount = 0
    private(set) var lastPlainRequest: BASOrganRequest?
    private(set) var lastElectRequest: BASOrganRequest?
    private(set) var lastElect: Bool?
    private(set) var lastPurposeRequest: BASOrganRequest?
    private(set) var lastPurpose: BASDecodeLanePolicy.Purpose?

    init(
        providerID: String,
        supportsStreaming: Bool = true,
        maxInputTokens: Int = 4096,
        maxOutputTokens: Int = 4096,
        runsOnDevice: Bool = true,
        supportedRoles: Set<BASOrganRole> = [.scout, .core],
        response: Response,
        capacity: BASOrganCapacity = .unlimited
    ) {
        self.descriptor = BASOrganDescriptor(
            providerID: providerID,
            providerName: "Stub: \(providerID)",
            supportsStreaming: supportsStreaming,
            maxInputTokens: maxInputTokens,
            maxOutputTokens: maxOutputTokens,
            runsOnDevice: runsOnDevice,
            supportedRoles: supportedRoles)
        self.response = response
        self._capacity = capacity
    }

    func draft(
        _ request: BASOrganRequest
    ) async throws -> BASOrganDraft {
        plainDraftCount += 1
        lastPlainRequest = request
        return try produceDraft(for: request)
    }

    func draft(
        _ request: BASOrganRequest,
        electAccelerated: Bool
    ) async throws -> BASOrganDraft {
        electDraftCount += 1
        lastElectRequest = request
        lastElect = electAccelerated
        return try produceDraft(for: request)
    }

    func draft(
        _ request: BASOrganRequest,
        purpose: BASDecodeLanePolicy.Purpose
    ) async throws -> BASOrganDraft {
        purposeDraftCount += 1
        lastPurposeRequest = request
        lastPurpose = purpose
        return try produceDraft(for: request)
    }

    private func produceDraft(
        for request: BASOrganRequest
    ) throws -> BASOrganDraft {
        switch response {
        case .draftSucceeds(let body):
            return BASOrganDraft(
                requestID: request.requestID,
                providerID: descriptor.providerID,
                role: request.role,
                body: body,
                inputTokensEstimated: 1,
                outputTokensEstimated: 1,
                producedAt: Date(),
                traceID: "stub-trace-\(descriptor.providerID)")
        case .draftThrows(let err):
            throw err
        case .cancellation:
            throw CancellationError()
        }
    }

    func currentCapacity() async -> BASOrganCapacity {
        capacityCount += 1
        return _capacity
    }
}

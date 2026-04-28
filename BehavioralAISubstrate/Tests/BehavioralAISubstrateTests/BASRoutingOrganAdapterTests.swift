import XCTest
@testable import BASOrgan

/// M255 — coverage for `BASRoutingOrganAdapter`.
///
/// Uses two stub `BASOrganAdapter` implementations: one configurable
/// to throw any error / return any draft, another always returning
/// a fixed draft. Exercises strategy dispatch, fallback triggers,
/// and the synthesized descriptor.
final class BASRoutingOrganAdapterTests: XCTestCase {

    // MARK: - Strategy dispatch

    func testPrimaryWithFallbackUsesPrimaryWhenHealthy() async
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
            primary: primary, secondary: secondary)

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
            primary: primary, secondary: secondary)

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
            primary: primary, secondary: secondary)

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
            primary: primary, secondary: secondary)

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
            primary: primary, secondary: secondary)

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
        let router = BASRoutingOrganAdapter(primary: p, secondary: s)
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
        let router = BASRoutingOrganAdapter(primary: p, secondary: s)
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
        let router = BASRoutingOrganAdapter(primary: p, secondary: s)
        XCTAssertEqual(router.descriptor.maxInputTokens, 1024)
        XCTAssertEqual(router.descriptor.maxOutputTokens, 512)
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
            primary: pYes, secondary: sNo)
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
        let router = BASRoutingOrganAdapter(primary: p, secondary: s)
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
        let router = BASRoutingOrganAdapter(primary: p, secondary: s)
        let cap = await router.currentCapacity()
        XCTAssertEqual(cap.availableInputTokens, 1024)
        XCTAssertFalse(cap.underPressure)
    }

    // MARK: - Helpers

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
    }

    nonisolated let descriptor: BASOrganDescriptor
    private let response: Response
    private let _capacity: BASOrganCapacity

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
        }
    }

    func currentCapacity() async -> BASOrganCapacity {
        _capacity
    }
}

import XCTest
@testable import BASOrgan

/// The neural matrix remains a pure observation/ranking facility.
final class BASProviderRoutingTests: XCTestCase {
    private func descriptor(
        _ providerID: String,
        onDevice: Bool = true,
        roles: Set<BASOrganRole> = [.scout, .core],
        tier: BASCertificationTier? = nil,
        kind: BASProviderKind? = .mlx
    ) -> BASOrganDescriptor {
        BASOrganDescriptor(
            providerID: providerID,
            providerName: providerID,
            supportsStreaming: false,
            maxInputTokens: 4096,
            maxOutputTokens: 4096,
            runsOnDevice: onDevice,
            supportedRoles: roles,
            providerKind: kind,
            certificationTier: tier)
    }

    func testMatrixRanksCertifiedProviderWithoutResolvingRegistry() {
        let selection = BASNeuralProviderMatrix.select(
            context: .init(role: .core, preferCertified: true),
            candidates: [
                descriptor("certified.v1", tier: .certified),
                descriptor("experimental.v1", tier: .experimental),
            ])

        XCTAssertEqual(selection.chosen?.providerID, "certified.v1")
        XCTAssertEqual(selection.ranked.map(\.providerID), [
            "certified.v1", "experimental.v1",
        ])
    }

    func testMatrixRanksOnDeviceProviderAsObservation() {
        let selection = BASNeuralProviderMatrix.select(
            context: .init(role: .core),
            candidates: [
                descriptor("remote.v1", onDevice: false, kind: .remote),
                descriptor("local.v1"),
            ])

        XCTAssertEqual(selection.chosen?.providerID, "local.v1")
        XCTAssertFalse(selection.ranked[0].isOffDevice)
        XCTAssertTrue(selection.ranked[1].isOffDevice)
    }

    func testMatrixReportsUnsupportedCandidatesWithoutExecution() {
        let selection = BASNeuralProviderMatrix.select(
            context: .init(role: .core),
            candidates: [descriptor("scout.only", roles: [.scout])])

        XCTAssertNil(selection.chosen)
        XCTAssertTrue(selection.ranked.isEmpty)
        XCTAssertEqual(selection.unsupportedProviderIDs, ["scout.only"])
    }
}
